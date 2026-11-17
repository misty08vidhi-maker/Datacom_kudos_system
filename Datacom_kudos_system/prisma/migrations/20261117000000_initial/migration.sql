CREATE TYPE "UserRole" AS ENUM ('EMPLOYEE', 'ADMIN');

CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'EMPLOYEE',
    "active" BOOLEAN NOT NULL DEFAULT TRUE,
    "password_hash" TEXT,
    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "kudos" (
    "id" TEXT NOT NULL,
    "sender_user_id" TEXT NOT NULL,
    "recipient_user_id" TEXT NOT NULL,
    "message" VARCHAR(500) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_visible" BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT "kudos_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "kudos_message_not_blank" CHECK (length(trim("message")) > 0),
    CONSTRAINT "kudos_no_self_recognition" CHECK ("sender_user_id" <> "recipient_user_id")
);

CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE INDEX "kudos_feed_order_idx" ON "kudos"("created_at" DESC, "id" DESC);
CREATE INDEX "kudos_sender_created_idx" ON "kudos"("sender_user_id", "created_at" DESC);
CREATE INDEX "kudos_recipient_created_idx" ON "kudos"("recipient_user_id", "created_at" DESC);

ALTER TABLE "kudos"
    ADD CONSTRAINT "kudos_sender_user_id_fkey"
    FOREIGN KEY ("sender_user_id") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "kudos"
    ADD CONSTRAINT "kudos_recipient_user_id_fkey"
    FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
