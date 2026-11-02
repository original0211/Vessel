# NOTICE — Vessel upstream attribution

Vessel (formerly KFusion) is a derivative work distributed under the GNU General Public License
v3.0 (see `LICENSE`, kept verbatim from upstream). This file records where the
code and designs come from.

## Proxy core

- **mihomo / Clash.Meta** — https://github.com/MetaCubeX/mihomo
  (vendored as the `core/Clash.Meta` git submodule)
  Licensed under GPL-3.0. One of the two cores shipped in the current
  product; configurations pass through it with full fidelity.

- **sing-box** — https://github.com/SagerNet/sing-box (GPL-3.0)
  Ships as the second core: native sing-box JSON is used as-is, and
  Clash configurations are converted at the node layer under one
  built-in routing template — a contract subset, not a full port.

## Vessel itself

Vessel's own modifications are likewise released under GPL-3.0. There is no
affiliation with, or endorsement by, the mihomo or sing-box projects.
