# 02 — Add VLESS+REALITY node as a selectable node

**What to build:** The REALITY-443-parsa node becomes available in PassWall and works as a standalone proxy node, without changing the active default. The node is decoded from this VLESS URI (source of truth for all credentials):

`vless://<uuid-redacted>@85.121.124.158:443?pbk=<reality-pubkey-redacted>&security=reality&sid=7fa7e3ce4165cba3&sni=www.microsoft.com&spx=%2F9ec568fc564cf86&type=tcp#REALITY-443-parsa`

Fields: address 85.121.124.158:443, protocol VLESS+REALITY over TCP, UUID `<uuid-redacted>`, Reality public key `<reality-pubkey-redacted>`, short id `7fa7e3ce4165cba3`, SNI `www.microsoft.com`, spiderX `/9ec568fc564cf86`, remark REALITY-443-parsa. Flow unset.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The node appears in PassWall's node list under the remark REALITY-443-parsa
- [ ] It passes PassWall's standalone node connectivity test (returns 200)
- [ ] The global TCP node is unchanged — hysteria remains the active default
- [ ] Backups from ticket 01 are verified intact before changes
