import { chmodSync, existsSync, mkdirSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { Database } from "bun:sqlite";

export function databasePath(): string {
  const configured = process.env.SQLITE_PATH;
  if (process.env.NODE_ENV === "production" && (!configured || !isAbsolute(configured))) {
    throw new Error("Production SQLITE_PATH must be an absolute path on persistent storage.");
  }
  return resolve(configured ?? "data/youki.sqlite");
}

export function openSqlite(path: string, create = false): Database {
  process.umask(0o077);
  if (create) mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  else if (!existsSync(path)) throw new Error("SQLite database missing; run bun run migrate first.");
  const db = create ? new Database(path, { create: true }) : new Database(path);
  chmodSync(path, 0o600);
  db.exec("PRAGMA journal_mode = WAL; PRAGMA synchronous = FULL; PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;");
  return db;
}
