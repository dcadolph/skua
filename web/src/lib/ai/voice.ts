import type { AiFeature } from './types';
import type { Forecast, SkuaClient, Voice, VoiceLevel } from '$lib/api';

// voiceFeature wraps the backend voice endpoint as an AiFeature at a given level
// and unit system, so the skua's voice is just one entry in a growing set of AI
// capabilities.
export function voiceFeature(
	client: SkuaClient,
	level: VoiceLevel = 'proper',
	units: 'metric' | 'imperial' = 'metric'
): AiFeature<Voice> {
	return {
		id: 'voice',
		run: (forecast: Forecast, signal?: AbortSignal) =>
			client.voice(forecast.location, level, units, signal)
	};
}
