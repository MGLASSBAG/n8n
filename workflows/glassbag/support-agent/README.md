# GlassBag Support Agent System

This folder contains the 4 n8n workflows that make up the GlassBag.ie automated customer support system. They work together around a central **Google Sheet** ("GlassBag Support System") that acts as the shared state/queue.

## Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │         Gmail: info@glassbag.ie      │
                    │         (inbound customer emails)     │
                    └──────────────┬───────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────────┐
                    │  1. MULTI-THREAD CONTEXT SUPPORT     │
                    │     AGENT (UerkpzQcPageyMYD)         │
                    │     - Polls every 45 mins            │
                    │     - Fetches unread threads          │
                    │     - Looks up customer (Shopify/Woo) │
                    │     - Gets collection schedule        │
                    │     - AI classifies email             │
                    │     - AI drafts reply                 │
                    │     - Auto-sends OR queues for review │
                    │     - Sends admin summary email       │
                    │     STATUS: INACTIVE                  │
                    └──────┬────────────┬──────────────────┘
                           │            │
              ┌────────────▼──┐    ┌────▼──────────────────┐
              │ Google Sheet   │    │ Google Sheet           │
              │ "Main Support  │    │ "Pending Actions       │
              │  Inbox Log"    │    │  Queue"                │
              │ (gid=0)        │    │ (gid=22198673)         │
              └──┬─────────┬──┘    └────────────────────────┘
                 │         │
    ┌────────────▼──┐   ┌──▼──────────────────────────────┐
    │ Admin reviews  │   │  3. SUPPORT SUMMARY DIGEST       │
    │ draft_status   │   │     (cZ98HFjao5z48y0w)          │
    │ column, sets   │   │     - Runs at noon + 8pm         │
    │ "approved"     │   │     - Reads both sheets           │
    │                │   │     - Builds KPI digest email     │
    │                │   │     - Sends to mark@ + david@     │
    │                │   │     STATUS: ACTIVE                │
    └────────┬───────┘   └──────────────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────────┐
    │  2. SEND APPROVED DRAFTS             │
    │     (ifyN0zAPSvYeFgk3)              │
    │     - Polls sheet every minute       │
    │     - Finds draft_status="approved"  │
    │     - Sends Gmail reply              │
    │     - Updates sheet: "sent"          │
    │     - Creates pending action if needed│
    │     STATUS: ACTIVE                   │
    └─────────────────────────────────────┘

    ┌─────────────────────────────────────┐
    │  4. ONLINE CHAT SUPPORT AGENT        │
    │     (ASFqDyfYPh2FxL5Q)              │
    │     - Webhook: POST /emily-ticket    │
    │     - Logs chat/call tickets to      │
    │       "Call & Chat Log" sheet         │
    │     STATUS: ACTIVE                   │
    └─────────────────────────────────────┘
```

## The Workflows

### 1. Multi-Thread Context Support Agent
- **File:** `multi-thread-context-support-agent.json`
- **n8n ID:** `UerkpzQcPageyMYD`
- **Status:** INACTIVE (this is the main agent, currently disabled)
- **Trigger:** Schedule — every 45 minutes
- **Nodes:** 55

This is the core workflow. It processes inbound emails through a multi-stage pipeline:

**Phase 1 — Email Retrieval & Parsing**
- Fetches 1 unread Gmail thread from info@glassbag.ie
- Extracts the most recent unread message
- Builds full thread context (last 4 messages, up to 8000 chars)
- Strips HTML, removes quoted text, decodes base64
- Detects Shopify contact form emails and extracts structured data
- Filters out automated emails (Shopify notifications, Stripe receipts, delivery failures, OOO, etc.)

**Phase 2 — Customer Lookup & Enrichment**
- Looks up customer by email in both **Shopify** and **WooCommerce** (parallel)
- Picks the best match based on data completeness (weighted scoring: eircode=2, name/phone/address/city/province=1 each)
- Determines customer type: `subscriber` (Active Subscriber Shopify tag), `once_off` (Shopify but no subscription), or `unknown`
- Calls the **GlassBag Collection Schedule API** (`gbr-api.vercel.app/api/collection-date`) with eircode + province
- Returns next collection date, area code, collection day/week, days until collection, plus alias/alternate route schedules

**Phase 3 — AI Classification (GPT-5.2)**
- Sends email + thread context + customer metadata to OpenAI
- Returns structured JSON classification:
  - **category:** collection_issue, bag_issue, account_admin, sales_inquiry, spam_or_other
  - **subcategory:** missed_customer_fault, missed_our_fault, replacement_needed, cancel_request, refund_request, etc.
  - **action_type:** attempt_reschedule, deliver_bag, cancel_customer, refund_customer, update_contact, none, etc.
  - **tone:** neutral, polite, frustrated, angry
  - **urgency:** low, normal, high
  - **needs_admin:** boolean (escalation flag)
  - **auto_send_eligible:** boolean
  - **requires_verification:** boolean + questions
  - **no_reply_needed:** boolean (courtesy message detector)

**Phase 4 — Business Rules (deterministic, overrides AI)**
- Billing/refund/cancel responses NEVER auto-send (policy override)
- missed_our_fault always creates a task
- Alias schedule suggestions always create a task
- No-reply-needed emails stop all actions
- Courtesy closers ("Thanks", "Perfect") are detected and not replied to

**Phase 5 — Reply Generation (GPT-5.2)**
- Builds dynamic system/user prompts with:
  - Deterministic greeting line (first name or email local part)
  - Hard rules injected based on classification (collection date, portal links, "how it works" text)
  - Scenario hints based on intent patterns (forgot bag, wants sooner, asks about schedule)
- AI generates a short, practical reply (2-4 sentences, signed "Thanks, Mark.")

**Phase 6 — Action**
- **Auto-send path:** Sends Gmail reply, marks sheet as "auto_sent", removes UNREAD labels
- **Manual review path:** Saves draft to sheet with `draft_status=pending_review`, creates task in Pending Actions Queue if needed
- **Always:** Sends admin summary email to mark@glassbag.ie with full classification + drafted reply

### 2. Send Approved Drafts
- **File:** `send-approved-drafts.json`
- **n8n ID:** `ifyN0zAPSvYeFgk3`
- **Status:** ACTIVE
- **Trigger:** Google Sheets Trigger — polls "Main Support Inbox Log" every minute for `draft_status` column changes; also has manual trigger
- **Nodes:** 15

Handles the human-in-the-loop approval step:
1. Reads rows where `draft_status = "approved"` from the Main Support Inbox Log
2. Validates the row has `ai_drafted_reply` and `thread_id`
3. Sends the reply via Gmail (as a thread reply using `message_id`)
4. Updates the sheet: `draft_status = "manually_approved_sent"`, `processed = TRUE`
5. If `create_task = TRUE`, builds a detailed Pending Actions row with full customer context and writes it to the Pending Actions Queue
6. Removes UNREAD labels from Gmail messages and threads

### 3. Support Summary Digest
- **File:** `support-summary-digest.json`
- **n8n ID:** `cZ98HFjao5z48y0w`
- **Status:** ACTIVE
- **Trigger:** Schedule — noon and 8pm daily
- **Nodes:** 7

Daily reporting workflow:
1. Reads all rows from "Main Support Inbox Log"
2. Reads all rows from "Pending Actions Queue"
3. Builds a rich HTML digest email with:
   - KPI chips: total messages today, needs admin count, tasks created, pending actions
   - Breakdown by category and draft status
   - Top 10 support messages table (time, from, subject, category, status, admin flag, task flag)
   - Top 10 pending actions table (created, customer, email, action type, priority, status)
4. Sends to mark@glassbag.ie and david@glassbag.ie

### 4. Online Chat Support Agent
- **File:** `online-chat-support-agent.json`
- **n8n ID:** `ASFqDyfYPh2FxL5Q`
- **Status:** ACTIVE
- **Trigger:** Webhook — `POST /emily-ticket`
- **Nodes:** 2

Simple webhook-to-sheet logger for live chat and phone interactions:
- Receives POST with: timestamp, customer_name, session_id, channel, email, phone, eircode, summary, topic, next_steps, transcript, source
- Writes to "Call & Chat Log" sheet (gid=2012516939) in the same GlassBag Support System spreadsheet

## Central Data Store

All workflows share one Google Sheet: **"GlassBag Support System"**
- Spreadsheet ID: `1oZXUNzltB7SErRNGFAp4q2a-I2XHgSrfEFhDIfsp1iA`

### Sheet: Main Support Inbox Log (gid=0)
The primary log of every processed email. Key columns:

| Column | Purpose |
|--------|---------|
| `timestamp` | When email was received |
| `thread_id` | Gmail thread ID |
| `message_id` | Gmail message ID (primary key) |
| `email_from` | Sender email |
| `subject` | Email subject |
| `body_cleaned` | Cleaned email body |
| `thread_context` | Last 4 messages for AI context |
| `thread_full_text` | Full thread (up to 8000 chars) |
| `name` | Customer name |
| `customer_found` | Found in Shopify/WooCommerce? |
| `isSubscriber` | Active subscription? |
| `customer_source` | "shopify" or "woocommerce" |
| `address_1`, `address_2`, `province`, `eircode` | Address fields |
| `phone` | Phone number |
| `collection_date` | Next collection date |
| `category` | AI classification |
| `subcategory` | AI sub-classification |
| `tone` | Customer tone (neutral/polite/frustrated/angry) |
| `urgency` | low/normal/high |
| `needs_admin` | Escalation flag |
| `auto_send_eligible` | Can be auto-sent? |
| `requires_verification` | Needs factual verification? |
| `verification_reason` | Why verification needed |
| `action_type` | Required action |
| `ai_drafted_reply` | AI-generated reply text |
| `draft_status` | auto_sent / pending_review / manually_approved_sent / no_email |
| `create_task` | Task created in Pending Actions? |
| `customer_intent` | AI-identified intent |
| `summary` | AI summary |
| `processed` | Fully processed? |
| `sent_timestamp` | When reply was sent |
| `approved_at` | When manually approved |
| `admin_notes` | Admin notes |

### Sheet: Pending Actions Queue (gid=22198673)
Tasks requiring manual follow-up:

| Column | Purpose |
|--------|---------|
| `created_at` | Task creation time |
| `source_message_id` | Gmail message that triggered it |
| `action_type` | attempt_reschedule, deliver_bag, cancel_customer, refund_customer, etc. |
| `status` | pending / open / completed |
| `assignee` | ADMIN |
| `customer_name` | Customer name |
| `email` | Customer email |
| `phone`, `address`, `province`, `eircode` | Contact details |
| `notes` | AI summary + context |
| `priority` | low/normal/high |
| `alias_onceoff_created` | Uses alias schedule? |
| `alias_area_code` | Alias route area code |
| `alias_collection_date` | Target date for alias |
| `completed_at` | When completed |

### Sheet: Call & Chat Log (gid=2012516939)
Logged by the Online Chat Support Agent webhook.

## External APIs & Services

| Service | Endpoint | Auth | Purpose |
|---------|----------|------|---------|
| Gmail | OAuth2 via n8n | `info@glassbag.ie` (ID: 6lB6mgLBMfvG3wjl) | Read/send/reply emails, manage labels |
| Google Sheets | OAuth2 via n8n | ID: VMxnAmLOE69buuPK | All sheet reads/writes |
| Shopify Admin | `glassbag-ie.myshopify.com/admin/api/2023-10/` | Access token in header | Customer lookup by email |
| WooCommerce | `glassbottlebin.ie/wp-json/wc/v3/` | HTTP Basic Auth (ID: BaAsxtNsh2ItOo7n) | Customer lookup by email |
| Collection Schedule API | `gbr-api.vercel.app/api/collection-date` | None (public) | Next collection date by eircode |
| OpenAI | GPT-5.2-2025-12-11 | ID: DPaojBOcshDfeEBJ | Classification + reply generation |

## AI Classification Taxonomy

```
category                  subcategory                action_type
─────────────────────────────────────────────────────────────────
collection_issue          missed_customer_fault      attempt_reschedule
                          missed_our_fault           attempt_reschedule
                          missed_no_text_received    investigate_phone_number
bag_issue                 replacement_needed         deliver_bag
account_admin             contact_update             update_contact
                          billing_issue              update_billing
                          cancel_request             cancel_customer
                          refund_request             refund_customer
                          general_query              none
sales_inquiry             new_customer               none
spam_or_other             spam                       none
                          other                      none
```

## Business Rules (Hard-coded, Override AI)

1. **Never auto-send:** billing_issue, refund_request, cancel_request
2. **Always create task:** missed_our_fault, deliver_bag, update_contact, update_billing, cancel_customer, refund_customer
3. **No-reply detection:** Courtesy closers ("Thanks", "Perfect", "Cheers") stop all actions
4. **Alias schedule:** If suggesting an earlier collection via alternate route, always creates a task (never auto-sends)
5. **Escalation:** angry/frustrated tone OR multi-issue emails always flag needs_admin
6. **Admin summary:** Every processed email generates a summary to mark@glassbag.ie regardless of outcome

## Known Issues & Current State

- The main agent (UerkpzQcPageyMYD) is currently **INACTIVE** — it was a previous iteration
- The Send Approved Drafts and Summary Digest workflows are **ACTIVE** and work with whatever data is in the sheet
- The online-chat-support-agent has only 2 nodes — it's a simple webhook logger, not a full agent
- There's an orphan node "Check Contact Form1" in the main agent that's defined but not connected to anything
- Two "Ensure Sheet Update" nodes are no-op passthrough hacks to force execution ordering
