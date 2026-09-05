import { ExternalServiceError } from "../../application/errors";

export class OpenMeteoClient {
  constructor(private readonly baseUrl: string) {}

  async getJson<T>(path: string, params: Record<string, string>): Promise<T> {
    const url = new URL(path, this.baseUrl);

    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }

    const response = await fetch(url.toString(), {
      headers: {
        accept: "application/json",
      },
    }).catch((error) => {
      throw new ExternalServiceError(
        `Unable to reach Open-Meteo: ${error instanceof Error ? error.message : "unknown error"}`,
      );
    });

    if (!response.ok) {
      const body = await response.text().catch(() => "");

      throw new ExternalServiceError(
        `Open-Meteo request failed with ${response.status}: ${body || "no response body"}`,
      );
    }

    return (await response.json()) as T;
  }
}
