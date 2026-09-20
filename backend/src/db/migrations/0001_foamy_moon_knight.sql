ALTER TABLE "devices" ADD COLUMN "last_sync_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "devices" ADD COLUMN "last_sync_status" text;--> statement-breakpoint
ALTER TABLE "devices" ADD COLUMN "last_sync_error" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "is_admin" boolean DEFAULT false NOT NULL;