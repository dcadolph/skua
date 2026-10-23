import type { Component } from 'svelte';
import type { Location, SkuaClient } from '$lib/api';
import type { Settings, Tier } from '$lib/stores/settings';

// PluginLoad fetches a plugin's own data for a location. Each plugin owns its
// data source, so a new plugin can hit a different endpoint (air quality, surf,
// aurora) without the core knowing anything about it. The optional watched value
// is whatever the plugin's watch function returned, letting a plugin fold in a
// settings slice such as the voice level.
export type PluginLoad = (
	loc: Location,
	client: SkuaClient,
	signal?: AbortSignal,
	watched?: unknown
) => Promise<unknown>;

// PanelProps is what every plugin panel receives once its data has loaded. The
// data is unknown at the boundary; each panel narrows it to its own type.
export interface PanelProps {
	data: unknown;
	loading: boolean;
	error: boolean;
}

// Plugin is a self-contained dashboard feature: it loads its own data and
// renders its own panel. Core features and future add-ons implement this
// identically, so the core never imports a specific plugin.
export interface Plugin {
	// id is a stable unique identifier.
	id: string;
	// name is the human-readable label.
	name: string;
	// tier gates the plugin behind a subscription level.
	tier: Tier;
	// order controls placement on the dashboard, lower first.
	order: number;
	// load fetches the plugin's data for a location.
	load: PluginLoad;
	// panel is the Svelte component rendered with the loaded data.
	panel: Component<PanelProps>;
	// watch selects the settings slice this plugin reloads on. When the returned
	// value changes, the plugin refetches. Location-only plugins omit it.
	watch?: (settings: Settings) => unknown;
	// relevant decides whether the plugin applies to a location at all, for
	// locale-specific plugins like aurora that only make sense at high latitude.
	// Omitted means always relevant. Plugins that can only tell from their data
	// (marine at an inland point) instead render nothing in their panel.
	relevant?: (loc: Location) => boolean;
}
