import type { SkyColorEventContext, SkyColorPrediction } from "../../domain";

export interface SkyColorEngine {
  predict(contexts: SkyColorEventContext[]): Promise<SkyColorPrediction[]>;
}
