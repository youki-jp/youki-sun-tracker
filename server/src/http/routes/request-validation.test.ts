import { describe, expect, test } from "bun:test";
import { ValidationError } from "../../application/errors";
import { isRecord, optionalDateString, parseLocation } from "./request-validation";

describe("forecast request validation", () => {
  test("accepts valid calendar dates including leap day", () => {
    expect(optionalDateString("2024-02-29", "targetDateIso")).toBe("2024-02-29");
    expect(optionalDateString("2025-03-01", "targetDateIso")).toBe("2025-03-01");
  });

  test.each(["2025-02-29", "2024-02-30", "2024-13-01", "2024-00-10", "2024-1-01"]) (
    "rejects impossible date %s",
    (date) => expect(() => optionalDateString(date, "targetDateIso")).toThrow(ValidationError),
  );

  test("rejects array objects and invalid coordinates", () => {
    expect(isRecord([])).toBe(false);
    expect(() => parseLocation([], "")).toThrow(ValidationError);
    expect(() => parseLocation({ latitude: Infinity, longitude: 0 }, "")).toThrow(ValidationError);
    expect(() => parseLocation({ latitude: 91, longitude: 0 }, "")).toThrow(ValidationError);
  });
});
