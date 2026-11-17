# Kudos Feature Specification and Technical Design

**Status:** Approved specification; standalone implementation prepared  
**Scope:** Internal web application feature and its implementation/setup guide  
**Verification:** Source and configuration files are present. Dependencies were not installed; application tests, build, and type-check remain unverified.

## 1. Overview

The Kudos feature lets an authenticated employee recognize a colleague with a short message of appreciation. Submitted kudos appear in a shared feed on the main dashboard, ordered newest first.

“Public” means visible to authenticated users of the internal application; it does not mean publicly accessible on the internet.

### Goals

- Make it straightforward to recognize a colleague.
- Give employees a shared, recent view of recognition.
- Associate each recognition with its sender, recipient, and submission time.
- Allow authorized administrators to keep the internal feed appropriate by hiding or deleting inappropriate kudos.

### Out of scope

- Reactions, comments, likes, badges, points, leaderboards, and notifications.
- Editing or withdrawing a submitted item by regular employees.
- Anonymous kudos, external recipients, or public web access.
- Configurable retention policies.

## 2. Assumptions and decisions

The original specification was intentionally stack-neutral because the project initially contained no application code or stack documentation. The implementation uses the decisions below; they do not imply integration with Datacom production systems.

1. The app requires authenticated, active users for recipient search, kudos submission, and feed access.
2. The standalone app uses a local PostgreSQL-backed employee directory. No Datacom employee directory API or employee data source was provided.
3. Roles are stored locally as `EMPLOYEE` or `ADMIN`. Server-side authorization checks the current database role for moderation; UI visibility is not an authorization control.
4. No Datacom identity provider or group claim was provided. Auth.js supports a configurable OIDC issuer/client configuration, and sign-in is limited to verified email addresses matching existing active directory records. OIDC group/role claims are not currently mapped; the local database role is authoritative.
5. Local demo password sign-in is available only outside production and only when explicitly enabled. It is disabled by default.
6. Users cannot send kudos to themselves. A message is required and limited to 500 Unicode code points; client and server validation enforce the limit.
7. Regular employees cannot edit, hide, or delete kudos. Authorized administrators can hide or delete according to application policy.
8. The approved PostgreSQL schema below remains the reference design. The standalone Prisma implementation uses text CUID identifiers rather than UUID identifiers; field meanings, foreign-key behavior, and visibility defaults are equivalent.

## 3. User stories

| ID | User story |
|---|---|
| US-1 | As an authenticated employee, I want to select an active colleague from a searchable list so I can address recognition to the right person. |
| US-2 | As an authenticated employee, I want to write a short appreciation message and submit it so I can recognize my colleague. |
| US-3 | As an authenticated employee, I want to see recently submitted kudos on the dashboard so I can learn about recognition across the organization. |
| US-4 | As an employee browsing the feed, I want to see who sent each kudos, who received it, and when it was sent so the recognition has context. |
| US-5 | As an employee using assistive technology or a keyboard, I want the recipient picker, message form, and feed to be accessible so I can use the feature independently. |
| US-6 | As an administrator, I want to hide or delete inappropriate kudos messages so that the public internal feed remains appropriate and professional. |

## 4. Functional requirements

### Submission

- **FR-1:** The application shall provide a “Give kudos” form reachable from the main dashboard.
- **FR-2:** The sender shall be the currently authenticated user; the client shall not choose or override the sender identity.
- **FR-3:** The sender shall select one active colleague from the application’s user directory. The picker should support searching by the directory’s standard name and, if already available, work identifier.
- **FR-4:** The form shall require a recipient and a non-empty message after trimming leading and trailing whitespace.
- **FR-5:** The message shall contain no more than 500 Unicode characters. The interface shall show the remaining or used character count and prevent or clearly report over-limit input.
- **FR-6:** The application shall prevent self-directed kudos, both in the interface and on the server.
- **FR-7:** On successful submission, the application shall persist exactly one kudos record, show a clear success confirmation, clear or reset the form, and make the new item eligible to appear at the top of the feed.
- **FR-8:** On failure, the application shall preserve the user’s entered message and recipient where possible, explain the failure, and avoid showing a success state.
- **FR-9:** The server shall validate authentication, recipient eligibility, message presence, and message length independently of client-side validation.
- **FR-10:** The server shall use the authenticated principal as the author and set the submission timestamp. It shall ignore or reject client-provided author and timestamp values.
- **FR-11:** The feature shall not offer editing by regular employees or anonymous submission. Regular employees shall not delete submitted kudos; administrator deletion is governed by FR-24 and FR-26.

### Recipient directory

- **FR-12:** The picker shall show only active, eligible internal users and shall not expose directory attributes that are not needed to identify a colleague.
- **FR-13:** Directory search shall be bounded and shall not require the browser to download the entire employee directory.
- **FR-14:** If a selected recipient becomes ineligible before submission, the server shall reject the request with a useful validation error.

### Dashboard feed

- **FR-15:** The main dashboard shall display a feed of recently submitted kudos to authenticated users.
- **FR-16:** Each feed item shall show the sender’s display name, recipient’s display name, message, and submission time.
- **FR-17:** Feed items shall be ordered by submission time descending, with a stable secondary ordering by unique ID to resolve ties.
- **FR-18:** The feed shall be paginated, with a default page size of 20 and a maximum page size of 50. It shall not load the complete history in one request.
- **FR-19:** The feed shall provide a useful empty state and a retryable error state.
- **FR-20:** A newly submitted item shall appear on the next feed refresh or navigation. Live push updates are not required.
- **FR-21:** Display names shall be resolved from the directory at read time unless the product explicitly chooses to snapshot names. If a user is deactivated, existing kudos shall remain readable and display a suitable inactive-user label rather than being lost.
- **FR-22:** Authorized administrators shall be able to hide inappropriate kudos. Hiding shall set the kudos visibility to false without changing its message or attribution.
- **FR-23:** Hidden kudos shall not appear in the dashboard feed or its pagination results.
- **FR-24:** Only users authorized as administrators under the application's authorization policy shall be able to hide or delete kudos.
- **FR-25:** Regular employees shall not be able to modify a kudos record's moderation status, including by submitting a forged visibility field.
- **FR-26:** The system shall support deleting inappropriate kudos, with authorization and any required audit or retention behavior governed by the application's existing policy. Deletion shall remove the item from the dashboard feed.

## 5. Non-functional requirements

| Area | Requirement |
|---|---|
| Security | All read and write operations require valid application authentication. Enforce authorization and validation on the server, including administrator authorization for moderation and deletion. Use parameterized database operations and encode message content on output; do not render submitted text as HTML. |
| Privacy | Limit directory search and feed data to fields needed for this feature. Treat the feed as internal employee content and do not expose it through unauthenticated routes or public indexing. |
| Performance | At the agreed normal production load, feed and directory search requests should meet a p95 response time of 500 ms, and submission should meet a p95 response time of 1 second, excluding unusually slow upstream identity services. Confirm load assumptions before release. |
| Scalability | Feed reads must be paginated and supported by appropriate indexes. Directory queries must be bounded and use the existing directory’s search facilities where possible. |
| Reliability | A successful submission is committed atomically. Database or directory failures must surface as errors, not success-shaped responses. |
| Accessibility | Meet WCAG 2.2 AA for the new UI, including keyboard operation, visible focus, labels, error association, and screen-reader status announcements. |
| Compatibility | Follow the supported browsers, UI framework, API conventions, and localization mechanisms of the existing application. |
| Observability | Record operational failures and latency without logging message bodies or unnecessary employee personal data. Track aggregate submission/feed error rates. |
| Maintainability | Reuse the application’s authentication, user-directory, database, API, and design-system components. Keep the feature’s validation and persistence logic testable independently of presentation. |

## 6. Data model

### Existing user entity (assumed)

The feature references, but does not redefine, the existing application user record:

| Field | Use |
|---|---|
| `id` | Stable primary key used by kudos references. |
| `display_name` | Name shown in picker and feed. |
| `active` or equivalent | Determines whether a user can send or receive new kudos. |

Do not duplicate authentication credentials or unrelated directory fields in the feature schema.

### `kudos` table (proposed)

PostgreSQL-style example:

```sql
CREATE TABLE kudos (
    id              UUID PRIMARY KEY,
    sender_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    message         VARCHAR(500) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_visible      BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT kudos_message_not_blank
        CHECK (length(trim(message)) > 0),
    CONSTRAINT kudos_no_self_recognition
        CHECK (sender_user_id <> recipient_user_id)
);

CREATE INDEX kudos_feed_order_idx
    ON kudos (created_at DESC, id DESC)
    WHERE is_visible = TRUE;

CREATE INDEX kudos_sender_created_idx
    ON kudos (sender_user_id, created_at DESC);

CREATE INDEX kudos_recipient_created_idx
    ON kudos (recipient_user_id, created_at DESC);
```

**Schema notes**

- `users` denotes the existing user table; adjust its actual name and key type.
- Generate `id` on the server. Use the database timestamp as the canonical creation time, stored in UTC.
- Enforce the message limit in application validation as well as the database column. Confirm Unicode character-count behavior across database and application runtimes.
- Foreign keys use `RESTRICT` to avoid silently removing recognition history. The application’s user deactivation and deletion policy must preserve references or define an explicit archival/anonymization policy.
- The sender and recipient indexes support likely profile-history queries but may be omitted if those queries are not included in the initial release. The feed index is required.
- Newly created records default to visible. Dashboard feed queries must filter to `is_visible = TRUE`; hidden records remain stored unless an authorized administrator deletes them.
- No uniqueness constraint is proposed: repeated recognition is allowed.
- Retention duration and any additional audit or deletion requirements remain governed by application policy.

## 7. Architecture and interface design

### Logical flow

```text
Dashboard UI
  ├─ Recipient picker ──> Authenticated user-directory API
  ├─ Kudos form ────────> Kudos API ──> Kudos service ──> Relational database
  └─ Recent feed <────── Kudos API <── Kudos service <── Relational database
  └─ Admin moderation ──> Admin-authorized Kudos API ──> Kudos service
                                      └── Existing user directory
```

### Components

1. **Dashboard UI**
   - Provides the submission form and recent feed.
   - Performs immediate usability validation, while treating server validation as authoritative.
   - Encodes all displayed user-controlled text using the UI framework’s normal safe text rendering.
2. **Authenticated API**
   - Reuses application authentication and authorization middleware.
   - Exposes recipient search, kudos creation, paginated feed retrieval, and administrator-only moderation operations.
   - Derives the sender identity from the authenticated principal.
   - Enforces the application's administrator authorization policy for hide and delete operations; regular employee requests cannot change visibility.
3. **Kudos service**
   - Applies business rules: eligibility, self-recognition rejection, message validation, feed visibility filtering, and administrator authorization for moderation.
   - Coordinates directory lookup and persistence; returns explicit validation, not-found, unauthorized, and service-error outcomes.
4. **Repository / relational database**
   - Persists kudos and retrieves ordered pages.
   - Uses bound parameters and transactions as appropriate.
5. **Existing user directory**
   - Supplies active recipients for search and display names for feed items.
   - Remains the source of truth for user status and identity.

For an existing modular monolith, implement these as modules within that application; a separate service is not required. Adapt endpoints and transport conventions to the app’s existing API.

### Suggested API contract

Paths are illustrative, not a commitment to a specific routing convention.

| Operation | Suggested route | Request / response |
|---|---|---|
| Search recipients | `GET /api/users?query={q}&limit={n}` | Returns a bounded list of eligible user IDs and display names. Requires authentication. |
| Create kudos | `POST /api/kudos` | Request: `{ "recipientUserId": "...", "message": "..." }`. Sender and timestamp are server-derived. Returns the created item on success. |
| Read feed | `GET /api/kudos?limit={n}&cursor={token}` | Returns ordered feed items and an opaque next cursor, if more results exist. Requires authentication. |
| Hide kudos | `POST /api/kudos/{id}/hide` | Administrator-only. Sets `is_visible` to `FALSE`. Requires the application's administrator authorization policy. |
| Delete kudos | `DELETE /api/kudos/{id}` | Administrator-only. Deletes the specified record according to the application's authorization, audit, and retention policies. |

Use the application’s normal status-code and error-body conventions. At minimum, distinguish invalid input, unauthenticated access, ineligible/missing recipient, rate limiting if applied, and unexpected service failure. Do not return stack traces or sensitive internals.
Moderation endpoints must also distinguish forbidden access from missing records using the application's normal conventions. Creation requests must not accept client-controlled `is_visible`; only the administrator-only hide operation may change visibility, and regular employees must not be able to alter it.

### Feed pagination

Use keyset/cursor pagination over `(created_at, id)` in descending order to provide stable pages as new items are added. Filter to `is_visible = TRUE` before pagination. Encode the last-seen ordering values in an opaque cursor; validate it on the server. Avoid offset pagination for an expanding feed.

### Write behavior

Validate the recipient against the directory at submission time, then insert the record with the authenticated sender and server/database timestamp. Ensure database failures are returned as failures. If the application has an established idempotency-key convention, reuse it to avoid duplicate writes on client retries; otherwise, disable repeat submission while a request is pending and define retry behavior before implementation.

## 8. Acceptance criteria

1. **Recipient selection:** Given an authenticated active employee, when they search the recipient picker, then only eligible active colleagues are returned in a bounded result set with sufficient identifying information.
2. **Valid submission:** Given a selected colleague and a non-blank message within 500 characters, when the sender submits, then one record is saved with the authenticated sender, selected recipient, message, and server-generated timestamp, and the UI confirms success.
3. **Required fields:** Given a missing recipient or blank/whitespace-only message, when submission is attempted, then the request is rejected with a field-specific error and no record is created.
4. **Length validation:** Given a message longer than 500 characters, when it is submitted directly to the API, then the server rejects it and creates no record; the UI also communicates the limit before submission.
5. **Self-recognition:** Given the sender selects themselves or crafts a direct API request naming themselves, when submission is attempted, then it is rejected and no record is created.
6. **Trusted identity/time:** Given a request that includes forged sender or timestamp fields, when it is submitted, then the server ignores or rejects those fields and persists the authenticated sender and server time only.
7. **Directory status change:** Given a recipient who is no longer eligible by submission time, when the request is processed, then it is rejected without creating a record.
8. **Feed contents:** Given persisted kudos, when an authenticated employee opens the dashboard feed, then each item displays sender, recipient, message, and submission time.
9. **Feed ordering and pagination:** Given more than one page of records, when pages are requested, then results are newest first with deterministic tie ordering, no duplicates across a stable traversal, and no more than the configured maximum page size.
10. **Internal access:** Given an unauthenticated request, when it attempts to search recipients, create kudos, or read the feed, then access is denied.
11. **Safe rendering:** Given a message containing HTML or script-like text, when it is displayed, then it is shown as text and does not execute markup or script.
12. **Failure handling:** Given a database or directory failure, when the user submits or loads the feed, then the UI reports a recoverable failure, does not claim success, and preserves form input where possible.
13. **Accessibility:** Given keyboard-only or screen-reader use, then all controls are labeled and operable, validation errors are announced/associated with fields, focus is visible, and submission status is communicated accessibly.
14. **Inactive historical users:** Given a sender or recipient is later deactivated, when an existing kudos is displayed, then the record remains available and the UI uses an appropriate inactive-user display.
15. **Default visibility:** Given a new kudos record is created without an explicitly supplied visibility value, then it is stored with `is_visible = TRUE`.
16. **Administrator hides kudos:** Given an authorized administrator identifies an inappropriate kudos, when they hide it, then its `is_visible` value becomes `FALSE` and the operation reports success.
17. **Hidden kudos excluded:** Given a kudos record has `is_visible = FALSE`, when an authenticated employee loads or paginates the dashboard feed, then that item is not returned.
18. **Unauthorized moderation denied:** Given a regular employee attempts to hide kudos or change its visibility through the API, then the server denies the request and leaves the visibility unchanged.
19. **Unauthorized deletion denied:** Given a regular employee attempts to delete kudos, then the server denies the request and the record remains unchanged.
20. **Authorized deletion:** Given an administrator authorized under the application's policy, when they delete an inappropriate kudos, then the record is removed according to that policy and no longer appears in the feed.

## 9. Testing and release considerations

- Unit tests are present for Unicode message validation, strict rejection of client-supplied moderation fields, cursor encoding and page-size bounds, and the administrator-role predicate.
- API tests are present for the visible-only feed query, administrator hide/delete operations, and denial of employee hide/delete requests.
- A schema-contract test checks that Prisma and the SQL migration default new kudos to visible.
- The test sources have not been executed because the project runtime and dependencies were not installed. These tests are not reported as passing.
- Additional release validation remains necessary: authenticated and unauthenticated end-to-end flows, server-derived sender/time, real database constraints and pagination, UI error/accessibility behavior, browser compatibility, representative-load performance, and production OIDC configuration.
- Migration review: verify existing user key types and deletion/deactivation semantics before applying the proposed foreign keys.
- Release checks: confirm operational latency targets under representative load, verify logs omit message content, and agree on retention, administrator authorization, and moderation/deletion ownership before production rollout.

## 10. Standalone implementation and run guide

This section consolidates the implementation decisions and setup information previously recorded in the project README. The approved requirements in Sections 1–9 remain the source of product behavior.

### 10.1 Technology stack

- Next.js 15 with the App Router, React 19, and TypeScript.
- PostgreSQL with Prisma ORM; schema and initial migration are under `prisma/`.
- Auth.js (NextAuth v5) for configurable OIDC sign-in and optional development-only demo credentials.
- Zod for request validation and Vitest for tests.

### 10.2 Authentication, directory, and authorization boundaries

- The local `users` table is a demonstration employee directory with `name`, unique `email`, `active`, and `role` fields. Demo records are fictional `example.test` accounts, not Datacom employee data.
- OIDC configuration uses `OIDC_ISSUER`, `OIDC_CLIENT_ID`, and `OIDC_CLIENT_SECRET`. Configure all three together. A verified email must match an active local user.
- OIDC identity-provider group or role claims are not currently mapped. The local database `role` is authoritative until the organization defines and approves a trusted claim mapping and provisioning policy.
- Local credentials are enabled only when `DEMO_AUTH_ENABLED=true` outside production. Seeded credentials use the `DEMO_PASSWORD` environment value; the seed command requires at least 12 characters. Do not enable this mode in production.
- Protected API handlers resolve the current active user from the signed Auth.js session and the database. Hide/delete routes independently check the current database role on the server.
- These configurations are not a Datacom SSO or employee-directory integration.

### 10.3 Implemented routes and behavior

| Route | Behavior |
|---|---|
| `GET /api/users?query={q}` | Authenticated bounded search of active colleagues; excludes the current user. |
| `POST /api/kudos` | Authenticated submission with recipient/message validation; author and timestamp are server-derived. |
| `GET /api/kudos?limit={n}&cursor={token}` | Authenticated, keyset-paginated feed ordered newest first and filtered to visible records. |
| `POST /api/kudos/{id}/hide` | Administrator-only logical hide (`is_visible = false`). |
| `DELETE /api/kudos/{id}` | Administrator-only deletion. |
| `/api/auth/[...nextauth]` | Auth.js sign-in/session endpoints. |

The dashboard includes colleague search/selection, the appreciation form, a character count, feed refresh and pagination, and admin moderation controls. Message content is rendered as text. Hidden records are filtered in the server-side database query.

### 10.4 Database mapping

The reference schema in Section 6 uses UUID identifiers. The implementation uses Prisma-generated text CUIDs. Prisma maps `isVisible` to database column `is_visible`, with `BOOLEAN NOT NULL DEFAULT TRUE`; the migration also adds non-blank-message and no-self-recognition constraints, restricted user foreign keys, and feed/sender/recipient indexes.

The implementation’s `users` table additionally stores local `EMPLOYEE`/`ADMIN` roles and optional password hashes for the demo provider. Credentials are stored as salted scrypt hashes.

### 10.5 Project files

- `src/app/`: dashboard, login UI, layout, styling, and API route handlers.
- `src/lib/`: Auth.js setup, Prisma client, current-user lookup, request validation, and feed/authorization rules.
- `prisma/schema.prisma`, `prisma/migrations/`, `prisma/seed.ts`: database definition, migration, and fictional demo users.
- `tests/`: unit, moderation API, and schema-contract tests.
- `package.json`, `tsconfig.json`, `vitest.config.ts`, `next.config.ts`, `eslint.config.mjs`: application and verification configuration.
- `.env.example`: environment-variable template; it contains placeholders, not real credentials.
- `.vscode/launch.json`: VS Code Run and Debug configuration. The root `launch.json` is also retained; VS Code discovers the configuration in `.vscode/`.
- `README.md`: retained as a short project overview; this specification now also contains its important setup and limitation details.

### 10.6 Local setup and commands

Prerequisites: Node.js 20.9 or newer, npm, PostgreSQL, and a private `AUTH_SECRET` of at least 32 random characters.

1. Copy `.env.example` to `.env`; configure `DATABASE_URL`, `AUTH_SECRET`, and `AUTH_URL`.
2. To use local demo login, set `DEMO_AUTH_ENABLED=true` and choose `DEMO_PASSWORD` with at least 12 characters. Demo sign-in is forcibly disabled in production.
3. Install dependencies locally in the project with `npm install`.
4. Generate the Prisma client and apply the migration:

   ```powershell
   npm run db:generate
   npm run db:migrate
   ```

5. Seed the demo directory with `npm run db:seed`. Seeded accounts are:
   - `alex.employee@example.test` — employee
   - `sam.employee@example.test` — employee
   - `taylor.admin@example.test` — administrator
   - `inactive.employee@example.test` — inactive; cannot sign in or receive new kudos

   Seeded active accounts use the configured `DEMO_PASSWORD`.
6. Start with `npm run dev`, or select **Run Kudos (Next.js)** in VS Code after dependencies and database are configured. Browse to `http://localhost:3000`.

Available verification commands:

```powershell
npm run build
npm run lint
npm run typecheck
npm test
```

Database commands: `npm run db:generate`, `npm run db:migrate`, and `npm run db:seed`.

### 10.7 Verification status and known limitations

- The project source, dependency manifest, migration, tests, and launch configurations are present. JSON configuration and required-file presence were statically checked.
- No dependencies were installed; `npm test`, `npm run build`, `npm run lint`, `npm run typecheck`, Prisma generation, and database migration have not been run. Application behavior is therefore not yet runtime-verified.
- Actual Datacom identity, employee-directory, and administrator-group integration remains unconfigured. Configure and verify OIDC claim mapping before production use.
- Retention/audit policy for administrator deletion, operational performance targets, production secrets, and production deployment settings remain to be confirmed.
