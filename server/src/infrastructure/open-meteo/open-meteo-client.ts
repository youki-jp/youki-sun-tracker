import { ExternalServiceError } from "../../application/errors";

interface CacheEntry { value: unknown; expiresAt: number }
interface Waiter { resolve: () => void; reject: (error: Error) => void; timer: ReturnType<typeof setTimeout> }

export class OpenMeteoClient {
  private static cache = new Map<string, CacheEntry>();
  private static pending = new Map<string, Promise<unknown>>();
  private static active = 0;
  private static waiters: Waiter[] = [];

  constructor(private readonly baseUrl: string) {}

  async getJson<T>(path: string, params: Record<string, string>): Promise<T> {
    const url = new URL(path, this.baseUrl);
    for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
    url.searchParams.sort();
    const key = url.toString();
    const cached = OpenMeteoClient.cache.get(key);
    if (cached && cached.expiresAt > Date.now()) return cached.value as T;
    if (cached) OpenMeteoClient.cache.delete(key);
    const pending = OpenMeteoClient.pending.get(key);
    if (pending) return pending as Promise<T>;
    const work = OpenMeteoClient.withSlot(async () => {
      let response: Response;
      try {
        response = await fetch(key, { signal: AbortSignal.timeout(5000), headers: { accept: "application/json" } });
      } catch {
        throw new ExternalServiceError("Unable to reach Open-Meteo.");
      }
      if (!response.ok) throw new ExternalServiceError(`Open-Meteo request failed with ${response.status}.`);
      let value: T;
      try { value = await response.json() as T; }
      catch { throw new ExternalServiceError("Open-Meteo returned invalid JSON."); }
      if (OpenMeteoClient.cache.size >= 256) {
        const oldest = OpenMeteoClient.cache.keys().next().value;
        if (oldest) OpenMeteoClient.cache.delete(oldest);
      }
      OpenMeteoClient.cache.set(key, { value, expiresAt: Date.now() + (params.forecast_days === "1" ? 3600_000 : 900_000) });
      return value;
    });
    OpenMeteoClient.pending.set(key, work);
    try { return await work; }
    finally { OpenMeteoClient.pending.delete(key); }
  }

  private static async withSlot<T>(work: () => Promise<T>): Promise<T> {
    if (this.active < 16) this.active++;
    else {
      if (this.waiters.length >= 32) throw new ExternalServiceError("Forecast capacity is temporarily full.");
      await new Promise<void>((resolve, reject) => {
        const waiter: Waiter = { resolve, reject, timer: setTimeout(() => {
          this.waiters = this.waiters.filter((item) => item !== waiter);
          reject(new ExternalServiceError("Forecast capacity wait timed out."));
        }, 1000) };
        this.waiters.push(waiter);
      });
    }
    try { return await work(); }
    finally {
      const next = this.waiters.shift();
      if (next) { clearTimeout(next.timer); next.resolve(); }
      else this.active--;
    }
  }
}
