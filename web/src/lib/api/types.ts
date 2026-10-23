// These types mirror the JSON the Skua backend returns. They are the contract
// between the app and the API, and the basis of a future standalone SDK.

// Location is a geographic coordinate.
export interface Location {
	lat: number;
	lon: number;
}

// Current holds present weather conditions.
export interface Current {
	time: string;
	condition: string;
	tempC: number;
	apparentTempC: number;
	precipMM: number;
	windKph: number;
	humidity: number;
	windDirDeg: number;
	uvIndex: number;
	pressureHPa: number;
	dewPointC: number;
	visibilityKm: number;
	windGustKph: number;
	cloudCover: number;
	isDay: boolean;
}

// HourlyPoint is the forecast for a single hour.
export interface HourlyPoint {
	time: string;
	condition: string;
	tempC: number;
	precipMM: number;
	windKph: number;
	precipProb: number;
}

// DailyPoint is the forecast for a single day.
export interface DailyPoint {
	date: string;
	sunrise: string;
	sunset: string;
	condition: string;
	highC: number;
	lowC: number;
	uvIndexMax: number;
	precipProb: number;
}

// MinutelyPoint is expected precipitation for one short interval.
export interface MinutelyPoint {
	time: string;
	precipMM: number;
}

// Forecast is the normalized weather result.
export interface Forecast {
	source: string;
	location: Location;
	current: Current;
	minutely?: MinutelyPoint[];
	hourly: HourlyPoint[];
	daily: DailyPoint[];
}

// Voice is the skua's generated line and daily briefing.
export interface Voice {
	line: string;
	briefing: string;
}

// VoiceLevel is the maturity and profanity setting for the skua's voice, from
// clean and professional to unhinged and raunchy.
export type VoiceLevel = 'proper' | 'sassy' | 'salty' | 'feral';

// Marine holds current sea state for a coastal location. available is false at
// inland points, which is how the client knows to hide the panel.
export interface Marine {
	available: boolean;
	time: string;
	waveHeightM: number;
	waveDirectionDeg: number;
	wavePeriodS: number;
	swellHeightM: number;
	swellPeriodS: number;
}

// Aurora holds the current planetary Kp index and a visibility estimate for a
// location's latitude.
export interface Aurora {
	time: string;
	kp: number;
	level: string;
	visible: boolean;
}

// RadarFrame is one radar tile layer. Tile URLs compose as
// host + path + /{size}/{z}/{x}/{y}/{color}/{options}.png.
export interface RadarFrame {
	time: string;
	path: string;
	future: boolean;
}

// Radar is the set of renderable radar frames, past then forecast.
export interface Radar {
	host: string;
	frames: RadarFrame[];
}

// Alert is one active weather alert.
export interface Alert {
	event: string;
	headline: string;
	severity: string;
	urgency: string;
	area: string;
	onset: string;
	ends: string;
	description: string;
	instruction: string;
}

// Alerts is the set of active alerts for a location, most severe first.
export interface Alerts {
	alerts: Alert[];
}

// AirQuality holds current air-quality conditions.
export interface AirQuality {
	time: string;
	category: string;
	usAqi: number;
	pm25: number;
	pm10: number;
	ozone: number;
	no2: number;
	uvIndex: number;
}

// GeocodeResult is a candidate place from a location search.
export interface GeocodeResult {
	name: string;
	country?: string;
	admin1?: string;
	lat: number;
	lon: number;
}
