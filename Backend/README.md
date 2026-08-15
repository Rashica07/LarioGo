# LarioGo API

Vapor + Fluent + PostgreSQL backend for LarioGo. Versioned at `/api/v1`.

> **Status: written, never compiled.** No Swift toolchain exists on the Windows
> development machine and GitHub Actions is currently blocked by account billing,
> so this code has not been built or tested even once. Expect compile errors on
> the first real build. See `LARIO_PROGRESS.md` in the repo root.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | — | Liveness + database reachability |
| POST | `/api/v1/auth/register` | — | Create an account, returns a JWT |
| POST | `/api/v1/auth/login` | — | Exchange credentials for a JWT |
| GET | `/api/v1/auth/me` | Bearer | Current user record |
| GET | `/api/v1/attractions` | — | List attractions |
| GET | `/api/v1/restaurants` | — | List restaurants |
| GET | `/api/v1/events` | — | List events and experiences |
| GET | `/api/v1/places` | — | List every kind (map / search) |
| GET | `/api/v1/{collection}/:id` | — | Single place |

Discovery is intentionally unauthenticated: a visitor should see what is around
them before being asked to create an account.

### Discovery query parameters

Applies to every list endpoint.

| Parameter | Example | Notes |
|---|---|---|
| `kind` | `kind=restaurant,event` | Overrides the endpoint default |
| `category` | `category=food` | Unknown value → 400 |
| `search` | `search=piona` | Matches name, tagline, summary, about, region |
| `minRating` | `minRating=4.5` | 0–5. Unrated places are excluded |
| `maxPrice` | `maxPrice=2` | 1–4. Places *without* a price are kept |
| `cuisine` | `cuisine=lombard` | Case-insensitive |
| `tag` | `tag=hiking` | Case-insensitive |
| `region` | `region=Varenna` | Exact match |
| `featured` | `featured=true` | |
| `lat` + `lon` | `lat=45.85&lon=9.39` | Must be supplied together |
| `radius` | `radius=5000` | Metres. Requires `lat`/`lon` |
| `startsAfter` / `startsBefore` | ISO-8601 | Event date range |
| `sort` | `sort=rating` | `relevance`, `distance`, `rating`, `priceLowToHigh`, `name`, `startDate` |
| `page` / `per` | `page=2&per=20` | `per` capped at 100 |

Responses are enveloped: `{ items: [...], metadata: { page, per, total, totalPages, hasNextPage } }`.
A bare array would leave the client unable to distinguish "no more results" from
"this page happened to be short".

`distance` (metres) appears on results only when `lat`/`lon` were supplied —
never as a placeholder value, which clients render as if it were real.

Invalid input is rejected with 400 rather than silently defaulted: `lat` without
`lon`, `sort=distance` without a location, `minRating=9`, `per=100000` and
unknown enum values all produce an explanatory error.

## Running locally

Requires Docker, or a local PostgreSQL plus a Swift 5.9+ toolchain (macOS/Linux).

```bash
cd Backend
cp .env.example .env
# Generate a signing key and paste it into .env as JWT_SECRET
openssl rand -base64 48
```

Then:

```bash
docker compose up db
```

```bash
swift run App migrate --yes
```

```bash
swift run App serve --hostname 0.0.0.0 --port 8080
```

Or run everything in containers:

```bash
docker compose up --build
```

## Tests

Tests need a reachable PostgreSQL. They run migrations automatically (the
testing environment sets `AUTO_MIGRATE`) and truncate `users` before each case.

```bash
swift test
```

## Configuration

All configuration is environment-driven; see `.env.example`. Notable behaviour:

- **`JWT_SECRET` is mandatory in production.** The server throws
  `ConfigurationError.missingJWTSecret` rather than booting with a default key,
  because a predictable signing key means anyone can forge a session. Outside
  production an ephemeral key is generated per boot and tokens do not survive a
  restart.
- A secret shorter than 32 characters is rejected outright.
- **CORS** defaults to allow-all in development and **deny-all in production**
  unless `CORS_ALLOWED_ORIGIN` names an exact origin.
- `AUTO_MIGRATE` is off by default. Run migrations as an explicit deploy step so
  a failing migration cannot crash-loop the service.

## Security notes

- Passwords are bcrypt-hashed via Vapor's `password` provider. `User` does not
  conform to `Content`, so the hash cannot be serialised into a response by
  accident — responses go through `UserResponse`.
- Duplicate emails are caught by a **unique database index**, not an
  application-level existence check, which would race under concurrent
  registration.
- Login returns an identical response whether the account is missing or the
  password is wrong, and performs a dummy bcrypt verification in the
  account-missing path, so the endpoint cannot be used to enumerate registered
  addresses. There is a test asserting the two response bodies match.
- `GET /me` re-reads the user from the database rather than trusting token
  claims, so a deleted account's token stops working immediately.
- **No third-party payment SDK.** Apple Pay / PassKit only, enforced by a CI gate.

## Deployment

The `Dockerfile` produces a statically linked binary running as a non-root
`vapor` user. Any host that accepts a container works (Railway, Fly.io, Render).

Required environment in production:

```
DATABASE_URL=<managed postgres url>
JWT_SECRET=<openssl rand -base64 48>
CORS_ALLOWED_ORIGIN=<exact origin, if a browser client exists>
```

Run `App migrate --yes` as a release/deploy command, then `App serve`.

## Geosearch implementation

Proximity uses an indexable bounding-box prefilter, then an exact haversine check
to trim the corners of the box. Distance ordering and text relevance cannot be
expressed in Fluent's query builder, so those two paths load the filtered set and
finish in memory, bounded by a `fetchCap` of 5,000 rows.

That is comfortable for one region's content and deliberately explicit rather
than silently truncating. **PostGIS plus a tsvector index is the scaling path**
once coverage grows past a few thousand places; the API contract does not change
when that happens.

## Seed content

`SeedPlaces` runs outside production (or with `SEED_CONTENT=true`) and no-ops if
the table already has rows.

Attractions and landmarks are **real, publicly documented places** around Lecco
and Lake Como. Dining and event entries are **invented sample data** — plausible
but not real businesses, tagged `sample-data` and described as such in their own
text. Opening hours, phone numbers and reservation availability are left absent
rather than fabricated. Replace with licensed or partner-supplied content before
any public launch.

## Not yet implemented

Reviews, favourites, itineraries and bookings. Phases 1–2 (config, user, auth,
health, discovery content) exist.
