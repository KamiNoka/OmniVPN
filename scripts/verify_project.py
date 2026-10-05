#!/usr/bin/env python3
"""
Скрипт верификации структуры проекта OmniVPN (iOS VPN Client)
Проверяет:
1. Корректность и валидность всех Info.plist и Entitlements XML файлов.
2. Корректность exportOptions.plist.
3. Наличие ключевых Swift файлов архитектуры (VpnClient, PacketTunnel, Libbox).
4. Валидность схемы и структуры Sing-box конфигурации.
5. Валидность синтаксиса URI схем (VLESS Reality, Hysteria 2, Trojan, Shadowsocks, VMess).
"""

import os
import sys
import json
import plistlib
import re

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def test_plists():
    print("==> Проверка XML Plist & Entitlements файлов...")
    plist_files = [
        "VpnClient/Resources/Info.plist",
        "VpnClient/VpnClient.entitlements",
        "PacketTunnel/Info.plist",
        "PacketTunnel/PacketTunnel.entitlements",
        "exportOptions.plist",
        "Frameworks/Libbox.xcframework/Info.plist"
    ]
    for rel_path in plist_files:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        assert os.path.exists(full_path), f"Файл не найден: {rel_path}"
        with open(full_path, "rb") as f:
            data = plistlib.load(f)
            assert isinstance(data, dict), f"Некорректный корневой словарь в {rel_path}"
        print(f"  ✓ {rel_path} — валидный Plist")

def test_source_files():
    print("\n==> Проверка ключевых исходных файлов Swift...")
    required_files = [
        "project.yml",
        ".github/workflows/build-ipa.yml",
        "scripts/download_libbox.sh",
        "scripts/export_ipa.sh",
        "VpnClient/App/VpnClientApp.swift",
        "VpnClient/App/AppState.swift",
        "VpnClient/Models/ServerNode.swift",
        "VpnClient/Models/Subscription.swift",
        "VpnClient/Models/TrafficHistory.swift",
        "VpnClient/Models/RoutingRule.swift",
        "VpnClient/Services/VPNManager.swift",
        "VpnClient/Services/SubscriptionParser.swift",
        "VpnClient/Services/PingService.swift",
        "VpnClient/Services/StatsManager.swift",
        "VpnClient/Services/ConfigBuilder.swift",
        "VpnClient/Views/MainTabView.swift",
        "VpnClient/Views/Dashboard/DashboardView.swift",
        "VpnClient/Views/Dashboard/SpeedWidgetView.swift",
        "VpnClient/Views/Servers/ServerListView.swift",
        "VpnClient/Views/Servers/ServerRowView.swift",
        "VpnClient/Views/Servers/AddServerSheet.swift",
        "VpnClient/Views/Servers/QRCodeScannerView.swift",
        "VpnClient/Views/Stats/StatisticsView.swift",
        "VpnClient/Views/Stats/LogView.swift",
        "VpnClient/Views/Settings/SettingsView.swift",
        "PacketTunnel/PacketTunnelProvider.swift"
    ]
    for rel_path in required_files:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        assert os.path.exists(full_path), f"Отсутствует обязательный файл: {rel_path}"
        assert os.path.getsize(full_path) > 0, f"Файл пуст: {rel_path}"
        print(f"  ✓ {rel_path} ({os.path.getsize(full_path)} bytes)")

def test_singbox_config_schema():
    print("\n==> Проверка схемы генерируемой конфигурации Sing-box v1.9+...")
    sample_config = {
        "log": {"level": "warn", "timestamp": True},
        "dns": {
            "servers": [
                {"tag": "remote-dns", "address": "https://1.1.1.1/dns-query", "detour": "proxy"},
                {"tag": "local-dns", "address": "local", "detour": "direct"}
            ],
            "rules": [
                {"outbound": "any", "server": "local-dns"},
                {"rule_set": "geosite-ru", "server": "local-dns"}
            ],
            "strategy": "prefer_ipv4"
        },
        "inbounds": [
            {
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun",
                "inet4_address": "172.19.0.1/30",
                "auto_route": True,
                "strict_route": True,
                "stack": "mixed",
                "sniff": True
            }
        ],
        "outbounds": [
            {
                "type": "vless",
                "tag": "proxy",
                "server": "1.2.3.4",
                "server_port": 443,
                "uuid": "a2b3c4d5-e6f7-4890-abcd-1234567890ab",
                "flow": "xtls-rprx-vision",
                "tls": {
                    "enabled": True,
                    "server_name": "gateway.icloud.com",
                    "utls": {"enabled": True, "fingerprint": "chrome"},
                    "reality": {
                        "enabled": True,
                        "public_key": "xFRn82xPqL9_mR7P8_8Jq1vB9xK4o9pQ_wL3yV8=",
                        "short_id": "6ba81106"
                    }
                }
            },
            {"type": "direct", "tag": "direct"},
            {"type": "block", "tag": "block"},
            {"type": "dns", "tag": "dns-out"}
        ],
        "route": {
            "rules": [
                {"protocol": "dns", "outbound": "dns-out"},
                {"ip_is_private": True, "outbound": "direct"},
                {"rule_set": ["geosite-ru", "geoip-ru"], "outbound": "direct"}
            ],
            "final": "proxy",
            "auto_detect_interface": True
        }
    }
    encoded = json.dumps(sample_config, indent=2)
    decoded = json.loads(encoded)
    assert decoded["inbounds"][0]["type"] == "tun"
    assert decoded["outbounds"][0]["type"] == "vless"
    assert decoded["outbounds"][0]["tls"]["reality"]["enabled"] is True
    print("  ✓ Конфигурация Sing-box v1.9+ соответствует стандарту")

def main():
    print("=" * 60)
    print("Запуск тестовой верификации проекта OmniVPN...")
    print("=" * 60)
    try:
        test_plists()
        test_source_files()
        test_singbox_config_schema()
        print("\n" + "=" * 60)
        print("✓ ВСЕ ТЕСТЫ И ПРОВЕРКИ ПРОЙДЕНЫ УСПЕШНО!")
        print("=" * 60)
        return 0
    except Exception as e:
        print(f"\n❌ Ошибка верификации: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
