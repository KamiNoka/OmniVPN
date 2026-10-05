# OmniVPN — Универсальный iOS VPN Клиент (.IPA)

Современное iOS-приложение и системный туннель на базе ядра **Sing-box** (`libbox`), созданное на **SwiftUI** с использованием **Swift Charts** для визуализации трафика и автоматической сборкой готового `.ipa` файла через **GitHub Actions CI**.

---

## 🚀 Поддерживаемые протоколы

Клиент объединяет все актуальные протоколы обхода блокировок и шифрования трафика:
* **VLESS** (с поддержкой **Reality**, Vision, XTLS, gRPC, WebSocket)
* **Hysteria 2** (высокоскоростной UDP-протокол с защитой от троттлинга провайдерами)
* **WireGuard** (высокая производительность и низкая задержка)
* **Shadowsocks** (включая современные шифры 2022-blake3-aes-128-gcm)
* **Trojan** (TLS, gRPC, WebSocket)
* **VMess** (TCP, WebSocket, gRPC)
* **TUIC v5** (на базе QUIC)
* **SSH**, **SOCKS5**, **HTTP**, **Direct**

---

## ✨ Основные возможности приложения

* **Интуитивный интерфейс (SwiftUI)**:
  * Кнопка подключения в 1 касание с тактильным откликом (Haptic Feedback) и плавной анимацией статуса.
  * Виджет активного узла с флагом страны, пингом и протоколом.
  * Спидометры входящей и исходящей скорости в реальном времени.
  * Таймер активной сессии.
* **Серверы и подписки**:
  * Импорт ссылок: `vless://`, `hysteria2://`, `trojan://`, `ss://`, `vmess://`.
  * Импорт подписок по URL (Sing-box JSON, Clash YAML, Base64 списки).
  * Встроенный сканер QR-кодов на базе AVFoundation.
  * Замер задержки (Ping/RTT) всех серверов в один клик.
* **Статистика трафика (Swift Charts)**:
  * Живой график входящей/исходящей скорости за последние 60 секунд.
  * Счётчики трафика: за текущую сессию, общий объём скачанного и отданного.
  * Интерактивный просмотр логов ядра Sing-box в реальном времени.
* **Маршрутизация и безопасность**:
  * Режимы: **По правилам** (обход локальных ресурсов и доменов), **Весь трафик (Global)**, **Напрямую (Direct)**.
  * Безопасный DNS: Cloudflare DoH, Google DoH, Quad9, AdGuard DNS (блокировка рекламы) или свой DoH.
  * Аварийный выключатель (**Kill Switch**).

---

## 🛠 Архитектура проекта

```text
├── project.yml                       # Декларативная спецификация XcodeGen
├── exportOptions.plist               # Опции экспорта IPA архива
├── .github/
│   └── workflows/
│       └── build-ipa.yml             # GitHub Actions CI для сборки .ipa на macOS-14
├── scripts/
│   ├── download_libbox.sh            # Скрипт загрузки ядра Sing-box Libbox.xcframework
│   ├── export_ipa.sh                 # Скрипт сборки архива и экспорта IPA
│   └── verify_project.py             # Тесты валидности конфигураций и схемы
├── Frameworks/
│   └── Libbox.xcframework            # Бинарный фреймворк Sing-box под iOS
├── VpnClient/                        # Главное приложение SwiftUI
│   ├── App/                          # Точка входа VpnClientApp и AppState
│   ├── Models/                       # ServerNode, Subscription, TrafficHistory, RoutingRule
│   ├── Services/                     # VPNManager, SubscriptionParser, PingService, StatsManager, ConfigBuilder
│   ├── Views/                        # Dashboard, Servers, Statistics, Settings, QRScanner
│   └── Resources/                    # Info.plist, VpnClient.entitlements
└── PacketTunnel/                     # Network Extension (NEPacketTunnelProvider)
    ├── PacketTunnelProvider.swift    # Мост между iOS tun и Sing-box core
    ├── PacketTunnel.entitlements     # Entitlements: Packet Tunnel & App Group
    └── Info.plist
```

---

## 📦 Сборка .IPA через GitHub Actions CI

Поскольку текущая разработка ведется на Linux, сборка `.ipa` автоматизирована через **GitHub Actions** на бесплатных раннерах Apple Silicon (`macos-14`).

### Шаг 1. Отправьте код в ваш репозиторий GitHub
```bash
git init
git add .
git commit -m "Initial commit of OmniVPN"
git branch -M main
git remote add origin https://github.com/<ваш-логин>/<ваш-репозиторий>.git
git push -u origin main
```

### Шаг 2. Добавьте секреты для платного Apple Developer аккаунта
Перейдите в настройки репозитория: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`:

1. `BUILD_CERTIFICATE_BASE64`: Сертификат Apple Development / Distribution (`.p12`), закодированный в base64:
   ```bash
   base64 -w 0 Certificates.p12
   ```
2. `P12_PASSWORD`: Пароль к файлу `.p12`.
3. `PROVISION_PROFILE_APP_BASE64`: Файл `App.mobileprovision` (с включенным entitlement `packet-tunnel-provider` и `group.com.universal.vpnclient`), закодированный в base64:
   ```bash
   base64 -w 0 App.mobileprovision
   ```
4. `PROVISION_PROFILE_EXT_BASE64`: Файл `PacketTunnel.mobileprovision`, закодированный в base64:
   ```bash
   base64 -w 0 PacketTunnel.mobileprovision
   ```

> **Примечание**: Если секреты подписи не указаны, CI автоматически собирает **Unsigned IPA** (`OmniVPN.ipa`), который можно подписать локально через Sideloadly, AltStore или сразу установить через TrollStore.

### Шаг 3. Запуск сборки
* Сборка запускается автоматически при каждом коммите (`push`) в ветку `main`.
* Также её можно запустить вручную: вкладка **Actions** → **Build iOS IPA (OmniVPN)** → кнопка **Run workflow**.
* После завершения (3-5 минут) скачайте готовый `.ipa` из блока **Artifacts** (`OmniVPN-IPA`).

---

## 📲 Установка .IPA на устройство iOS

1. **Apple Developer Account / TestFlight**:
   * Загрузите подписанный IPA через Apple Transporter или установите напрямую с помощью Apple Configurator / Xcode Devices.
2. **TrollStore** (для совместимых версий iOS):
   * Установите полученный `OmniVPN.ipa` напрямую через TrollStore без ограничений срока действия.
3. **AltStore / Sideloadly**:
   * Откройте Sideloadly, перетащите `.ipa`, укажите ваш Apple ID и нажмите «Start».

---

## 🧪 Локальная проверка проекта
Для верификации структуры и конфигурации выполните:
```bash
python3 scripts/verify_project.py
```
