# AGENTS.md

Guidance for coding agents working in this repo.

## Project

This repo tracks the **home-network** project: an OpenWrt router (Xiaomi Mi Router AX3000T at `192.168.1.1`) that runs an automated monitoring & alerting system delivered through a Telegram bot (**@xirouterbot**).

The running system lives on the **router**, not in this repo:

- Scripts: `/root/{tg,usage,billing,balance,hyst,devicewatch,botcmd,monthly}.sh` on the router
- Config: `/etc/{tg,samantel,billing}.conf` on the router
- This repo holds docs, specs, and planning artifacts

## Agent skills

### Issue tracker

Issues and specs live as local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default triage vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

## Conventions

- Read `CONTEXT.md` before doing anything in this repo.
- Check `docs/adr/` for decisions relevant to the area you're touching.
- Specs go under `.scratch/<feature-slug>/spec.md`.
- Router changes are applied over SSH (`sshpass ... ssh root@192.168.1.1`); this repo never contains router secrets in plaintext.
