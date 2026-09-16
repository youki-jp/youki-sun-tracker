import type {
  LocationInput,
  IsoDateString,
  SkyEventKind,
  SolarDayMilestones,
  SolarDaySample,
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

  getDayMilestones(input: {
    location: LocationInput;
    timezoneId: string;
    targetDateIso: IsoDateString;
  }): Promise<SolarDayMilestones>;

  listDaySamples(input: {
    location: LocationInput;
    timezoneId: string;
    targetDateIso: IsoDateString;
    milestones: SolarDayMilestones;
  }): Promise<SolarDaySample[]>;
}
