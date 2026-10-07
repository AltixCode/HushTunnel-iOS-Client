# HushTunnel

HushTunnel is a managed VPN subscription service for iOS. Unlike a bring-your-own-server
proxy client, HushTunnel sells access: a user creates an account, chooses a plan, pays
through the App Store, and gets a managed connection with no configuration file to write
or server to run. It also supports a multi-tier reseller model, where a distributor can
manage their own customers, subscriptions, deposits and sub-resellers from within the app.

## What's in this repo

The product layer — account registration and sign-in, subscription plans and in-app
purchase via RevenueCat, order history, a wallet with a transaction ledger, and the full
reseller dashboard — lives under `ApplicationLibrary/HushTunnel/`. That layer talks to
HushTunnel's own backend over more than 30 `/api/mobile/*` endpoints and has no
equivalent upstream.

## Acknowledgements

HushTunnel's tunnelling layer is built on [sing-box](https://sing-box.sagernet.org/), the
open-source universal proxy platform by [SagerNet](https://github.com/SagerNet/sing-box) /
nekohasekai, and this repository began as a fork of their
[sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple) client. The networking
engine, platform integration, and a substantial portion of the surrounding code are their
work, not ours; our own contribution is the account, billing and reseller layer described
above. See [Open Source Acknowledgements](https://github.com/SagerNet/sing-box) and the
engine's own [documentation](https://sing-box.sagernet.org/) for details on sing-box itself.

## License

This project is distributed under the terms of the GNU General Public License v3, inherited
from its sing-box-for-apple origin:

```
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
```
