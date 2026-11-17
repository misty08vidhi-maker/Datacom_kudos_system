# Internal Kudos

A standalone implementation of the approved Kudos specification using Next.js, TypeScript, PostgreSQL, Prisma, and Auth.js.

## Important assumptions and limitations

- This repository does **not** integrate with Datacom's actual identity provider, employee directory, or administrator group. No such integration details or services were supplied.
- The database-backed `users` table is a demonstration employee directory. It contains active and inactive sample users. Only active users can sign in or be selected as recipients.
- Roles are stored on each local employee record as `EMPLOYEE` or `ADMIN`. The server reads the current role from the database for protected actions; hiding and deleting kudos are not authorized by UI state alone.
- OIDC is configurable through standard issuer, client ID, and client secret environment variables. OIDC sign-in matches the provider's verified email to an existing active local employee. The local database role remains authoritative in this standalone version. Before a real SSO rollout, explicitly map the provider's trusted group/role claim to the local role policy and validate issuer, audience, claim shape, and provisioning rules with the identity team.
- Local demo password sign-in is disabled by default, permitted only outside production, and requires `DEMO_AUTH_ENABLED=true`. Use a private development password; never expose demo mode to a production deployment.
- The project files and dependency manifest are provided, but no runtime or package installation was performed. Build, lint, type-check, tests, and database migration have not yet been run in this environment.
- Moderation uses logical hiding (`is_visible = false`) or hard deletion. Any additional audit/retention obligations must be confirmed against application policy before deployment.

## Prerequisites

- Node.js 20.9 or newer and npm.
- PostgreSQL.
- A private development `AUTH_SECRET` (at least 32 random characters).

## Local setup

1. Copy `.env.example` to `.env` and set `DATABASE_URL`, `AUTH_SECRET`, and `AUTH_URL`.
2. For demo sign-in, set `DEMO_AUTH_ENABLED=true` and set `DEMO_PASSWORD` to a password of at least 12 characters. Demo sign-in is forcibly disabled in production.
3. Install project dependencies locally with `npm install`.
4. Generate the Prisma client and apply the database migration:

   ```powershell
   npm run db:generate
   npm run db:migrate
   ```

5. Seed the demonstration directory:

   ```powershell
   npm run db:seed
   ```

   Seeded accounts use the configured `DEMO_PASSWORD`:
   - `alex.employee@example.test`
   - `sam.employee@example.test`
   - `taylor.admin@example.test` (administrator)
   - `inactive.employee@example.test` (inactive; cannot sign in or receive new kudos)

6. Start the development server with `npm run dev`, or use the **Run Kudos (Next.js)** launch configuration in VS Code after dependencies are installed. VS Code discovers that configuration in `.vscode/launch.json`; the root `launch.json` is retained as requested.
7. Open `http://localhost:3000`.

The empty `.env.example` OIDC settings can be filled from a trusted OIDC provider. All three OIDC values must be present together. A matching active employee record must already exist in the local directory.

## Available commands

```powershell
npm run dev
npm run build
npm run lint
npm run typecheck
npm test
```

Database commands: `npm run db:generate`, `npm run db:migrate`, and `npm run db:seed`.

## Implemented behavior

- Active colleague search backed by the local directory.
- Server-validated kudos submission; author and timestamp are server-derived.
- Authenticated recent feed with keyset cursor pagination, newest-first order, and a hard visibility filter.
- Default-visible database field `is_visible BOOLEAN NOT NULL DEFAULT TRUE`.
- Server-authorized administrator hide and delete endpoints, plus dashboard controls for administrators.
- Message validation, self-recognition prevention, safe text rendering, explicit error responses, and focused unit tests.
