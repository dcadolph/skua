import type { Forecast } from '$lib/api';

// AiFeature is any AI-backed capability. The voice is the first; future chat,
// briefings, and other LLM connections implement the same shape.
export interface AiFeature<Result> {
	// id is a stable identifier.
	id: string;
	// run produces the feature's result for a forecast.
	run(forecast: Forecast, signal?: AbortSignal): Promise<Result>;
}
