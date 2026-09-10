# POS (pos_in_desktop)

A desktop Point-of-Sale application built with Flutter for a retail shop.
It runs on **Windows**, **macOS** and **Android**, and talks to a
**PostgreSQL** database.

## Features

- **Authentication** – user login with SHA-256 hashed passwords, persisted
  sessions, per-user role permissions and a user-management screen.
- **Product catalog & stock** – categories, inventory types and stock items
  with live quantity that stays in sync with purchases, sales and returns.
- **Parties** – customers and companies with running balances.
- **Purchasing** – purchase invoices and purchase returns.
- **Sales** – sale invoice cart with sale/purchase price per line, hold
  (park) & resume, sale returns and sale exchange from an existing invoice.
- **Payments & ledger** – customer payment dialog, opening-balance updates
  and a derived party ledger / account statement.
- **Receipts** – auto-printed 80&nbsp;mm thermal receipt (PDF + system
  printer), barcode labels, and an admin screen to edit the shop header and
  toggle individual receipt fields.
- **Finance** – bank accounts & entries, a cash register (cash book),
  expenses and vouchers.
- **Dashboard** – KPI cards, a sales bar chart and a top-products list.
- **Reports** – eight date-ranged reports (sales, sale return, sale
  exchange, purchase + return, stock, category, expense, P&L) with document
  export.
- **Backup** – the whole local database is mirrored to a single Supabase
  table as JSON, on a 6-hourly schedule and on demand, with restore into an
  empty database.

## Tech stack

| Area | Choice |
| --- | --- |
| UI | Flutter (Material), custom SVG icon set (`AppIcon` / `AppIcons`) |
| Database | PostgreSQL (`postgres` package) |
| Session | `shared_preferences` |
| Printing | `pdf` + `printing` |
| Export | `excel` |
| Cloud backup | `supabase_flutter` |

The code follows a feature-first / clean-architecture layout:

```
lib/
  config/          app config, DB connection, theme, formatting
  shared/          cross-feature widgets, receipt & export helpers
  features/<name>/
    data/          datasource, model, repository
    presentation/  provider, screen, widget
```

## Getting started

### Prerequisites

- Flutter SDK **3.35.x** (Dart `^3.9.2`)
- A reachable **PostgreSQL** server and database
- A Supabase project (optional – only for cloud backup)

### Run

```bash
flutter pub get
flutter run -d windows      # or: macos / android
```

Configure the database connection in `lib/config/db_config.dart`.

> **Database schema:** the per-feature SQL scripts are **not** kept in this
> repository. Each feature screen reports the exact script name it needs if a
> table or permission is missing; obtain those scripts from the project owner
> and apply them with `psql` before first use.

## Build

```bash
flutter build windows --release     # build/windows/x64/runner/Release
```

## CI/CD

`.github/workflows/windows-build.yml` runs on every push / PR to `main` and
on `v*` tags:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build windows --release`
5. zips the `Release` folder and uploads it as a build artifact
6. on a `v*` tag, publishes a GitHub Release with the zip attached

Trigger a release with:

```bash
git tag v1.0.0
git push --tags
```

## Tests

```bash
flutter test
```

Feature and widget tests live under `test/`.
