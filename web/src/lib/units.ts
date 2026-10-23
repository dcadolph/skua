import type { Units } from '$lib/stores/settings';

// The backend always speaks metric; conversion is a display concern. Value
// helpers return preformatted numbers without labels so panels keep control of
// unit-label styling, and unit helpers return the matching label.

// tempValue converts Celsius for display, rounded to a whole degree.
export function tempValue(c: number, u: Units): number {
	return Math.round(u === 'imperial' ? c * 1.8 + 32 : c);
}

// speedValue converts kilometers per hour for display.
export function speedValue(kph: number, u: Units): number {
	return Math.round(u === 'imperial' ? kph * 0.621371 : kph);
}

// speedUnit is the label for speedValue.
export function speedUnit(u: Units): string {
	return u === 'imperial' ? 'mph' : 'kph';
}

// distanceValue converts kilometers for display with one decimal.
export function distanceValue(km: number, u: Units): string {
	return (u === 'imperial' ? km * 0.621371 : km).toFixed(1);
}

// distanceUnit is the label for distanceValue.
export function distanceUnit(u: Units): string {
	return u === 'imperial' ? 'mi' : 'km';
}

// pressureValue converts hectopascals for display: whole hPa, two-decimal inHg.
export function pressureValue(hpa: number, u: Units): string {
	return u === 'imperial' ? (hpa * 0.02953).toFixed(2) : Math.round(hpa).toString();
}

// pressureUnit is the label for pressureValue.
export function pressureUnit(u: Units): string {
	return u === 'imperial' ? 'inHg' : 'hPa';
}

// precipValue converts millimeters for display: one-decimal mm, two-decimal in.
export function precipValue(mm: number, u: Units): string {
	return u === 'imperial' ? (mm * 0.0393701).toFixed(2) : mm.toFixed(1);
}

// precipUnit is the label for precipValue.
export function precipUnit(u: Units): string {
	return u === 'imperial' ? 'in' : 'mm';
}

// heightValue converts meters for display with one decimal, used for waves.
export function heightValue(m: number, u: Units): string {
	return (u === 'imperial' ? m * 3.28084 : m).toFixed(1);
}

// heightUnit is the label for heightValue.
export function heightUnit(u: Units): string {
	return u === 'imperial' ? 'ft' : 'm';
}
