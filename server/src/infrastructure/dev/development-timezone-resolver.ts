import type { TimezoneResolver } from "../../application/ports/timezone-resolver";
import type { LocationInput } from "../../domain";

export class DevelopmentTimezoneResolver implements TimezoneResolver {
  async resolveTimezone(_location: LocationInput): Promise<string> {
    return "UTC";
  }
}
