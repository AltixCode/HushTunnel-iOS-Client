import Foundation
import SwiftUI
import Combine

public enum ShadowLinkLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case persian = "fa"
    case russian = "ru"
    case chinese = "zh"
    case turkish = "tr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .persian: return "فارسی (Persian)"
        case .russian: return "Русский (Russian)"
        case .chinese: return "中文 (Chinese)"
        case .turkish: return "Türkçe (Turkish)"
        }
    }

    public var isRTL: Bool {
        return self == .persian
    }
}

@MainActor
public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    @Published public var currentLanguage: ShadowLinkLanguage = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }

    public var layoutDirection: LayoutDirection {
        currentLanguage.isRTL ? .rightToLeft : .leftToRight
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        self.currentLanguage = ShadowLinkLanguage(rawValue: saved) ?? .english
    }

    public func setLanguage(_ lang: ShadowLinkLanguage) {
        self.currentLanguage = lang
    }

    public func tr(_ key: String) -> String {
        return ShadowLinkStrings.get(key, lang: currentLanguage)
    }
}

public struct ShadowLinkStrings {
    private static let translations: [ShadowLinkLanguage: [String: String]] = [
        .english: [
            "auth.login": "Log in",
            "auth.register": "Sign up",
            "auth.email": "Email address",
            "auth.password": "Password",
            "auth.signIn": "Sign In",
            "auth.signUp": "Create Account",
            "auth.dontHaveAccount": "Don't have an account?",
            "auth.alreadyHaveAccount": "Already have an account?",
            "vpn.connect": "Connect",
            "vpn.disconnect": "Disconnect",
            "vpn.connecting": "Connecting...",
            "vpn.connected": "Connected",
            "vpn.disconnected": "Disconnected",
            "vpn.activePlan": "Active Plan",
            "vpn.expires": "Expires",
            "vpn.daysRemaining": "%d days left",
            "vpn.trafficUsed": "Usage",
            "vpn.buyPlan": "Get a Subscription",
            "vpn.renew": "Renew Subscription",
            "vpn.noSub": "No active VPN connection",
            "vpn.noSubDesc": "Select a plan below to activate your high-speed VLESS connection.",
            "orders.title": "Order History",
            "reseller.portal": "Reseller Portal",
            "reseller.balance": "Prepaid Balance",
            "reseller.discount": "Current Discount",
            "reseller.nextTier": "Add $%@ for %d%% off",
            "reseller.tab.vpn": "My VPN",
            "reseller.tab.overview": "Dashboard",
            "reseller.tab.customers": "Customers",
            "reseller.tab.subscriptions": "Subscriptions",
            "reseller.tab.orders": "Orders",
            "reseller.tab.deposits": "Deposits",
            "reseller.createMyVpn": "Create My Personal VPN",
            "reseller.addCustomer": "Add Customer",
            "reseller.newOrder": "New Order for Customer",
            "reseller.addFunds": "Deposit Funds",
            "reseller.resetPassword": "Reset Password",
            "reseller.changePassword": "Set Custom Password",
            "reseller.extend": "Extend Days",
            "reseller.revoke": "Revoke",
            "common.cancel": "Cancel",
            "common.confirm": "Confirm",
            "common.done": "Done",
            "common.language": "Language",
            "common.logout": "Log out",
            "common.refresh": "Refresh",
            "common.close": "Close",
            "common.copy": "Copy",
            "common.copied": "Copied to clipboard"
        ],
        .persian: [
            "auth.login": "ورود به حساب",
            "auth.register": "ثبت نام",
            "auth.email": "آدرس ایمیل",
            "auth.password": "کلمه عبور",
            "auth.signIn": "ورود",
            "auth.signUp": "ایجاد حساب کاربری",
            "auth.dontHaveAccount": "حساب کاربری ندارید؟",
            "auth.alreadyHaveAccount": "قبلاً ثبت نام کرده‌اید؟",
            "vpn.connect": "اتصال سریع",
            "vpn.disconnect": "قطع اتصال",
            "vpn.connecting": "در حال اتصال...",
            "vpn.connected": "متصل شد",
            "vpn.disconnected": "قطع شد",
            "vpn.activePlan": "اشتراک فعال",
            "vpn.expires": "تاریخ انقضا",
            "vpn.daysRemaining": "%d روز باقی مانده",
            "vpn.trafficUsed": "مصرف ترافیک",
            "vpn.buyPlan": "خرید اشتراک جدید",
            "vpn.renew": "تمدید اشتراک",
            "vpn.noSub": "اشتراک فعالی ندارید",
            "vpn.noSubDesc": "برای فعال‌سازی کانکشن ضد فیلتر پرسرعت، یک پلن انتخاب کنید.",
            "orders.title": "تاریخچه سفارشات",
            "reseller.portal": "پنل همکاران و نمایندگان",
            "reseller.balance": "موجودی کیف پول",
            "reseller.discount": "تخفیف فعلی شما",
            "reseller.nextTier": "شارژ $%@ برای %d%% تخفیف",
            "reseller.tab.vpn": "اتصال من",
            "reseller.tab.overview": "داشبورد",
            "reseller.tab.customers": "مشتریان",
            "reseller.tab.subscriptions": "اشتراک‌ها",
            "reseller.tab.orders": "سفارشات",
            "reseller.tab.deposits": "افزایش موجودی",
            "reseller.createMyVpn": "ایجاد اتصال اختصاصی برای خودم",
            "reseller.addCustomer": "افزودن کاربر جدید",
            "reseller.newOrder": "ثبت اشتراک برای کاربر",
            "reseller.addFunds": "افزایش موجودی کیف پول",
            "reseller.resetPassword": "بازنشانی کلمه عبور",
            "reseller.changePassword": "تعیین پسورد دلخواه",
            "reseller.extend": "تمدید روزها",
            "reseller.revoke": "حذف و ابطال",
            "common.cancel": "انصراف",
            "common.confirm": "تایید",
            "common.done": "تمام",
            "common.language": "تغییر زبان",
            "common.logout": "خروج از حساب",
            "common.refresh": "بروزرسانی",
            "common.close": "بستن",
            "common.copy": "کپی",
            "common.copied": "کپی شد"
        ],
        .russian: [
            "auth.login": "Вход",
            "auth.register": "Регистрация",
            "auth.email": "Электронная почта",
            "auth.password": "Пароль",
            "auth.signIn": "Войти",
            "auth.signUp": "Создать аккаунт",
            "auth.dontHaveAccount": "Нет аккаунта?",
            "auth.alreadyHaveAccount": "Уже есть аккаунт?",
            "vpn.connect": "Подключиться",
            "vpn.disconnect": "Отключиться",
            "vpn.connecting": "Подключение...",
            "vpn.connected": "Подключено",
            "vpn.disconnected": "Отключено",
            "vpn.activePlan": "Активный тариф",
            "vpn.expires": "Истекает",
            "vpn.daysRemaining": "Осталось %d дн.",
            "vpn.trafficUsed": "Трафик",
            "vpn.buyPlan": "Купить тариф",
            "vpn.renew": "Продлить тариф",
            "vpn.noSub": "Нет активной подписки",
            "vpn.noSubDesc": "Выберите тариф ниже для подключения к VPN.",
            "orders.title": "История заказов",
            "reseller.portal": "Кабинет реселлера",
            "reseller.balance": "Баланс кошелька",
            "reseller.discount": "Скидка реселлера",
            "reseller.nextTier": "+$%@ для скидки %d%%",
            "reseller.tab.vpn": "Мой VPN",
            "reseller.tab.overview": "Обзор",
            "reseller.tab.customers": "Клиенты",
            "reseller.tab.subscriptions": "Подписки",
            "reseller.tab.orders": "Заказы",
            "reseller.tab.deposits": "Пополнения",
            "reseller.createMyVpn": "Создать личный VPN",
            "reseller.addCustomer": "Добавить клиента",
            "reseller.newOrder": "Оформить для клиента",
            "reseller.addFunds": "Пополнить баланс",
            "reseller.resetPassword": "Сбросить пароль",
            "reseller.changePassword": "Задать новый пароль",
            "reseller.extend": "Продлить дни",
            "reseller.revoke": "Отозвать",
            "common.cancel": "Отмена",
            "common.confirm": "Подтвердить",
            "common.done": "Готово",
            "common.language": "Язык",
            "common.logout": "Выйти",
            "common.refresh": "Обновить",
            "common.close": "Закрыть",
            "common.copy": "Копировать",
            "common.copied": "Скопировано"
        ],
        .chinese: [
            "auth.login": "登录",
            "auth.register": "注册",
            "auth.email": "电子邮箱",
            "auth.password": "密码",
            "auth.signIn": "登录",
            "auth.signUp": "创建账户",
            "auth.dontHaveAccount": "还没有账户？",
            "auth.alreadyHaveAccount": "已有账户？",
            "vpn.connect": "一键连接",
            "vpn.disconnect": "断开连接",
            "vpn.connecting": "正在连接...",
            "vpn.connected": "已连接",
            "vpn.disconnected": "未连接",
            "vpn.activePlan": "当前订阅",
            "vpn.expires": "到期时间",
            "vpn.daysRemaining": "剩余 %d 天",
            "vpn.trafficUsed": "已用流量",
            "vpn.buyPlan": "购买套餐",
            "vpn.renew": "续费订阅",
            "vpn.noSub": "暂无有效订阅",
            "vpn.noSubDesc": "请在下方选择套餐以开启高速 VLESS 节点。",
            "orders.title": "订单记录",
            "reseller.portal": "代理商后台",
            "reseller.balance": "账户余额",
            "reseller.discount": "当前折扣",
            "reseller.nextTier": "充值 $%@ 可享 %d%% 折扣",
            "reseller.tab.vpn": "我的VPN",
            "reseller.tab.overview": "总览",
            "reseller.tab.customers": "客户列表",
            "reseller.tab.subscriptions": "订阅管理",
            "reseller.tab.orders": "订单管理",
            "reseller.tab.deposits": "充值记录",
            "reseller.createMyVpn": "开通个人专属VPN",
            "reseller.addCustomer": "添加新客户",
            "reseller.newOrder": "为客户开通套餐",
            "reseller.addFunds": "充值余额",
            "reseller.resetPassword": "重置密码",
            "reseller.changePassword": "修改自定义密码",
            "reseller.extend": "增加天数",
            "reseller.revoke": "删除注销",
            "common.cancel": "取消",
            "common.confirm": "确认",
            "common.done": "完成",
            "common.language": "语言",
            "common.logout": "退出登录",
            "common.refresh": "刷新",
            "common.close": "关闭",
            "common.copy": "复制",
            "common.copied": "已复制"
        ],
        .turkish: [
            "auth.login": "Giriş Yap",
            "auth.register": "Kayıt Ol",
            "auth.email": "E-posta Adresi",
            "auth.password": "Şifre",
            "auth.signIn": "Giriş Yap",
            "auth.signUp": "Hesap Oluştur",
            "auth.dontHaveAccount": "Hesabınız yok mu?",
            "auth.alreadyHaveAccount": "Zaten hesabınız var mı?",
            "vpn.connect": "Bağlan",
            "vpn.disconnect": "Bağlantıyı Kes",
            "vpn.connecting": "Bağlanıyor...",
            "vpn.connected": "Bağlandı",
            "vpn.disconnected": "Bağlantı Yok",
            "vpn.activePlan": "Aktif Plan",
            "vpn.expires": "Bitiş Tarihi",
            "vpn.daysRemaining": "%d gün kaldı",
            "vpn.trafficUsed": "Kullanım",
            "vpn.buyPlan": "Plan Satın Al",
            "vpn.renew": "Planı Yenile",
            "vpn.noSub": "Aktif bağlantı bulunamadı",
            "vpn.noSubDesc": "VLESS bağlantınızı etkinleştirmek için bir plan seçin.",
            "orders.title": "Sipariş Geçmişi",
            "reseller.portal": "Bayi Portalı",
            "reseller.balance": "Bakiye",
            "reseller.discount": "Mevcut İndirim",
            "reseller.nextTier": "%%d indirim için $%@ ekleyin",
            "reseller.tab.vpn": "VPN Bağlantım",
            "reseller.tab.overview": "Panel",
            "reseller.tab.customers": "Müşteriler",
            "reseller.tab.subscriptions": "Abonelikler",
            "reseller.tab.orders": "Siparişler",
            "reseller.tab.deposits": "Yüklemeler",
            "reseller.createMyVpn": "Kişisel VPN Oluştur",
            "reseller.addCustomer": "Müşteri Ekle",
            "reseller.newOrder": "Müşteriye Plan Tanımla",
            "reseller.addFunds": "Bakiye Yükle",
            "reseller.resetPassword": "Şifreyi Sıfırla",
            "reseller.changePassword": "Yeni Şifre Belirle",
            "reseller.extend": "Süre Uzat",
            "reseller.revoke": "İptal Et",
            "common.cancel": "İptal",
            "common.confirm": "Onayla",
            "common.done": "Tamam",
            "common.language": "Dil",
            "common.logout": "Çıkış Yap",
            "common.refresh": "Yenile",
            "common.close": "Kapat",
            "common.copy": "Kopyala",
            "common.copied": "Kopyalandı"
        ]
    ]

    public static func get(_ key: String, lang: ShadowLinkLanguage) -> String {
        return translations[lang]?[key] ?? translations[.english]?[key] ?? key
    }
}
