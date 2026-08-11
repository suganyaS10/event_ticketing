# Event Ticketing API

A JSON API for browsing events and buying tickets.

The interesting part of this problem is not the CRUD. It is making sure two people cannot buy the same last ticket, and that a price rise mid-checkout never reaches a customer who has already been quoted.

---

## Ruby version

- **Ruby 3.4.9** — pinned in `.ruby-version` and `.tool-versions`
- **Rails 8.1.3**

## System dependencies

- **PostgreSQL** (developed against 14). Row-level locking and a check constraint do the real work here, so the database is not incidental.
- **Bundler** and the gems in `Gemfile`. Notable ones: `blueprinter` for serialisation,
  `rspec-rails`, `factory_bot_rails` and `shoulda-matchers` for tests, `rubocop-rails-omakase` and `brakeman` for static analysis.

No Node, Redis or external services are required.

## Configuration

Configuration is by environment variable, loaded from `.env.*` files via `dotenv-rails`.
`.env.example` shows what is needed:

```
DATABASE_URL="postgres://${USER}@localhost/my_database"
```

`config/database.yml` uses `DATABASE_URL` when present and otherwise falls back to
`ticketing_development` / `ticketing_test` on the local socket, so on a standard local
PostgreSQL install no configuration is needed at all.

## Database creation

```bash
bin/rails db:create
bin/rails db:schema:load
```

Or in one step, which also creates the test database:

```bash
bin/rails db:prepare
```

## Database initialization

```bash
bin/rails db:seed
```

The seeds are idempotent — re-running restores the declared state, including `quantity_sold`, so you can reset after experimenting.

Five events, each named after the scenario it exercises, so every interesting path is reachable
without any setup:

| Event | Tiers | Exercises |
|---|---|---|
| 1 · Riverside Night Market | GA £25 (60 left) · VIP £75 (15) · Child £10 (50) | happy path, mixed basket |
| 2 · Harbour Jazz Session | GA £18 (**1 left**) · Balcony £30 (**sold out**) | the last-ticket race, sold-out rejection |
| 3 · Winter Light Festival | Early Bird £15 (**window closed**) · Standard £22 | sale windows enforced by dates, not by name |
| 4 · Summer Sessions | GA £20 | **draft** — must not appear in the listing |
| 5 · Spring Warehouse Party | GA £20 | **past** — must not appear in the listing |

Then:

```bash
bin/rails server
```

## How to run the test suite

```bash
bundle exec rspec        # 110 examples
bin/rubocop              # style
bin/brakeman             # security analysis
bin/ci                   # all of the above, plus a seed run
```

## Services (job queues, cache servers, search engines, etc.)

**None.** There is no background job processing, no Redis, no cache server and no search
engine. Caching in development is `:memory_store` and Action Cable is the `async` adapter —
both Rails defaults, neither used by this API.

This is deliberate rather than unfinished. Purchasing is synchronous by nature: the customer
needs to know within the request whether they got the ticket. Pushing any of it onto a queue
would mean answering "your order is being processed", which is a worse experience and a much
harder correctness problem. The one thing that would justify a queue — sweeping expired
reservations — does not exist here, because there are no reservations (see *Next steps*).

---

## API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/events` | published, not-yet-started events with price and availability summary |
| `GET` | `/api/v1/events/:id` | one event, plus description and its ticket tiers |
| `POST` | `/api/v1/events/:event_id/orders` | buy tickets |
| `GET` | `/api/v1/orders/:order_ref` | look up an order |

```bash
curl -i -X POST http://localhost:3000/api/v1/events/2/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer": { "email": "alex@example.com", "first_name": "Alex" },
    "items": [
      { "ticket_tier_id": 4, "quantity": 1, "expected_unit_price_cents": 1800 }
    ]
  }'
```

`201 Created` with the order and its lines. Run it again — event 2's General Admission is now
exhausted — and you get:

```json
{
  "error": {
    "code": "purchase_conflict",
    "message": "Not enough tickets remain for the quantity requested - [4]"
  }
}
```

| Code | When |
|---|---|
| `201` | order created |
| `409` | request was valid, the world moved — price changed, or not enough stock |
| `422` | request itself is wrong — unknown tier, duplicate tier, closed sale window, non-numeric quantity |
| `404` | unknown event, draft event, or unknown order reference |

The 409/422 split is deliberate: **422 means fix your request; 409 means the same request might
succeed if you adjust or retry.** Every error shares one body shape with a stable `code`, so
clients branch on that rather than on prose.

---

# Design decisions

## Two customers, one last ticket

### The strategy

Everything happens in one transaction, and the tier rows are locked *before* anything is checked:

```ruby
ActiveRecord::Base.transaction do
  tiers = event.ticket_tiers
               .where(id: requested_tier_ids)
               .order(:id)          # deterministic lock order
               .lock                # SELECT ... FOR UPDATE
               .index_by(&:id)

  check_purchaseability(tiers)      # price and stock, read from the locked rows
  update_inventory!(order, tiers)
  update_order_total!(order)
  update_order_status!(order)
end
```

Three things are load-bearing.

**The checks happen inside the lock.** Availability read *before* the lock is stale the instant
it returns — that is precisely the bug. Two requests can both see "1 remaining" and both proceed.

**`ORDER BY id` comes before `.lock`.** Two customers each buying GA *and* VIP would otherwise
acquire the two rows in opposite orders and deadlock. Sorting gives every transaction the same
acquisition sequence, so no cycle can form. This is not cosmetic: `EXPLAIN` shows the plan puts
`LockRows` **above** `Sort`, so rows really are locked in id order however the scan finds them.

**A database check constraint is the actual guarantee:**

```sql
CHECK (quantity_sold >= 0 AND quantity_sold <= quantity_total)
```

The lock is the fast path; the constraint is what makes overselling *impossible* rather than
merely unlikely. It holds even if application logic is wrong, a future code path forgets to
lock, or someone runs a script against production.

### What breaks if you remove each piece

| Removed | Consequence |
|---|---|
| the row lock | Two buyers read the same `quantity_sold` and both write it back. Last write wins, one ticket sold twice. The check constraint catches the overshoot, so the *data* stays correct — but the loser gets a 500 instead of a clean 409. |
| `ORDER BY id` | Single-tier purchases are unaffected. Mixed baskets deadlock under load: one transaction holds GA waiting for VIP while another holds VIP waiting for GA. Postgres kills one after `deadlock_timeout`. |
| the check constraint | Nothing changes while the lock is correct. The day it is not — a refactor, a new endpoint, a background job — overselling becomes silent and permanent, and you hear about it from customers at the door. |
| checking inside the lock | The lock becomes decorative: you would be locking rows and then deciding on values read before you held them. |

### Trade-offs accepted

- `SELECT ... FOR UPDATE` **serialises purchases per tier**. Two people buying the same tier
  queue behind each other. That is the correct trade for money and inventory, and the critical
  section is a few milliseconds, but it does mean a single very popular tier is a throughput
  ceiling. Optimistic locking with retries would allow more concurrency at the cost of a more
  complicated failure story.
- Locks are held for the whole purchase, including writing the order and its lines. Keeping the
  transaction short matters; nothing slow (HTTP calls, mail) belongs inside it.
- **All-or-nothing baskets.** If one line cannot be filled, the whole order is rejected. Someone
  buying 2 VIP and 2 GA probably does not want only the GA, and partial fulfilment means
  explaining a partial charge.

### Evidence

Two threads on separate connections, both buying the last General Admission ticket for event 2:

```
BEFORE: sold=59/60  available=1
thread 0: success  -> ORD-CFDB10A8A1717E84  succeeded
thread 1: rejected -> Not enough tickets remain for the quantity requested
AFTER:  sold=60/60  available=0
```

Exactly one sale; the loser gets a domain error, not a crash. This is a real test in
`spec/services/orders/tickets_service_spec.rb`, not a description. It has to disable
transactional fixtures — two transactions cannot see each other's uncommitted rows, so the race
would not otherwise reproduce.

## A price change during a purchase

### The strategy

The client sends the price it displayed:

```json
{ "ticket_tier_id": 4, "quantity": 1, "expected_unit_price_cents": 1800 }
```

Inside the lock, that is compared against the tier's real price. If they differ the purchase is
rejected with `409 purchase_conflict` and the client re-quotes. Each order line stores
`unit_price_cents` as a **snapshot**, so a later price change cannot reach back into an order
already placed.

This is optimistic concurrency on price. Rejecting is the honest outcome: silently honouring the
old price means selling below what the promoter set, indefinitely; silently charging the new one
is the complaint that started this. So the customer is told, and decides.

### The lock protects the price too

While a purchase holds `FOR UPDATE` on a tier, a promoter's price update **blocks** until that
purchase commits — measured at **0.91s** against a deliberately slowed transaction. So a price
change cannot land *inside* a purchase. It happens either before it (and the guard rejects the
stale quote) or after it (and the snapshot is already written).

### Trade-offs accepted

- `expected_unit_price_cents` is **required**. That is a small burden on clients, but an optional
  price guard is not a guard — any client that omitted it would silently lose the protection.
- The client is trusted to send the price it *showed*, not one it invented. It is only ever
  compared, never written: the order always records the tier's real price, so a client cannot name its own price.
- A rejected purchase costs the customer a round trip. The alternative — holding a price quote for N minutes — needs reservations, which is out of scope.

### Evidence

Beyond the "stale quote" case, there is a test for the narrow window where the price changes
*during* a request, after validation but before the lock is taken. It passes only because the
comparison reads the **locked** row rather than the tiers loaded earlier in the same request —
verified by temporarily making it read the earlier copy, at which point the test fails.

## Smaller decisions

**Ticket tiers are rows, not an enum.** GA and VIP are instances, not a closed type system.
Promoters will invent "Balcony", "Student", "Group of 4"; with rows that costs nothing.

**Early bird is a date range, not a name.** `sale_starts_at` / `sale_ends_at` make the rule
enforceable rather than a label the application has to interpret.

**Money is integer cents.** Floats lose pennies and stop reconciling. Integer minor units are
also what payment processors expect, so adding payments introduces no conversion boundary at
exactly the point where rounding matters.

**Buyers are `customers`, not `guests`.** When authentication arrives, credentials attach to the
existing customer row — rather than a separate `users` table with a polymorphic buyer, which
would drop the foreign key on `orders` and split one person's history in two.

**Orders are addressed by an opaque `order_ref`**, not by id. Without authentication that
reference is the only thing protecting a purchase. Events are addressed by id, because the
catalogue is public and obscuring those identifiers would protect nothing. Draft events return a
404 **identical** to a missing record, so the response never confirms an unannounced event exists.

**Failed purchases are recorded** with `status: failed` and a `failure_reason`, written *after*
the transaction rolls back — written inside it, the rollback would erase the record along with
everything else. Requests rejected before an order exists leave no row: fulfilment failures are
recorded, malformed requests are not.

**Thin controller, service object.** `Orders::TicketsService` owns the transaction and raises
typed errors; the controller maps error class to HTTP status via `rescue_from` and does nothing
else.

---

# Next steps

Called out so the gaps read as decisions rather than oversights.

**Idempotency.** A retried `POST` currently creates a second order. The fix is a client-supplied
`Idempotency-Key` header with a unique index, returning the original order on replay. Note that
`order_ref` cannot do this job — it is server-generated, so a retry mints a different one.

**Reservations.** Real ticketing holds stock for a few minutes during payment. That needs an
`expires_at` column and a sweeper job — and with no payment step, there is nothing to hold *for*.

**Authentication.** Excluded by the brief. `GET /api/v1/orders` (list by email) exists but would
need real authentication before shipping: an email address is not a credential.

**A JSON 500 handler.** Unhandled exceptions currently fall through to Rails' default handling.
A production API would rescue `StandardError` at the base controller, log the detail and return a
generic body — left out here to keep failures visible during development.

**Structured error details.** Errors carry a `code` and a message, but the offending tier ids are
interpolated into the message rather than returned as structured data. A client currently has to
parse prose to know which line to fix.

**Pagination** on the events listing, and **`lock_timeout`** in production so a stuck transaction
queues rather than hangs.

---

# Test coverage

**110 examples**, no failures. There is no coverage tool wired up — adding SimpleCov would be the
next step, along with request specs for the orders endpoints, which are currently covered only at
the service layer.

What is covered:

| Area | Notes |
|---|---|
| `spec/services/orders/tickets_service_spec.rb` | The purchase flow: happy path, multi-tier basket, price snapshotting, every rejection, inventory rollback — plus the **concurrent last-ticket race** and the **mid-request price change** |
| `spec/models/ticket_tier_spec.rb` | Inventory rules, sale-window boundaries, and the **check constraint tested directly with validations bypassed**, proving the database refuses to oversell on its own |
| `spec/models/*` | Validations, associations, price and availability logic |
| `spec/requests/api/v1/events_spec.rb` | Listing filters (draft, past), payload shape, 404 behaviour |

Deliberate gaps: no request specs for the orders endpoints (the service beneath them is
thoroughly covered), and no test for a price change *inside* the transaction — that cannot happen,
since the lock blocks it, and asserting it would mean testing PostgreSQL via timing.

---

Roughly: schema and models · seeds · events API · purchase service and its tests · README.
