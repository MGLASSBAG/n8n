# n8n Workflow Management — GoSimple

Writing and client-facing docs: see AGENTS.md.

## Project Overview
This repo is the single source of truth for all n8n workflows running on our GoSimple n8n cloud instance (https://gosimple.app.n8n.cloud). It manages automation workflows for two businesses:
- **GlassBag.ie** — Doorstep glass bottle collection service (Shopify/WooCommerce/ReCharge)
- **JunkIreland.ie** — Professional junk removal service (Shopify)

Both are part of the GoSimple.ie family of services.

## n8n REST API Rules (CRITICAL)
- Base URL: `https://gosimple.app.n8n.cloud/api/v1`
- Auth: `X-N8N-API-KEY: $N8N_API_KEY` (from .env)
- ALWAYS read the current live workflow (`GET /workflows/:id`) before making changes
- Update existing workflows in place (`PUT /workflows/:id`) with these fields only: `name`, `nodes`, `connections`, `settings`
- NEVER create duplicate workflows when an existing one should be updated
- NEVER change active/inactive state unless explicitly requested
- After every update, verify: response has expected workflow `id`, `nodes.length` matches, critical node names exist
- Keep local JSON as source of truth, then push via API
- To list all workflows: `GET /workflows` (optionally `?active=true`)

## Workflow File Organisation
```
workflows/
├── glassbag/          # GlassBag.ie specific workflows
├── junkireland/       # JunkIreland.ie specific workflows
├── shared/            # Multi-store or shared workflows
└── scripts/           # Helper scripts for syncing/deploying
```

Each workflow JSON file should be named descriptively in kebab-case matching its n8n name, e.g. `fulfil-shopify-orders.json`.

## Workflow Lifecycle
- All changes are made locally in this repo first, then pushed to n8n via the REST API
- Every workflow file must have a `_meta` block noting its n8n ID, purpose, and schedule
- Before pushing, always GET the live version first to avoid overwriting someone else's changes

## Live Workflow Registry (13 workflows as of 2026-02-23)

| n8n ID | Name | Status | Category |
|--------|------|--------|----------|
| LyNkq3x02qKMwuKA | Blog Post Automation v3 (Multi-Store) | ACTIVE | shared |
| vcPlqvIsK0kYr5eT | Blog Topic Generation v3 (Multi-Store) | ACTIVE | shared |
| 0zznUUxrSocIzqQm | GlassBag.ie: Once-Off & Inactive Subscriber Re-engagement | ACTIVE | glassbag |
| 5N4mMmmm4iTOUpH3 | Glassbag.ie - Pending Action & Alias Once-Off Scheduler | ACTIVE | glassbag |
| ASFqDyfYPh2FxL5Q | Glassbag.ie: Online Chat Support Agent | ACTIVE | glassbag |
| Ty7TNdNQjjLjDIHg | Update Once Off Sheet via Emily Chat + New Subscription Order via WooCommerce | ACTIVE | glassbag |
| XI1fqRQ4kuEEAZWy | GlassBag.ie - Fulfil Shopify Orders / 7am | ACTIVE | glassbag |
| cZ98HFjao5z48y0w | Glassbag.ie: Support Summary Digest | ACTIVE | glassbag |
| i1tOtrTnPJc6pVnu | GlassBag.ie - Sets Once Off Tag / 6am | ACTIVE | glassbag |
| ifyN0zAPSvYeFgk3 | GlassBag.ie - Send Approved Drafts | ACTIVE | glassbag |
| sOdT7YUhaEYdKe3w | Glassbag.ie - WooCommerce/ReCharge Max Retries Webhook | ACTIVE | glassbag |
| UerkpzQcPageyMYD | Glassbag.ie - Multi-Thread Context Support Agent | INACTIVE | glassbag |
| uwUqy4eJkrPDiXOO | Glassbag.ie - Create Collection List | ACTIVE | glassbag |

## Recent Changes (2026-02-23)
The Blog Post Automation v3 workflow (LyNkq3x02qKMwuKA) was recently updated with:
1. **Dynamic Pricing in HTML** — JunkIreland blog posts now wrap all prices in `<span data-live-price="product-handle">€X</span>` tags so a JS file (live-pricing.js) on the Shopify theme can auto-update them. Full handle lookup table is in the Build Prompt node.
2. **Factual Accuracy rules** — The JunkIreland system prompt now has a FACTUAL ACCURACY section prohibiting fabricated statistics, third-party prices, council fees, or regulatory figures. Only JunkIreland's own product prices may be stated as fact.

## Shared Credentials (for reference, do not store secrets)
| Credential | n8n ID | Name |
|---|---|---|
| Google Sheets OAuth2 | VMxnAmLOE69buuPK | Google Sheets account |
| Gmail OAuth2 | 6lB6mgLBMfvG3wjl | Gmail account: info@glassbag.ie |
| OpenAI | DPaojBOcshDfeEBJ | OpenAi account |
| SerpApi | bioEhjlpnVltaNy9 | SerpApi account |
| JunkIreland Shopify | sEj00VzPrNSAoOba | JunkIreland Shopify Admin API |

## Related Repos
- **gbr-api** (`/mnt/c/dev/gbr-api`) — The GlassBag/JunkIreland API (Vercel serverless). Contains the API endpoints that many of these workflows call (collection-date, customer-profile, update-once-off-sheet, etc.). Previously held workflow JSON files in its `/workflows/` directory — this n8n repo is now the canonical source.
