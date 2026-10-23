import { writable } from 'svelte/store';
import type { Location } from '$lib/api';

// SavedLocation is a location with a display name.
export interface SavedLocation extends Location {
	name: string;
}

// storageKey is where saved locations are persisted.
const storageKey = 'skua.locations';

// fallback is the default location for a new user.
const fallback: SavedLocation = { name: 'Austin', lat: 30.27, lon: -97.74 };

// load reads saved locations, defaulting to the fallback.
function load(): SavedLocation[] {
	if (typeof localStorage !== 'undefined') {
		const raw = localStorage.getItem(storageKey);
		if (raw) {
			try {
				const list = JSON.parse(raw) as SavedLocation[];
				if (list.length > 0) return list;
			} catch {
				// Ignore corrupt storage.
			}
		}
	}
	return [fallback];
}

// locations holds the user's saved places.
export const locations = writable<SavedLocation[]>(load());

// current holds the location the dashboard is showing.
export const current = writable<SavedLocation>(load()[0] ?? fallback);

locations.subscribe((l) => {
	if (typeof localStorage !== 'undefined') localStorage.setItem(storageKey, JSON.stringify(l));
});

// selectLocation sets the current location, saving it as a place if it is new.
export function selectLocation(loc: SavedLocation): void {
	current.set(loc);
	locations.update((list) =>
		list.some((x) => x.name === loc.name && x.lat === loc.lat) ? list : [...list, loc]
	);
}

// removeLocation drops a saved place by name and coordinate.
export function removeLocation(loc: SavedLocation): void {
	locations.update((list) => {
		const next = list.filter((x) => !(x.name === loc.name && x.lat === loc.lat));
		return next.length > 0 ? next : [fallback];
	});
}
