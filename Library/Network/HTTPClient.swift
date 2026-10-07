import Foundation
#if !os(iOS)
    import Libbox
#endif

#if os(iOS)
    // iOS no longer runs sing-box as its tunnel engine (see
    // Extension/PacketTunnelProvider.swift — xray-core + hev-socks5-tunnel
    // instead, for GPLv3/App Store reasons), and Libbox itself can no longer
    // be linked into the iOS build at all: gomobile-bound frameworks each
    // embed their own full Go runtime, and two independently-built Go
    // runtimes (Libbox's and XrayMobile's) cannot coexist in one process —
    // confirmed on-device via a real crash: `panic: seq.Inc: unknown
    // refnum` from Libbox's own gomobile reference-counting code, triggered
    // the instant xray-core's engine started. This is a plain URLSession
    // reimplementation of the same public API Libbox's HTTPClient exposed,
    // so every caller (ProvisionHelper, Profile+Update, etc.) keeps working
    // unchanged. The User-Agent string matters here specifically: the
    // backend's subscription endpoint sniffs it to decide which config
    // FORMAT to return (see HushTunnel-Billing-Dashboard's
    // lib/subscription-format.ts — a "sing-box" substring makes it return a
    // sing-box JSON document instead of the plain vless:// link iOS's
    // ProvisionHelper actually expects).
    public class HTTPClient {
        private static var userAgent: String {
            var userAgent = Variant.applicationName
            userAgent += " (xray-core"
            userAgent += "; language "
            userAgent += Locale.current.identifier
            userAgent += ")"
            return userAgent
        }

        private let session: URLSession

        public init() {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 120
            session = URLSession(configuration: config)
        }

        public func getString(_ url: String?, headers: [String: String] = [:]) throws -> String {
            #if DEBUG
                precondition(!Thread.isMainThread, "HTTPClient.getString(...) must not be called on the main thread")
            #endif
            guard let url, let requestURL = URL(string: url) else {
                throw HTTPClientError.invalidURL
            }
            var request = URLRequest(url: requestURL)
            request.setValue(HTTPClient.userAgent, forHTTPHeaderField: "User-Agent")
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let (data, response) = try Self.runSynchronously { completion in
                self.session.dataTask(with: request) { data, response, error in
                    completion((data, response, error))
                }
            }
            try Self.validate(response: response)
            guard let data, let content = String(data: data, encoding: .utf8) else {
                throw HTTPClientError.invalidResponseEncoding
            }
            return content
        }

        public func getStringAsync(_ url: String?) async throws -> String {
            try await Self.getStringAsync(url)
        }

        public static func getStringAsync(_ url: String?) async throws -> String {
            try await BlockingIO.run {
                try HTTPClient().getString(url)
            }
        }

        public func writeTo(_ url: String?, path: String, progress: ((Int64, Int64) -> Void)? = nil) throws {
            #if DEBUG
                precondition(!Thread.isMainThread, "HTTPClient.writeTo(...) must not be called on the main thread")
            #endif
            guard let url, let requestURL = URL(string: url) else {
                throw HTTPClientError.invalidURL
            }
            var request = URLRequest(url: requestURL)
            request.setValue(HTTPClient.userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try Self.runSynchronously { completion in
                self.session.dataTask(with: request) { data, response, error in
                    completion((data, response, error))
                }
            }
            try Self.validate(response: response)
            guard let data else {
                throw HTTPClientError.invalidResponseEncoding
            }
            progress?(Int64(data.count), Int64(data.count))
            try data.write(to: URL(fileURLWithPath: path))
        }

        public static func writeToAsync(_ url: String?, path: String, progress: ((Int64, Int64) -> Void)? = nil) async throws {
            try await BlockingIO.run {
                try HTTPClient().writeTo(url, path: path, progress: progress)
            }
        }

        /// Bridges a completion-handler-based `URLSessionDataTask` into a
        /// synchronous call, matching the blocking contract every caller of
        /// `getString`/`writeTo` already relies on (both are documented as
        /// "must not be called on the main thread" and are always invoked
        /// from inside `BlockingIO.run`, which already hops to a background
        /// queue).
        private static func runSynchronously(
            _ start: (@escaping ((Data?, URLResponse?, Error?)) -> Void) -> URLSessionDataTask
        ) throws -> (Data?, URLResponse?) {
            let semaphore = DispatchSemaphore(value: 0)
            var result: (Data?, URLResponse?, Error?) = (nil, nil, nil)
            let task = start { outcome in
                result = outcome
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
            if let error = result.2 {
                throw error
            }
            return (result.0, result.1)
        }

        private static func validate(response: URLResponse?) throws {
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw HTTPClientError.httpError(statusCode: httpResponse.statusCode)
            }
        }
    }

    public enum HTTPClientError: LocalizedError {
        case invalidURL
        case invalidResponseEncoding
        case httpError(statusCode: Int)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                "Invalid URL"
            case .invalidResponseEncoding:
                "Response was not valid UTF-8"
            case let .httpError(statusCode):
                "HTTP error \(statusCode)"
            }
        }
    }

#else

    public class HTTPClient {
        private static var userAgent: String {
            var userAgent = Variant.applicationName
            userAgent += " (sing-box "
            userAgent += LibboxVersion()
            userAgent += "; language "
            userAgent += Locale.current.identifier
            userAgent += ")"
            return userAgent
        }

        private let client: any LibboxHTTPClientProtocol

        public init() {
            client = LibboxNewHTTPClient()!
            client.modernTLS()
        }

        public func getString(_ url: String?, headers: [String: String] = [:]) throws -> String {
            #if DEBUG
                precondition(!Thread.isMainThread, "HTTPClient.getString(...) must not be called on the main thread")
            #endif
            let request = client.newRequest()!
            request.setUserAgent(HTTPClient.userAgent)
            for (key, value) in headers {
                request.setHeader(key, value: value)
            }
            try request.setURL(url)
            let response = try request.execute()
            let content = try response.getContent()
            return content.value
        }

        public func getStringAsync(_ url: String?) async throws -> String {
            try await Self.getStringAsync(url)
        }

        public static func getStringAsync(_ url: String?) async throws -> String {
            try await BlockingIO.run {
                try HTTPClient().getString(url)
            }
        }

        public func writeTo(_ url: String?, path: String, progress: ((Int64, Int64) -> Void)? = nil) throws {
            #if DEBUG
                precondition(!Thread.isMainThread, "HTTPClient.writeTo(...) must not be called on the main thread")
            #endif
            let request = client.newRequest()!
            request.setUserAgent(HTTPClient.userAgent)
            try request.setURL(url)
            let response = try request.execute()
            if let progress {
                let handler = WriteToProgressHandler(progress)
                try response.writeTo(withProgress: path, handler: handler)
            } else {
                try response.write(to: path)
            }
        }

        public static func writeToAsync(_ url: String?, path: String, progress: ((Int64, Int64) -> Void)? = nil) async throws {
            try await BlockingIO.run {
                try HTTPClient().writeTo(url, path: path, progress: progress)
            }
        }

        deinit {
            client.close()
        }
    }

    private class WriteToProgressHandler: NSObject, LibboxHTTPResponseWriteToProgressHandlerProtocol {
        private let handler: (Int64, Int64) -> Void

        init(_ handler: @escaping (Int64, Int64) -> Void) {
            self.handler = handler
        }

        func update(_ progress: Int64, total: Int64) {
            handler(progress, total)
        }
    }

#endif
