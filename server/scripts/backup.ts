import { existsSync, mkdirSync, unlinkSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { Database } from "bun:sqlite";
import { databasePath, openSqlite } from "../src/infrastructure/auth/sqlite-database";

const destination = process.argv[2];
if (!destination) throw new Error("Pass a destination path: bun run backup -- /path/to/backup.sqlite");
const sourcePath = databasePath();
const backupPath = resolve(destination);
if (sourcePath === backupPath) throw new Error("Backup destination must differ from the live database.");
if (existsSync(backupPath)) throw new Error("Backup destination already exists; refusing to overwrite it.");
process.umask(0o077);
mkdirSync(dirname(backupPath), { recursive: true, mode: 0o700 });
const source = openSqlite(sourcePath);
try {
  source.query("VACUUM INTO ?").run(backupPath);
  const backup = new Database(backupPath, { readonly: true });
  try {
    const result = backup.query("PRAGMA integrity_check").get() as { integrity_check: string };
    if (result.integrity_check !== "ok") throw new Error("SQLite backup failed integrity_check.");
  } finally { backup.close(); }
  console.log(`SQLite backup verified: ${backupPath}`);
} catch (error) {
  if (existsSync(backupPath)) unlinkSync(backupPath);
  throw error;
} finally { source.close(); }
