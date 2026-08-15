# ADR-0011: Message center — templates and bulk flow via share sheet

**Status**: Accepted (wayfinder ticket #13, chart-time fork: share intents only)

## Context

The vision wants personalized monthly billing messages with template variables (`{name} {month} {usage} {amount} {remaining} {due_date}`), custom templates, and a bulk flow (select unpaid users → generate → share), with copy + Android share sheet.

## Decision

- Room table `message_templates`: `id` (TEXT PK), `name`, `body` (TEXT), `createdAt`. Seeded with one default Persian template. Selective default stored in `Store`.
- Pure `MessageCenter.render(template, person, month, amounts)` object: substitutes the variable set `{name} {month} {usage} {amount} {remaining} {due_date} {credits}` using the Format/Persian conventions; unit-tested.
- **Share intents only**: copy-to-clipboard + Android `ACTION_SEND` share sheet (SMS, Telegram, WhatsApp, anything). No SMS permission, no Telegram bot.
- Bulk flow: Ledger screen → filter (unpaid preset) → multi-select persons → «ارسال پیام قبض» → preview list of rendered messages → copy one or share each. Amounts come from the Payments-aware projections (ADR-0001).
- Message center screen: template editor (body + variable legend), preview, and per-person message history (generated strings, not stored).

## Consequences

- Messaging is a pure render seam plus the share-sheet integration — no new permissions.
- The bulk "unpaid" filter stays correct as payments/credit change the projection (ADR-0001).