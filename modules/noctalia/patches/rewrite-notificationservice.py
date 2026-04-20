#!/usr/bin/env python3

from pathlib import Path
import re
import sys


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing anchor for {label}")
    return text.replace(old, new, 1)


def main() -> None:
    path = Path(sys.argv[1])
    text = path.read_text()

    text = replace_once(
        text,
        "  property var notificationServerLoader: null\n",
        '  property var notificationServerLoader: null\n  property var browserAppEntries: []\n  property string lastFocusedBrowserAppId: ""\n',
        "notificationServerLoader property",
    )

    process_block = r"""  Process {
    id: browserAppDesktopProcess
    running: false
    command: ["sh", "-lc", "for file in \"$HOME\"/.local/share/applications/brave-*.desktop; do [ -f \"$file\" ] || continue; app_id=$(basename \"$file\" .desktop); name=$(grep -m1 '^Name=' \"$file\" | cut -d= -f2-); printf '%s\\t%s\\n' \"$app_id\" \"$name\"; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        const entries = [];
        const lines = (this.text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line)
            continue;
          const parts = line.split("\t");
          const appId = parts[0] || "";
          const name = parts.slice(1).join("\t").trim();
          if (!appId || !name)
            continue;
          entries.push({
                         "appId": appId.toLowerCase(),
                         "name": name,
                         "normalizedName": name.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim()
                       });
        }
        root.browserAppEntries = entries;
      }
    }
  }

  Connections {
    target: CompositorService
    function onActiveWindowChanged() {
      const focusedWindow = CompositorService.getFocusedWindow();
      if (!focusedWindow)
        return;

      const focusedAppId = (focusedWindow.appId || "").toLowerCase();
      if ((focusedAppId.startsWith("brave-") || focusedAppId.startsWith("chrome-") || focusedAppId.startsWith("chromium-")) && focusedAppId !== "brave-browser" && focusedAppId !== "google-chrome" && focusedAppId !== "chromium-browser") {
        root.lastFocusedBrowserAppId = focusedAppId;
      }
    }
  }

  function reloadBrowserAppEntries() {
    browserAppDesktopProcess.running = false;
    browserAppDesktopProcess.running = true;
  }

"""

    text = replace_once(
        text,
        "  }\n\n  function updateNotificationServer() {\n",
        "  }\n\n" + process_block + "  function updateNotificationServer() {\n",
        "insert browser app loader",
    )

    text = replace_once(
        text,
        "    if (Settings.isLoaded) {\n      updateNotificationServer();\n    }\n",
        '    if (Settings.isLoaded) {\n      updateNotificationServer();\n      reloadBrowserAppEntries();\n\n      const focusedWindow = CompositorService.getFocusedWindow();\n      if (focusedWindow) {\n        const focusedAppId = (focusedWindow.appId || "").toLowerCase();\n        if (isBrowserWindowId(focusedAppId) && focusedAppId !== "brave-browser" && focusedAppId !== "google-chrome" && focusedAppId !== "chromium-browser") {\n          root.lastFocusedBrowserAppId = focusedAppId;\n        }\n      }\n    }\n',
        "initialize browser focus",
    )

    text = replace_once(
        text,
        "          if (itemId === actionId) {\n            if (actionObj.invoke) {\n",
        '          if (itemId === actionId) {\n            if (actionId === "default") {\n              invoked = focusBrowserAppWindow(notifData.notification);\n              if (invoked) {\n                break;\n              }\n            }\n            if (actionObj.invoke) {\n',
        "default action focus",
    )

    focus_sender_replacement = r"""  function isBrowserAppName(appName) {
    const name = (appName || "").toLowerCase();
    return name === "brave" || name === "chrome" || name === "chromium";
  }

  function isBrowserWindowId(appId) {
    const id = (appId || "").toLowerCase();
    return id.startsWith("brave-") || id.startsWith("chrome-") || id.startsWith("chromium-");
  }

  function focusWindowByAppId(appId) {
    const targetAppId = (appId || "").toLowerCase();
    if (!targetAppId)
      return false;

    for (var i = 0; i < CompositorService.windows.count; i++) {
      const win = CompositorService.windows.get(i);
      const winAppId = (win.appId || "").toLowerCase();
      if (winAppId === targetAppId) {
        CompositorService.focusWindow(win);
        return true;
      }
    }

    return false;
  }

  function focusPreferredBrowserWindow() {
    if (root.lastFocusedBrowserAppId && focusWindowByAppId(root.lastFocusedBrowserAppId)) {
      return true;
    }

    let mainBrowserWindow = null;

    for (var i = 0; i < CompositorService.windows.count; i++) {
      const win = CompositorService.windows.get(i);
      const winAppId = (win.appId || "").toLowerCase();

      if (!isBrowserWindowId(winAppId)) {
        continue;
      }

      if (winAppId === "brave-browser" || winAppId === "google-chrome" || winAppId === "chromium-browser") {
        if (!mainBrowserWindow) {
          mainBrowserWindow = win;
        }
        continue;
      }

      CompositorService.focusWindow(win);
      return true;
    }

    if (mainBrowserWindow) {
      CompositorService.focusWindow(mainBrowserWindow);
      return true;
    }

    return false;
  }

  function extractNotificationKeywords(notification) {
    const rawText = ((notification.summary || "") + " " + (notification.body || "")).toLowerCase();
    const normalizedText = rawText.replace(/[^a-z0-9.]+/g, " ");
    const keywords = [];

    function addKeyword(value) {
      const normalized = (value || "").toLowerCase().replace(/[^a-z0-9]+/g, "").trim();
      if (normalized.length < 3)
        return;
      if (!keywords.includes(normalized)) {
        keywords.push(normalized);
      }
    }

    const parts = normalizedText.split(/\s+/);
    for (var i = 0; i < parts.length; i++) {
      addKeyword(parts[i]);
    }

    return keywords;
  }

  function getBrowserAppEntry(appId) {
    const normalizedAppId = (appId || "").toLowerCase();
    for (var i = 0; i < browserAppEntries.length; i++) {
      const entry = browserAppEntries[i];
      if (entry.appId === normalizedAppId) {
        return entry;
      }
    }
    return null;
  }

  function findBestBrowserAppWindow(notification) {
    const keywords = extractNotificationKeywords(notification);
    let bestWindow = null;
    let bestScore = 0;

    for (var i = 0; i < CompositorService.windows.count; i++) {
      const win = CompositorService.windows.get(i);
      const winAppId = (win.appId || "").toLowerCase();
      if (!isBrowserWindowId(winAppId)) {
        continue;
      }

      const entry = getBrowserAppEntry(winAppId);
      if (!entry)
        continue;

      const entryTokens = entry.normalizedName.split(/\s+/).filter(token => token.length >= 3);
      let score = 0;
      for (var j = 0; j < entryTokens.length; j++) {
        if (keywords.includes(entryTokens[j])) {
          score += 100;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestWindow = win;
      }
    }

    return {
      "window": bestWindow,
      "score": bestScore
    };
  }

  function focusBrowserAppWindow(notification) {
    if (!notification)
      return false;

    const match = findBestBrowserAppWindow(notification);
    if (match.window && match.score >= 100) {
      CompositorService.focusWindow(match.window);
      return true;
    }

    if (isBrowserAppName(notification.appName)) {
      return focusPreferredBrowserWindow();
    }

    return false;
  }

  function focusSenderWindow(appName) {
    if (!appName || appName === "" || appName === "Unknown")
      return false;

    if (isBrowserAppName(appName)) {
      if (focusPreferredBrowserWindow()) {
        return true;
      }
    }

    const normalizedName = appName.toLowerCase().replace(/\s+/g, "");

    for (var i = 0; i < CompositorService.windows.count; i++) {
      const win = CompositorService.windows.get(i);
      const winAppId = (win.appId || "").toLowerCase();

      const segments = winAppId.split(".");
      const lastSegment = segments[segments.length - 1] || "";

      if (winAppId === normalizedName || lastSegment === normalizedName || winAppId.includes(normalizedName) || normalizedName.includes(lastSegment)) {
        CompositorService.focusWindow(win);
        return true;
      }
    }

    Logger.d("NotificationService", "No window found for app: " + appName);
    return false;
  }
"""

    text = re.sub(
        r"  function focusSenderWindow\(appName\) \{.*?\n  function removeFromHistory\(notificationId\) \{",
        lambda match: (
            focus_sender_replacement
            + "\n  function removeFromHistory(notificationId) {"
        ),
        text,
        count=1,
        flags=re.S,
    )

    path.write_text(text)


if __name__ == "__main__":
    main()
