# Spotify Soloist on pc-fixe

Spotify Soloist dynamically picks an IPv4 TCP port for Spotify Connect pairing.
Spotifast 0.17.1 launches Soloist with a separate loopback WebSocket endpoint at
`127.0.0.1:0`. There is no supported setting for a fixed Connect port.
See the [Soloist CLI reference](https://developer.spotify.com/documentation/soloist/reference/command-line),
the [fixed-port feature request](https://github.com/spotify/soloist/issues/4),
and the [Spotifast launcher](https://github.com/crmne/spotifast/blob/v0.17.1/src/soloist/mod.rs#L412).

The Spotifast NixOS module scopes shared Avahi mDNS traffic on UDP 5353 to the
wired LAN on `enp4s0` from `192.168.1.0/24` or IPv6 link-local addresses.
The existing iptables firewall allows IPv4 pairing traffic from that interface
and subnet only when the destination port is in the `soloist-connect` set.

`soloist-firewall.service` replaces the set every two seconds using IPv4
wildcard TCP listeners owned by the desktop user whose process executable is
inside Spotifast's Soloist builds directory. Loopback listeners are excluded.
The kernel expires entries after five seconds if refreshes stop. A port released
between scans stays eligible for new connections until the next scan or expiry.
Discovery can also precede the first scan by up to two seconds. Retry pairing
if the client attempts to connect during that interval.

After activating the configuration, open Spotifast and inspect the current set
while Soloist runs:

```bash
systemctl status soloist-firewall.service
sudo nix shell .#nixosConfigurations.pc-fixe.pkgs.ipset -c ipset list soloist-connect
```
