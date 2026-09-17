# Retired n8n Workflow Archive

**Status: retired.** The GoSimple n8n service no longer exists. Its functionality has been implemented in the relevant application repositories.

This repository retains historical workflow exports for reference. It is not a deployment target or the source of truth for current automation. Make operational changes in the application repository that now owns the functionality.

Do not use the archived pull or push scripts to provision, import, or reactivate workflows. References to active workflows below describe their status when exported, not a running service.

## Businesses

The archived workflows supported two brands under the GoSimple.ie family:

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

## Historical Workflows (13)

| n8n ID | Name | Status at export | Category |
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

## Related Repos

- **gbr-api** — GlassBag/JunkIreland Vercel API. This archive records workflows that previously called its endpoints. Current implementations belong in the relevant application repositories.
