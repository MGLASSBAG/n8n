# Agent Instructions — GoSimple n8n repo

## Writing and client-facing artifacts
Style: Tim Pope / Chris Beams commits; Google developer docs + Simplified Technical English for prose.
Dead prose. Short sentences. No aphorisms, flourishes, or marketing adjectives.
Commits: imperative subject (~50 chars), explain why, one logical change, never mention the tool.

### Client-facing docs, spreadsheets, decks, PDFs
These are external. Write as the company speaking to a customer, accountant, partner, or the public.
- Use repo context for brand names, products, prices, legal entities, and how the business actually works.
- Do not invent numbers, names, dates, quotes, addresses, or sample rows. Empty / "not available" beats fake data.
- If a fact is not in the repo, look it up from a primary source (official site, Companies Registration Office, Revenue, published price list). Cite the source in an internal note if needed; do not put "we assumed" in the client file.
- If you still cannot confirm it, omit it or mark the cell/section as pending. Do not fill gaps with plausible fiction.
- Do not use internal process voice: no "management confirmed", "as discussed", "the team decided", "Mark said", "for the board pack we…".
- Do not describe how the document was produced. The document is the product.
- Spreadsheets: real columns and formulas only. No lorem rows, no dummy €1,234.56, no placeholder customer names.

### Other rules
- Never commit secrets; `.env.example` placeholders only.
- Don't add markdown files the user didn't ask for (README sprawl).
- PRs/commits: explain why, not a file list.
- Internal vs external: docs/ and engineering notes can mention cron/env details; anything emailed to or downloaded by a client cannot.
