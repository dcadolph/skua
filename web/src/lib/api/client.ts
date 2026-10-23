import type {
	AirQuality,
	Alerts,
	Aurora,
	Forecast,
	Location,
	Marine,
	Radar,
	Voice,
	VoiceLevel
} from './types';

// Transport is the fetch-like function the client uses. It is injectable so the
// client can be tested or run in non-browser environments.
export type Transport = typeof fetch;

// SkuaClientOptions configures a SkuaClient.
export interface SkuaClientOptions {
	baseUrl: string;
	transport?: Transport;
}

// SkuaError carries the HTTP status from a failed request.
export class SkuaError extends Error {
	status: number;

	constructor(status: number, message: string) {
		super(message);
		this.name = 'SkuaError';
		this.status = status;
	}
}

// SkuaClient is a typed client for the Skua backend. It is the single seam
// between the app and the API, and is built to be lifted out as an SDK.
export class SkuaClient {
	#baseUrl: string;
	#fetch: Transport;

	constructor(opts: SkuaClientOptions) {
		this.#baseUrl = opts.baseUrl.replace(/\/$/, '');
		this.#fetch = opts.transport ?? fetch;
	}

	// forecast fetches the normalized forecast for a coordinate.
	async forecast(loc: Location, signal?: AbortSignal): Promise<Forecast> {
		return this.#get<Forecast>('/forecast', loc, {}, signal);
	}

	// voice fetches the skua's line and briefing for a coordinate, spoken at a
	// maturity level in a unit system.
	async voice(
		loc: Location,
		level: VoiceLevel = 'proper',
		units: 'metric' | 'imperial' = 'metric',
		signal?: AbortSignal
	): Promise<Voice> {
		return this.#get<Voice>('/voice', loc, { level, units }, signal);
	}

	// airQuality fetches current air quality for a coordinate.
	async airQuality(loc: Location, signal?: AbortSignal): Promise<AirQuality> {
		return this.#get<AirQuality>('/airquality', loc, {}, signal);
	}

	// marine fetches current sea state for a coordinate.
	async marine(loc: Location, signal?: AbortSignal): Promise<Marine> {
		return this.#get<Marine>('/marine', loc, {}, signal);
	}

	// aurora fetches the current planetary Kp and visibility for a coordinate.
	async aurora(loc: Location, signal?: AbortSignal): Promise<Aurora> {
		return this.#get<Aurora>('/aurora', loc, {}, signal);
	}

	// alerts fetches the active weather alerts for a coordinate.
	async alerts(loc: Location, signal?: AbortSignal): Promise<Alerts> {
		return this.#get<Alerts>('/alerts', loc, {}, signal);
	}

	// radar fetches the radar frame index. It is not location specific; the
	// frames cover the world and the client renders them wherever it is looking.
	async radar(signal?: AbortSignal): Promise<Radar> {
		const res = await this.#fetch(`${this.#baseUrl}/radar`, { signal });
		if (!res.ok) {
			throw new SkuaError(res.status, '/radar request failed');
		}
		return (await res.json()) as Radar;
	}

	async #get<T>(
		path: string,
		loc: Location,
		extra: Record<string, string>,
		signal?: AbortSignal
	): Promise<T> {
		const params = new URLSearchParams({ lat: String(loc.lat), lon: String(loc.lon), ...extra });
		const url = `${this.#baseUrl}${path}?${params.toString()}`;
		const res = await this.#fetch(url, { signal });
		if (!res.ok) {
			throw new SkuaError(res.status, `${path} request failed`);
		}
		return (await res.json()) as T;
	}
}
