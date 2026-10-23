<script lang="ts">
	import L from 'leaflet';
	import 'leaflet/dist/leaflet.css';
	import type { PanelProps } from '$lib/plugins';
	import type { Radar } from '$lib/api';
	import { current } from '$lib/stores/locations';
	import { theme, themes } from '$lib/theme';
	import Panel from './Panel.svelte';

	let { data, loading }: PanelProps = $props();
	let radar = $derived(data as Radar | null);

	let el = $state<HTMLDivElement | null>(null);
	let map = $state.raw<L.Map | null>(null);
	let idx = $state(0);
	let playing = $state(true);

	// layerCache holds one tile layer per frame so a completed loop replays from
	// the browser cache instead of refetching tiles.
	let layerCache = new Map<number, L.TileLayer>();

	// attribution credits the basemap and radar sources, as their terms require.
	const attribution = '&copy; OpenStreetMap, &copy; CARTO, radar by RainViewer';

	// baseUrl picks the CARTO basemap matching the active theme.
	function baseUrl(name: string): string {
		const flavor = name === 'storm' ? 'dark_all' : 'light_all';
		return `https://{s}.basemaps.cartocdn.com/${flavor}/{z}/{x}/{y}{r}.png`;
	}

	// tileUrl composes a RainViewer tile URL for one frame.
	function tileUrl(r: Radar, path: string): string {
		return `${r.host}${path}/512/{z}/{x}/{y}/2/1_1.png`;
	}

	// frameLayer returns the cached tile layer for a frame, creating and
	// attaching it invisibly on first use.
	function frameLayer(m: L.Map, r: Radar, i: number): L.TileLayer {
		let layer = layerCache.get(i);
		if (!layer) {
			layer = L.tileLayer(tileUrl(r, r.frames[i].path), { opacity: 0, zIndex: 10 });
			layer.addTo(m);
			layerCache.set(i, layer);
		}
		return layer;
	}

	// The map is created when the container and data are ready, and rebuilt when
	// the location or theme changes. The cleanup tears the old map down.
	$effect(() => {
		const container = el;
		const r = radar;
		const center: [number, number] = [$current.lat, $current.lon];
		const themeName = $theme;
		if (!container || !r) return;

		const m = L.map(container, { center, zoom: 6 });
		L.tileLayer(baseUrl(themeName), {
			subdomains: 'abcd',
			maxZoom: 12,
			attribution
		}).addTo(m);
		L.circleMarker(center, {
			radius: 6,
			color: themes[themeName].accent,
			fillColor: themes[themeName].accent,
			fillOpacity: 0.9,
			weight: 2
		}).addTo(m);
		layerCache = new Map();
		map = m;
		idx = 0;
		return () => {
			m.remove();
			map = null;
			layerCache = new Map();
		};
	});

	// The active frame shows at 0.7 opacity while every other cached frame stays
	// invisible, and the next frame preloads so the loop stays smooth.
	$effect(() => {
		const m = map;
		const r = radar;
		const i = idx;
		if (!m || !r || r.frames.length === 0) return;
		frameLayer(m, r, i);
		frameLayer(m, r, (i + 1) % r.frames.length);
		layerCache.forEach((layer, k) => layer.setOpacity(k === i ? 0.7 : 0));
	});

	// The animation advances while playing, looping through every frame.
	$effect(() => {
		const r = radar;
		if (!playing || !map || !r || r.frames.length === 0) return;
		const t = setInterval(() => {
			idx = (idx + 1) % r.frames.length;
		}, 600);
		return () => clearInterval(t);
	});

	let frame = $derived(radar?.frames[idx] ?? null);

	// stamp renders a frame time as a local clock reading.
	function stamp(iso: string): string {
		return new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
	}
</script>

<Panel title="Radar" wide>
	{#if radar}
		<div class="map" bind:this={el}></div>
		<div class="controls">
			<button type="button" class="play" onclick={() => (playing = !playing)}>
				{playing ? 'Pause' : 'Play'}
			</button>
			{#if frame}
				<span class="stamp">{stamp(frame.time)}</span>
				{#if frame.future}<span class="chip">Forecast</span>{/if}
			{/if}
		</div>
	{:else if loading}
		<p class="dim">Warming up the radar...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.map {
		height: 400px;
		border-radius: 10px;
		overflow: hidden;
	}
	.controls {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-top: 10px;
	}
	.play {
		padding: 5px 14px;
		border-radius: 8px;
		border: 1px solid var(--hair);
		background: transparent;
		color: var(--text);
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
	}
	.play:hover {
		border-color: var(--accent);
	}
	.stamp {
		font-family: var(--mono);
		font-size: 0.85rem;
		color: var(--muted);
		font-variant-numeric: tabular-nums;
	}
	.chip {
		font-size: 0.65rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		padding: 2px 7px;
		border-radius: 5px;
		background: var(--accent);
		color: var(--accent-ink);
		font-weight: 700;
	}
	.dim {
		color: var(--muted);
	}
</style>
