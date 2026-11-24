# Sprout ERP PoC

A micro-ERP for **Sprout**, which buys used electronics in lots, refurbishes them,
and resells them on **Amazon Renewed**.

## Stack

| Layer | What |
|---|---|
| Front end | Single-page app in **Vue 3** (Vue Router, Pinia), built by Vite, styled with Tailwind |
| Back end | **Elixir / Phoenix 1.8** JSON API under `/api`, plus a Phoenix Channel for live updates |
| Database | **PostgreSQL** through Ecto |
| Hosting | **Heroku** (Procfile and buildpack config; see [Deploy to Heroku](#deploy-to-heroku)) or any Docker host, such as **Render** ([Deploy to Render](#deploy-to-render)) |

Business rules (cost allocation, grading and pricing, estimated fees, margins) live
in the Elixir contexts. The API returns the computed numbers; the Vue app only
shows them. Dashboard figures (30-day totals, weekly revenue, category margins,
aging stock) are aggregated by PostgreSQL in `SproutErp.Metrics`.

```
assets/src/            Vue app: views, components, router, stores
lib/sprout_erp/        contexts: Purchasing, Inventory, Catalog, Metrics
lib/sprout_erp_web/    router, API controllers, channel, HTML shell
priv/repo/             migrations and demo seeds
```

## Run it

You need Elixir 1.20 / OTP 29, Node 22 or newer, and PostgreSQL running locally.

```bash
brew install elixir node postgresql@17     # one time
brew services start postgresql@17          # one time
mix setup                    # deps, database, ~100 days of demo data, npm install, Vite build
mix phx.server               # http://localhost:4000
```

The database connection uses your OS user with no password by default; set
`PGUSER`, `PGPASSWORD` or `PGHOST` to change it.

Reset the demo data at any time with `mix ecto.reset`.
There is **no login**: the app opens straight on the dashboard. All the data is
fictitious demo data.

`mix phx.server` also runs Vite in watch mode, so edits under `assets/` rebuild
and reload the browser.

Run the tests with `mix test` (API, contexts, channel) and `npm test --prefix assets`
(front-end formatting helpers).

## What's inside

| Area | Route | What it does |
|---|---|---|
| Dashboard | `/` | 30-day KPIs with deltas, weekly revenue, pipeline, category margins, aging stock, live activity feed |
| Purchasing | `/purchasing` | Supplier scorecards; purchase lots with sell-through and projected ROI |
| Receive lot | `/purchasing/new` | Multi-line intake. Lot cost is allocated to units by MSRP, and each unit gets a SKU |
| Lot detail | `/purchasing/:id` | Invested vs. net revenue, profit, and every unit in the lot |
| Workshop | `/workshop` | Kanban (dock → inspection → bench → shelf) with one-click actions |
| Inventory | `/inventory` | Every unit, with filters by stage, category and search |
| Unit | `/inventory/:id` | Stage stepper, grading, bench tasks (parts + labor), pricing, unit economics, timeline |
| Amazon listings | `/listings` | Live offers, estimated fees, projected profit, days live |
| Sales | `/sales` | Orders with fully loaded margin (30d / 90d / all time) |

### Domain model

```
Supplier ─< Lot ─< Unit >─ Product
                    ├─< WorkItem   (bench task: parts $ + labor minutes @ $45/h)
                    ├─< Sale       (order ledger: completed, cancelled or returned)
                    └─< Event      (audit trail / activity feed)
```

Unit lifecycle: `received → inspecting → refurbishing → ready → listed → sold`

* **Grades** follow Amazon Renewed: Premium, Excellent, Good and Acceptable. Each
  grade sets the suggested price: 86%, 76%, 66% or 55% of MSRP.
* **Amazon fees** are estimated as an 8% referral fee plus a per-category FBA fee.
* **QC is blocked** while a unit still has open bench tasks.
* Two people cannot act on the same unit at once: each action carries the unit's
  version, and a stale one gets *"This item was already updated"*.
* Every screen updates **in real time**: the server pushes a "changed" message on a
  Phoenix Channel and the open screens refetch. Open two tabs to see it.

### API

Writes carry the `x-csrf-token` header; errors come back as JSON
(`404`, `409` stale, `422` validation).

| | |
|---|---|
| `GET /api/dashboard` | KPIs, weekly revenue, pipeline, categories, aging stock, activity |
| `GET /api/lots`, `GET /api/lots/:id`, `POST /api/lots` | Suppliers and lots; receive a lot |
| `GET /api/workshop` | The board, by stage |
| `GET /api/units`, `GET /api/units/:id` | Inventory (filters: `status`, `category`, `q`) and one unit |
| `POST /api/units/:id/actions/:action` | `start_inspection`, `grade`, `mark_ready`, `list`, `reprice`, `sell`, `cancel_sale`, `return_sale` |
| `POST /api/units/:id/work_items`, `PATCH /api/work_items/:id/toggle`, `DELETE /api/work_items/:id` | Bench tasks |
| `GET /api/listings`, `GET /api/sales?range=30\|90\|all` | Live offers; orders and the sales ledger |
| `GET /export/inventory.csv`, `GET /export/sales.csv` | CSV downloads (same filters as the screens) |

## Demo script (5 min)

1. **Dashboard.** Walk through the 30-day KPIs, the weekly revenue chart (hover a
   bar), the pipeline, and the aging stock under *Needs attention*.
2. **Receive lot.** Pick a supplier, enter a $2,000 cost, add 3 iPhones and
   2 AirPods, then submit. The app opens the new lot with its allocated unit costs.
3. **Workshop.** Start inspection on a new unit, then grade it *Excellent*.
4. Open that unit. Add the bench task "Battery replacement" ($18.90, 30 min), check
   it off, **Pass QC**, and **List on Amazon** at the suggested price.
5. **Amazon listings.** Click **Record sale**. The dashboard (open in another tab)
   updates live.

## Deploy to Heroku

The repository carries what Heroku needs: `Procfile` (web process, and migrations on
every release), `elixir_buildpack.config`, `phoenix_static_buildpack.config` with the
`compile` script that runs the Vite build, and `app.json`.

```bash
heroku create my-sprout-erp
heroku buildpacks:add https://github.com/HashNuke/heroku-buildpack-elixir
heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static
heroku addons:create heroku-postgresql
heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret) PHX_HOST=my-sprout-erp.herokuapp.com
git push heroku main
heroku run "mix run priv/repo/seeds.exs"     # demo data
```

The app has no login, so anyone who has the URL can use it and change the demo
data; run the seeds again to restore it.

`DATABASE_URL` comes from the Postgres add-on. This configuration was exercised
locally in production mode (`MIX_ENV=prod`, same commands the buildpacks run); it has
not been deployed to a Heroku app yet.

## Deploy to Render

`render.yaml` describes a free web service, built from the `Dockerfile` as an Elixir
release, and a free PostgreSQL database.

1. On [render.com](https://render.com), choose **New → Blueprint** and connect this
   repository.
2. Apply the blueprint. Render builds the image, creates the database and fills in
   `DATABASE_URL` and `SECRET_KEY_BASE`.

The service starts with `bin/demo`: it runs the migrations, loads the demo data when
the database is empty and then starts the server, so there is no manual step. The
public host name comes from `RENDER_EXTERNAL_HOSTNAME`.

On the free plan the service sleeps when idle (the first request takes a while) and
the free database expires 30 days after it is created. The release and its start
script were exercised locally against PostgreSQL; the Docker build itself runs on
Render.

## Known limitations

Choices made to keep this a proof of concept, and what each would take.

| Limitation | Why it is acceptable here | Next step |
|---|---|---|
| **No login or permissions.** Every route is open and the history does not record who did each action. | The app is a demo on fictitious data that people should open directly. | Accounts with roles; an author on every history event. |
| **Sale data is stored twice.** A sold unit carries its price, fees, date and order number, and the `sales` ledger holds the same values. Reports read the unit. | Both are written in one transaction, so they cannot drift today. | Make the ledger the only source and drop the unit columns. |
| **Lists are not paginated.** Inventory, lots and sales return every row of the filter. Dashboard figures are aggregated in PostgreSQL, but the purchasing screen still computes lot ROI from loaded units. | The demo holds about 200 units. | Pagination, and lot economics as a database aggregate. |
| **Amazon is simulated.** Fees are estimates (8% + a per-category FBA fee, flagged as estimated everywhere) and order numbers, bin locations and serials are generated. | No seller account is connected. | Amazon SP-API: real orders, fees and returns. |
| **Fee and suggested-price math uses floats** before rounding to cents. Stored amounts and the lot cost allocation are integer cents. | They are estimates, shown as such. | Integer or decimal arithmetic once real fees arrive. |
| **Bench tasks are checked against the unit's stage outside the write transaction.** A task could change in the instant a unit passes QC. | The window is milliseconds and stage changes themselves are locked by version. | Lock the unit row while a task changes. |
| **Front-end tests cover formatting only.** The flows are tested through the API (contexts, endpoints, channel). | Business rules live in Elixir. | Component and browser tests for the main flows. |

Also out of scope: multi-warehouse support and outgoing e-mail. The contexts
(`Purchasing`, `Inventory`, `Metrics`) are where those would plug in. No AWS service
is needed yet; file storage (S3) and e-mail (SES) would be the first candidates.
