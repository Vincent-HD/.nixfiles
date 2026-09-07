# DankCalendar Google Calendar

After switching the configuration, the `dcal` user service starts with the graphical session:

```bash
sudo nixos-rebuild switch --flake .#pc-fixe
systemctl --user status dcal
```

Add Google Calendar interactively from the logged-in user session. The first command prints the
one-time OAuth setup instructions; the second opens the browser sign-in flow:

```bash
dcal account setup google
dcal account add google
```

The account list and a manual sync are useful checks:

```bash
dcal account list
dcal sync
```

OAuth tokens are stored by `dcal` in the existing GNOME Keyring through Secret Service. Keep the
OAuth flow user-owned and do not add client secrets or tokens to Nix files, environment declarations,
or this repository. DMS 1.6 is configured declaratively with the `dankcal` calendar backend and
automatically discovers the running daemon.
