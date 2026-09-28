import { sql } from "drizzle-orm";
import { check, index, integer, primaryKey, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("app_users", {
  id: text("id").primaryKey(),
  appleSubject: text("apple_subject").notNull(),
  appleRefreshCiphertext: text("apple_refresh_ciphertext"),
  status: text("status", { enum: ["active", "suspended"] }).notNull().default("active"),
  createdAt: integer("created_at").notNull(),
  lastActiveAt: integer("last_active_at"),
}, (t) => [
  uniqueIndex("app_users_apple_subject").on(t.appleSubject),
  check("app_users_status_check", sql`${t.status} IN ('active', 'suspended')`),
]);

export const entitlements = sqliteTable("entitlements", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  productKey: text("product_key").notNull(),
  status: text("status", { enum: ["active", "revoked"] }).notNull(),
  source: text("source", { enum: ["manual", "app_store"] }).notNull(),
  externalTransactionId: text("external_transaction_id"),
  grantedAt: integer("granted_at").notNull(),
  revokedAt: integer("revoked_at"),
}, (t) => [
  uniqueIndex("entitlements_external_transaction").on(t.externalTransactionId),
  index("entitlements_active_user").on(t.userId, t.status),
  check("entitlements_product_check", sql`${t.productKey} = 'youki_pro_lifetime'`),
  check("entitlements_status_check", sql`${t.status} IN ('active', 'revoked')`),
  check("entitlements_source_check", sql`${t.source} IN ('manual', 'app_store')`),
]);

export const challenges = sqliteTable("auth_challenges", {
  nonceHash: text("nonce_hash").primaryKey(),
  expiresAt: integer("expires_at").notNull(),
}, (t) => [index("auth_challenges_expiry").on(t.expiresAt)]);

export const sessions = sqliteTable("user_sessions", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  accessHash: text("access_hash").notNull(),
  refreshHash: text("refresh_hash").notNull(),
  accessExpiresAt: integer("access_expires_at").notNull(),
  refreshExpiresAt: integer("refresh_expires_at").notNull(),
  revokedAt: integer("revoked_at"),
  createdAt: integer("created_at").notNull(),
}, (t) => [
  uniqueIndex("user_sessions_access_hash").on(t.accessHash),
  uniqueIndex("user_sessions_refresh_hash").on(t.refreshHash),
  index("user_sessions_user").on(t.userId),
  index("user_sessions_expiry").on(t.refreshExpiresAt),
]);

export const counters = sqliteTable("request_counters", {
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  scope: text("scope", { enum: ["minute", "day"] }).notNull(),
  windowStart: integer("window_start").notNull(),
  count: integer("count").notNull(),
}, (t) => [
  primaryKey({ columns: [t.userId, t.scope, t.windowStart] }),
  index("request_counters_expiry").on(t.windowStart),
  check("request_counters_scope_check", sql`${t.scope} IN ('minute', 'day')`),
]);
