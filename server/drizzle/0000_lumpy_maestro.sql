CREATE TABLE `auth_challenges` (
	`nonce_hash` text PRIMARY KEY NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `auth_challenges_expiry` ON `auth_challenges` (`expires_at`);--> statement-breakpoint
CREATE TABLE `request_counters` (
	`user_id` text NOT NULL,
	`scope` text NOT NULL,
	`window_start` integer NOT NULL,
	`count` integer NOT NULL,
	PRIMARY KEY(`user_id`, `scope`, `window_start`),
	FOREIGN KEY (`user_id`) REFERENCES `app_users`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "request_counters_scope_check" CHECK("request_counters"."scope" IN ('minute', 'day'))
);
--> statement-breakpoint
CREATE INDEX `request_counters_expiry` ON `request_counters` (`window_start`);--> statement-breakpoint
CREATE TABLE `entitlements` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`product_key` text NOT NULL,
	`status` text NOT NULL,
	`source` text NOT NULL,
	`external_transaction_id` text,
	`granted_at` integer NOT NULL,
	`revoked_at` integer,
	FOREIGN KEY (`user_id`) REFERENCES `app_users`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "entitlements_product_check" CHECK("entitlements"."product_key" = 'youki_pro_lifetime'),
	CONSTRAINT "entitlements_status_check" CHECK("entitlements"."status" IN ('active', 'revoked')),
	CONSTRAINT "entitlements_source_check" CHECK("entitlements"."source" IN ('manual', 'app_store'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `entitlements_external_transaction` ON `entitlements` (`external_transaction_id`);--> statement-breakpoint
CREATE INDEX `entitlements_active_user` ON `entitlements` (`user_id`,`status`);--> statement-breakpoint
CREATE TABLE `user_sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`access_hash` text NOT NULL,
	`refresh_hash` text NOT NULL,
	`access_expires_at` integer NOT NULL,
	`refresh_expires_at` integer NOT NULL,
	`revoked_at` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `app_users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `user_sessions_access_hash` ON `user_sessions` (`access_hash`);--> statement-breakpoint
CREATE UNIQUE INDEX `user_sessions_refresh_hash` ON `user_sessions` (`refresh_hash`);--> statement-breakpoint
CREATE INDEX `user_sessions_user` ON `user_sessions` (`user_id`);--> statement-breakpoint
CREATE INDEX `user_sessions_expiry` ON `user_sessions` (`refresh_expires_at`);--> statement-breakpoint
CREATE TABLE `app_users` (
	`id` text PRIMARY KEY NOT NULL,
	`apple_subject` text NOT NULL,
	`apple_refresh_ciphertext` text,
	`status` text DEFAULT 'active' NOT NULL,
	`created_at` integer NOT NULL,
	`last_active_at` integer,
	CONSTRAINT "app_users_status_check" CHECK("app_users"."status" IN ('active', 'suspended'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `app_users_apple_subject` ON `app_users` (`apple_subject`);