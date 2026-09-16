export interface SolarPosition {
  elevationDegrees: number;
  azimuthDegrees: number;
}

const DEGREES_PER_RADIAN = 180 / Math.PI;
const MILLIS_PER_DAY = 86_400_000;
const JULIAN_DAY_AT_UNIX_EPOCH = 2_440_587.5;
const JULIAN_DAY_AT_J2000 = 2_451_545;
const DAYS_PER_JULIAN_CENTURY = 36_525;

/**
 * NOAA solar position algorithm. Accurate to roughly a hundredth of a degree
 * for the years 1901-2099, which is far beyond what sky color needs.
 *
 * Adapted from the NOAA Global Monitoring Laboratory solar calculator, working
 * in UTC throughout rather than the spreadsheet's local-time-plus-offset form.
 */
export function calculateSolarPosition(input: {
  utcMillis: number;
  latitude: number;
  longitude: number;
}): SolarPosition {
  const { utcMillis, latitude, longitude } = input;
  const julianCentury =
    (utcMillis / MILLIS_PER_DAY + JULIAN_DAY_AT_UNIX_EPOCH - JULIAN_DAY_AT_J2000) /
    DAYS_PER_JULIAN_CENTURY;

  const geomMeanLongitude = normalizeDegrees(
    280.46646 + julianCentury * (36_000.76983 + julianCentury * 0.0003032),
  );
  const geomMeanAnomaly =
    357.52911 + julianCentury * (35_999.05029 - 0.0001537 * julianCentury);
  const eccentricity =
    0.016708634 -
    julianCentury * (0.000042037 + 0.0000001267 * julianCentury);

  const equationOfCenter =
    Math.sin(toRadians(geomMeanAnomaly)) *
      (1.914602 - julianCentury * (0.004817 + 0.000014 * julianCentury)) +
    Math.sin(toRadians(2 * geomMeanAnomaly)) *
      (0.019993 - 0.000101 * julianCentury) +
    Math.sin(toRadians(3 * geomMeanAnomaly)) * 0.000289;

  const trueLongitude = geomMeanLongitude + equationOfCenter;
  const apparentLongitude =
    trueLongitude -
    0.00569 -
    0.00478 * Math.sin(toRadians(125.04 - 1_934.136 * julianCentury));

  const meanObliquity =
    23 +
    (26 +
      (21.448 -
        julianCentury *
          (46.815 + julianCentury * (0.00059 - julianCentury * 0.001813))) /
        60) /
      60;
  const obliquityCorrection =
    meanObliquity +
    0.00256 * Math.cos(toRadians(125.04 - 1_934.136 * julianCentury));

  const declination = toDegrees(
    Math.asin(
      Math.sin(toRadians(obliquityCorrection)) *
        Math.sin(toRadians(apparentLongitude)),
    ),
  );

  const varY = Math.tan(toRadians(obliquityCorrection / 2)) ** 2;
  const equationOfTimeMinutes =
    4 *
    toDegrees(
      varY * Math.sin(2 * toRadians(geomMeanLongitude)) -
        2 * eccentricity * Math.sin(toRadians(geomMeanAnomaly)) +
        4 *
          eccentricity *
          varY *
          Math.sin(toRadians(geomMeanAnomaly)) *
          Math.cos(2 * toRadians(geomMeanLongitude)) -
        0.5 * varY * varY * Math.sin(4 * toRadians(geomMeanLongitude)) -
        1.25 *
          eccentricity *
          eccentricity *
          Math.sin(2 * toRadians(geomMeanAnomaly)),
    );

  const utcMinutesIntoDay = getUtcMinutesIntoDay(utcMillis);
  const trueSolarTimeMinutes = mod(
    utcMinutesIntoDay + equationOfTimeMinutes + 4 * longitude,
    1_440,
  );
  const hourAngle =
    trueSolarTimeMinutes / 4 < 0
      ? trueSolarTimeMinutes / 4 + 180
      : trueSolarTimeMinutes / 4 - 180;

  const latitudeRadians = toRadians(latitude);
  const declinationRadians = toRadians(declination);
  const zenithRadians = Math.acos(
    clamp(
      Math.sin(latitudeRadians) * Math.sin(declinationRadians) +
        Math.cos(latitudeRadians) *
          Math.cos(declinationRadians) *
          Math.cos(toRadians(hourAngle)),
      -1,
      1,
    ),
  );

  const trueElevation = 90 - toDegrees(zenithRadians);

  return {
    elevationDegrees: trueElevation + getRefractionDegrees(trueElevation),
    azimuthDegrees: getAzimuthDegrees({
      hourAngle,
      zenithRadians,
      latitudeRadians,
      declinationRadians,
    }),
  };
}

function getAzimuthDegrees(input: {
  hourAngle: number;
  zenithRadians: number;
  latitudeRadians: number;
  declinationRadians: number;
}): number {
  const { hourAngle, zenithRadians, latitudeRadians, declinationRadians } = input;
  const denominator = Math.cos(latitudeRadians) * Math.sin(zenithRadians);

  // Directly overhead or at the pole: azimuth is undefined, so pick due south.
  if (Math.abs(denominator) < 1e-9) {
    return 180;
  }

  const azimuthRadians = Math.acos(
    clamp(
      (Math.sin(latitudeRadians) * Math.cos(zenithRadians) -
        Math.sin(declinationRadians)) /
        denominator,
      -1,
      1,
    ),
  );

  return hourAngle > 0
    ? mod(toDegrees(azimuthRadians) + 180, 360)
    : mod(540 - toDegrees(azimuthRadians), 360);
}

/**
 * Atmospheric refraction lifts the apparent sun above its true position, by
 * about half a degree at the horizon. That matters here: it is the difference
 * between the sun appearing to sit on the horizon and being fully below it.
 */
function getRefractionDegrees(trueElevationDegrees: number): number {
  if (trueElevationDegrees > 85) {
    return 0;
  }

  const tangent = Math.tan(toRadians(trueElevationDegrees));
  let arcSeconds: number;

  if (trueElevationDegrees > 5) {
    arcSeconds =
      58.1 / tangent - 0.07 / tangent ** 3 + 0.000086 / tangent ** 5;
  } else if (trueElevationDegrees > -0.575) {
    arcSeconds =
      1_735 +
      trueElevationDegrees *
        (-518.2 +
          trueElevationDegrees *
            (103.4 +
              trueElevationDegrees *
                (-12.79 + trueElevationDegrees * 0.711)));
  } else {
    arcSeconds = -20.772 / tangent;
  }

  return arcSeconds / 3_600;
}

function getUtcMinutesIntoDay(utcMillis: number): number {
  const date = new Date(utcMillis);

  return (
    date.getUTCHours() * 60 +
    date.getUTCMinutes() +
    date.getUTCSeconds() / 60
  );
}

function toRadians(degrees: number): number {
  return degrees / DEGREES_PER_RADIAN;
}

function toDegrees(radians: number): number {
  return radians * DEGREES_PER_RADIAN;
}

function normalizeDegrees(degrees: number): number {
  return mod(degrees, 360);
}

function mod(value: number, modulus: number): number {
  return ((value % modulus) + modulus) % modulus;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
