import type { Plugin } from './types';
import { tierRank, type Tier } from '$lib/stores/settings';

// registry holds every registered plugin.
const registry: Plugin[] = [];

// register adds one or more plugins to the dashboard. Duplicate ids are ignored.
export function register(...plugins: Plugin[]): void {
	for (const p of plugins) {
		if (!registry.some((x) => x.id === p.id)) registry.push(p);
	}
}

// allPlugins returns every registered plugin in display order.
export function allPlugins(): Plugin[] {
	return [...registry].sort((a, b) => a.order - b.order);
}

// pluginsForTier returns the plugins available at or below the given tier.
export function pluginsForTier(tier: Tier): Plugin[] {
	return allPlugins().filter((p) => tierRank[p.tier] <= tierRank[tier]);
}
