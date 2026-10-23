import { weatherColors } from './tokens';

// hex parses a #rrggbb string into r, g, b components.
function hex(h: string): [number, number, number] {
	const n = parseInt(h.slice(1), 16);
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

// mix blends two hex colors, with t from 0 (a) to 1 (b).
function mix(a: string, b: string, t: number): string {
	const ca = hex(a);
	const cb = hex(b);
	const r = Math.round(ca[0] + (cb[0] - ca[0]) * t);
	const g = Math.round(ca[1] + (cb[1] - ca[1]) * t);
	const bl = Math.round(ca[2] + (cb[2] - ca[2]) * t);
	return `rgb(${r}, ${g}, ${bl})`;
}

// tempColor maps a Celsius temperature to a color on the cold-to-hot ramp.
export function tempColor(c: number): string {
	if (c <= 0) return weatherColors.tempCold;
	if (c <= 12) return mix(weatherColors.tempCold, weatherColors.tempMild, c / 12);
	if (c <= 24) return mix(weatherColors.tempMild, weatherColors.tempWarm, (c - 12) / 12);
	if (c <= 36) return mix(weatherColors.tempWarm, weatherColors.tempHot, (c - 24) / 12);
	return weatherColors.tempHot;
}
