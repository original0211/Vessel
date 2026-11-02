# NOTICE — Vessel upstream attribution

Vessel (formerly KFusion) is a derivative work distributed under the GNU General Public License
v3.0 (see `LICENSE`, kept verbatim from upstream). This file records where the
code and designs come from.

## Based on FlClash

- **FlClash** by chen08209 — https://github.com/chen08209/FlClash
  Licensed under GPL-3.0.
  KFusion P0 is a fork of FlClash v0.9.1 (commit 8d4f974), reduced to the
  Android and Windows targets and rebranded. The original copyright and
  license are preserved in `LICENSE` and in the source file headers.
  The upstream repository remains available as the git remote `upstream`.

## Proxy core

- **mihomo / Clash.Meta** — https://github.com/MetaCubeX/mihomo
  (vendored as the `core/Clash.Meta` git submodule, FlClash branch of
  https://github.com/chen08209/Clash.Meta)
  Licensed under GPL-3.0. One of the two cores shipped in the current
  product; configurations pass through it with full fidelity.

## Design input

- **Karing** by KaringX — https://github.com/KaringX/karing
  Licensed under GPL-3.0 with an additional term that derivative works may
  not use the Karing name or imply association with it.
  No Karing code is included. Vessel's all-format subscription import and
  its single routing template applied across subscriptions are *designs*
  informed by Karing; no Karing code or name is used. If Karing code is
  ever reused, it will be under GPL-3.0 and this notice will be updated.

- **sing-box** — https://github.com/SagerNet/sing-box (GPL-3.0)
  Ships as the second core: native sing-box JSON is used as-is, and
  Clash configurations are converted at the node layer under one
  built-in routing template — a contract subset, not a full port.

## Vessel itself

Vessel's own modifications are likewise released under GPL-3.0. There is no
affiliation with, or endorsement by, the FlClash, Karing, mihomo or sing-box
projects.
