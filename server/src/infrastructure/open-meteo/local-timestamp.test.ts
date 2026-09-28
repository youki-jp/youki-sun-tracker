import { describe, expect, test } from "bun:test";
import { ExternalServiceError } from "../../application/errors";
import { normalizeOpenMeteoLocalTimestamp } from "./local-timestamp";

describe("Open-Meteo local timestamp normalization", () => {
  test("adds seconds to minute timestamps and preserves second timestamps", () => {
    expect(normalizeOpenMeteoLocalTimestamp("2026-09-25T12:34")).toBe("2026-09-25T12:34:00");
    expect(normalizeOpenMeteoLocalTimestamp("2026-09-25T12:34:56")).toBe("2026-09-25T12:34:56");
  });

  test.each(["2026-09-25T12:34Z", "2026-09-25T12:34+09:00", "2026-02-30T12:34", "2026-09-25T24:00", "invalid"]) (
    "rejects malformed or zone-bearing value %s",
    (timestamp) => expect(() => normalizeOpenMeteoLocalTimestamp(timestamp)).toThrow(ExternalServiceError),
  );
});
