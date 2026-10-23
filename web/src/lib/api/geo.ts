import type { GeocodeResult } from './types';

// geoURL is Open-Meteo's free, key-less geocoding endpoint.
const geoURL = 'https://geocoding-api.open-meteo.com/v1/search';

// rawGeoResult is the shape Open-Meteo returns for a candidate place.
interface rawGeoResult {
	name: string;
	country?: string;
	admin1?: string;
	latitude: number;
	longitude: number;
}

// geocode resolves a place name to candidate coordinates. It is a separate seam
// from the Skua backend so the backend never needs to proxy search.
export async function geocode(query: string, signal?: AbortSignal): Promise<GeocodeResult[]> {
	const q = query.trim();
	if (!q) return [];
	const url = `${geoURL}?name=${encodeURIComponent(q)}&count=6&language=en&format=json`;
	const res = await fetch(url, { signal });
	if (!res.ok) return [];
	const data = (await res.json()) as { results?: rawGeoResult[] };
	return (data.results ?? []).map((r) => ({
		name: r.name,
		country: r.country,
		admin1: r.admin1,
		lat: r.latitude,
		lon: r.longitude
	}));
}
