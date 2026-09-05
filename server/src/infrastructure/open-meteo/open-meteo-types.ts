export interface OpenMeteoDailyForecastResponse {
  timezone?: string;
  timezone_abbreviation?: string;
  daily?: {
    time?: string[];
    sunrise?: string[];
    sunset?: string[];
  };
}

export interface OpenMeteoWeatherResponse {
  timezone?: string;
  timezone_abbreviation?: string;
  hourly?: {
    time?: string[];
    cloud_cover?: Array<number | null>;
    cloud_cover_low?: Array<number | null>;
    cloud_cover_mid?: Array<number | null>;
    cloud_cover_high?: Array<number | null>;
    visibility?: Array<number | null>;
    relative_humidity_2m?: Array<number | null>;
    dew_point_2m?: Array<number | null>;
    precipitation?: Array<number | null>;
  };
}

export interface OpenMeteoAirQualityResponse {
  timezone?: string;
  timezone_abbreviation?: string;
  hourly?: {
    time?: string[];
    aerosol_optical_depth?: Array<number | null>;
    pm2_5?: Array<number | null>;
    pm10?: Array<number | null>;
    dust?: Array<number | null>;
    ozone?: Array<number | null>;
  };
}
