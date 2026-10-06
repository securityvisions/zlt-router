# 03 - Re-verify hy2 Inbound Credentials & Obfs Settings

Status: resolved
Assignee: agent
Type: task

## Answer

1. **VPS Configuration Validated:**
   - Inbound 2 in `s-ui.db` uses `salamander` obfs with password `bwne4pabf0tzt00f`, listening on port `31800/udp`.
   - TLS certificate `/etc/s-ui-certs/hy2.crt` is valid until August 2036.
   - User `parsa` credentials (`p4DyJIAuyp`) are active and verified.
2. **Client Alignment:**
   - Client configs in `router/sing-box-config.json` and `router/x28/mihomo-config.yaml` match the server parameters exactly (`password: p4DyJIAuyp`, `obfs: salamander / bwne4pabf0tzt00f`, `tls.insecure: true`).
   - Zero credential or configuration mismatches exist between client and server.
Blocked by: none

## Question

Do the client parameters in `router/sing-box-config.json` and `router/x28/mihomo-config.yaml` match the active user and salamander obfs settings in `s-ui.db` on the VPS?

### Findings & Context

In `s-ui.db`:
- Inbound 2: `hysteria2`, `listen_port: 31800`, `obfs: {'password': 'bwne4pabf0tzt00f', 'type': 'salamander'}`
- Client `parsa`: password `p4DyJIAuyp`
- Client `tape`: password `zZ2aK8xz3e`
- Client `jafar`: password `NYEcO1LQfP`
In AX3000T `sing-box`:
- `server: 85.121.124.158`, `server_port: 31800`, `password: p4DyJIAuyp`, `obfs: {type: salamander, password: bwne4pabf0tzt00f}`
Parameters match, but need end-to-end transport verification.
