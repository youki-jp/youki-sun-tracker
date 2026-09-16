import type {
  NormalizedSkyObservation,
  SkyGradientOutput,
} from "../../domain/sky-gradient";

export interface SkyGradientEngine {
  generate(input: NormalizedSkyObservation): SkyGradientOutput;
}
