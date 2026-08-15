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

## Not yet implemented

Attractions, restaurants, events, reviews, favourites, itineraries, bookings and
geosearch. Only the Phase 1 foundation (config, user, auth, health) exists.
