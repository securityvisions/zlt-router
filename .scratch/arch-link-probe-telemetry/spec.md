# arch-link-probe-telemetry — spec

Deepen the three shallow seams that block a correct failover ladder: LinkState (one Link reader), ProbeService (one probing budget), TelemetryStore (one history). Together they eliminate 7 probe endpoints, 2 logs, and 3 Link parsers and unblock the PassWall ladder ordering (LinkDegraded → Operator → NodeRotate → FailOpen).

## Context

Hot-spot scan of `57248b0…ef0b512` (X28 promotion): 6 procd daemons on the X28, two telemetry stores (`/etc/telemetry/hourly.log` vs `/data/proxy/usage/telemetry.log`), seven probe isolates, four Link readers. The only deep module is `hnlib.sh`; everything else re-parses text.

## Tickets

1. LinkState seam — one Link reader + LinkPolicy.decide
2. ProbeService seam — one probing budget + ProbeProfile per Link/PassWall/VPS
3. TelemetryStore seam — one history with LinkState + ProbeSample

Edges: 01 -> 02 -> 03 (02 reads LinkState; 03 stores LinkState + ProbeSample).
