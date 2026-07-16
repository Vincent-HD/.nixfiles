#!/usr/bin/env python3
"""Embedded Autodesk sign-in bridge for Fusion running under Wine."""

import html
import os
import shutil
import subprocess
import sys
from urllib.parse import urlparse

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")

from gi.repository import GLib, Gtk, WebKit2  # noqa: E402


def fail(message: str) -> None:
    print(f"fusion360-login: {message}", file=sys.stderr)
    notifier = shutil.which("notify-send")
    if notifier is not None:
        subprocess.run(
            [notifier, "--app-name=fusion360", "Fusion sign-in failed", message],
            check=False,
        )
    raise SystemExit(1)


def sanitize_callback(url: str) -> str:
    # Browsers can preserve the HTML entity or encode the trailing equals sign.
    return html.unescape(url).replace("%3D", "=").replace("%3d", "=")


def hand_off_callback(url: str) -> None:
    callback = sanitize_callback(url)
    wine = os.environ.get("FUSION360_WINE")
    identity_manager = os.environ.get("FUSION360_IDENTITY_MANAGER")

    if wine is not None and identity_manager is not None:
        subprocess.Popen([wine, identity_manager, callback], env=os.environ.copy())
    else:
        handler = shutil.which("fusion360-uri-handler")
        if handler is None:
            fail("fusion360-uri-handler is not available")
        subprocess.Popen([handler, callback], env=os.environ.copy())


def open_system_browser(url: str) -> None:
    opener = shutil.which("xdg-open")
    if opener is None:
        fail("xdg-open is not available")
    subprocess.Popen([opener, url])


def main() -> None:
    if len(sys.argv) != 2:
        fail("expected exactly one URL")

    url = sys.argv[1]
    if url.lower().startswith("adskidmgr:"):
        hand_off_callback(url)
        return

    parsed = urlparse(url)
    hostname = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or not (
        hostname == "autodesk.com" or hostname.endswith(".autodesk.com")
    ):
        open_system_browser(url)
        return

    window = Gtk.Window(title="Autodesk – Sign in")
    window.set_default_size(560, 800)
    window.set_position(Gtk.WindowPosition.CENTER)
    window.connect("destroy", Gtk.main_quit)

    webview = WebKit2.WebView()

    def decide_policy(_webview, decision, decision_type):
        if decision_type != WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            return False
        callback = decision.get_navigation_action().get_request().get_uri()
        if callback.lower().startswith("adskidmgr:"):
            decision.ignore()
            hand_off_callback(callback)
            GLib.idle_add(Gtk.main_quit)
            return True
        return False

    webview.connect("decide-policy", decide_policy)
    webview.load_uri(url)
    window.add(webview)
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
