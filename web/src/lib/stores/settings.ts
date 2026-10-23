import { writable } from 'svelte/store';
import type { VoiceLevel } from '$lib/api';

// Tier is the subscription level. It gates plugins and premium features.
export type Tier = 'free' | 'plus' | 'pro';

// Units is the measurement system for display.
export type Units = 'metric' | 'imperial';

// Settings holds user preferences.
export interface Settings {
	// units is the measurement system for display.
	units: Units;
	// tier is the active subscription level.
	tier: Tier;
	// voiceLevel is the maturity and profanity level for the skua's voice.
	voiceLevel: VoiceLevel;
	// adult records a one-time acknowledgment that the user is 18 or older,
	// required before the crude voice levels unlock.
	adult: boolean;
}

// storageKey is where settings are persisted.
const storageKey = 'skua.settings';

// defaultUnits picks the measurement system from the browser locale, so a US
// visitor sees Fahrenheit before ever touching a setting.
function defaultUnits(): Units {
	if (typeof navigator !== 'undefined' && navigator.language?.endsWith('-US')) {
		return 'imperial';
	}
	return 'metric';
}

// defaults is the starting settings for a new user.
const defaults: Settings = { units: defaultUnits(), tier: 'free', voiceLevel: 'proper', adult: false };

// tierRank orders the subscription tiers for comparison.
export const tierRank: Record<Tier, number> = { free: 0, plus: 1, pro: 2 };

// tierAtLeast reports whether have meets or exceeds need.
export function tierAtLeast(have: Tier, need: Tier): boolean {
	return tierRank[have] >= tierRank[need];
}

// initial reads saved settings, merged over the defaults.
function initial(): Settings {
	if (typeof localStorage !== 'undefined') {
		const raw = localStorage.getItem(storageKey);
		if (raw) {
			try {
				return { ...defaults, ...(JSON.parse(raw) as Partial<Settings>) };
			} catch {
				// Ignore corrupt storage and fall back to defaults.
			}
		}
	}
	return { ...defaults };
}

// settings holds the user's preferences.
export const settings = writable<Settings>(initial());

settings.subscribe((s) => {
	if (typeof localStorage !== 'undefined') localStorage.setItem(storageKey, JSON.stringify(s));
});
