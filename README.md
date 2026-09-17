# GoSimple n8n Workflows

This repo is the **single source of truth** for all n8n workflows running on our GoSimple n8n cloud instance.

**Live instance:** https://gosimple.app.n8n.cloud

## Businesses

We manage automation workflows for two brands under the GoSimple.ie family:

- **GlassBag.ie** — Doorstep glass bottle collection service (Shopify/WooCommerce/ReCharge)
- **JunkIreland.ie** — Professional junk removal service (Shopify)

## Folder Structure

```
workflows/
├── glassbag/          # GlassBag.ie specific workflows
├── junkireland/       # JunkIreland.ie specific workflows
├── shared/            # Multi-store or shared workflows
└── scripts/
    ├── pull-all.sh    # Pull all active workflows from n8n
    └── push.sh        # Push a local workflow to n8n
```

## Setup

1. Clone this repo
2. Create `.env` with your n8n API key:
   ```
   N8N_API_KEY=your-api-key-here
   ```

## Pulling Workflows

Pull all active workflows from the live n8n instance:

```bash
./workflows/scripts/pull-all.sh
```

This fetches every active workflow, strips metadata, adds a `_meta` block with the n8n ID and pull timestamp, and saves each to the correct subfolder.

## Pushing Workflows

Push a local workflow back to n8n:

```bash
./workflows/scripts/push.sh workflows/glassbag/fulfil-shopify-orders.json
```

The script:
1. Reads `_meta.n8n_id` from the file to identify the target workflow
2. Fetches the current live version (safety check)
3. PUTs the local version
4. Verifies the response (ID match, node count)

## Workflows (13)

| n8n ID | Name | Status | Category |
|--------|------|--------|----------|
| LyNkq3x02qKMwuKA | Blog Post Automation v3 (Multi-Store) | Active | shared |
| vcPlqvIsK0kYr5eT | Blog Topic Generation v3 (Multi-Store) | Active | shared |
| 0zznUUxrSocIzqQm | Once-Off & Inactive Subscriber Re-engagement | Active | glassbag |
| 5N4mMmmm4iTOUpH3 | Pending Action & Alias Once-Off Scheduler | Active | glassbag |
| ASFqDyfYPh2FxL5Q | Online Chat Support Agent | Active | glassbag |
| Ty7TNdNQjjLjDIHg | Update Once Off Sheet via Emily Chat | Active | glassbag |
| UerkpzQcPageyMYD | Multi-Thread Context Support Agent | Inactive | glassbag |
| XI1fqRQ4kuEEAZWy | Fulfil Shopify Orders / 7am | Active | glassbag |
| cZ98HFjao5z48y0w | Support Summary Digest | Active | glassbag |
| i1tOtrTnPJc6pVnu | Sets Once Off Tag / 6am | Active | glassbag |
| ifyN0zAPSvYeFgk3 | Send Approved Drafts | Active | glassbag |
| sOdT7YUhaEYdKe3w | WooCommerce/ReCharge Max Retries Webhook | Active | glassbag |
| uwUqy4eJkrPDiXOO | Create Collection List | Active | glassbag |

## Workflow Lifecycle

1. **Edit locally** — Make all changes to the JSON files in this repo
2. **Push to n8n** — Use `push.sh` to deploy changes to the live instance
3. **Never edit live** — If someone edits in the n8n UI, pull the changes back here first

## Related Repos

- **gbr-api** (`/mnt/c/dev/gbr-api`) — GlassBag/JunkIreland Vercel API. Contains endpoints called by many of these workflows. Previously stored workflow JSON — this repo is now canonical.
