import type { VoiceLevel } from '$lib/api';
import type { Tier } from '$lib/stores/settings';

// VoiceLevelMeta describes one maturity level for the picker: its label, a short
// blurb, the lowest tier that unlocks it, and whether it needs an 18+ opt-in.
export interface VoiceLevelMeta {
	id: VoiceLevel;
	label: string;
	blurb: string;
	minTier: Tier;
	adult: boolean;
}

// VOICE_LEVELS is the ordered ladder shown in the picker, clean to unhinged.
export const VOICE_LEVELS: VoiceLevelMeta[] = [
	{ id: 'proper', label: 'Proper', blurb: 'Clean and professional.', minTier: 'free', adult: false },
	{ id: 'sassy', label: 'Sassy', blurb: 'Snarky, no cursing.', minTier: 'free', adult: false },
	{ id: 'salty', label: 'Salty', blurb: 'Real profanity, crude.', minTier: 'plus', adult: true },
	{ id: 'feral', label: 'Feral', blurb: 'Unfiltered, raunchy, lewd.', minTier: 'plus', adult: true }
];

// voiceLevelMeta returns the metadata for a level.
export function voiceLevelMeta(id: VoiceLevel): VoiceLevelMeta {
	return VOICE_LEVELS.find((l) => l.id === id) ?? VOICE_LEVELS[0];
}
