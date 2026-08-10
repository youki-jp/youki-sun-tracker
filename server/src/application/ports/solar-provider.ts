import type {
  LocationInput,
  IsoDateString,
  SkyEventKind,
  SolarEventWindow,
  SolarSample,
  TimeRange,
} from "../../domain";

export interface SolarProvider {
  getSolarEventWindow(input: {
    location: LocationInput;
    timezoneId: string;
    targetDateIso: IsoDateString;
    kind: SkyEventKind;
  }): Promise<SolarEventWindow>;

  listSolarSamples(input: {
    location: LocationInput;
    timezoneId: string;
    kind: SkyEventKind;
    range: TimeRange;
  }): Promise<SolarSample[]>;
}
