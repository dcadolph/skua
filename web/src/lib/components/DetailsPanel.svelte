<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Forecast } from '$lib/api';
	import { settings } from '$lib/stores/settings';
	import {
		tempValue,
		speedValue,
		speedUnit,
		distanceValue,
		distanceUnit,
		pressureValue,
		pressureUnit,
		precipValue,
		precipUnit
	} from '$lib/units';
	import Panel from './Panel.svelte';

	let { data, loading }: PanelProps = $props();
	let c = $derived((data as Forecast | null)?.current ?? null);
	let u = $derived($settings.units);

	// uvColor follows the WHO UV bands.
	function uvColor(uv: number): string {
		if (uv < 3) return '#3fb68b';
		if (uv < 6) return '#e0b040';
		if (uv < 8) return '#e08640';
		if (uv < 11) return '#d65454';
		return '#9b6dd6';
	}

	function uvLabel(uv: number): string {
		if (uv < 3) return 'Low';
		if (uv < 6) return 'Moderate';
		if (uv < 8) return 'High';
		if (uv < 11) return 'Very high';
		return 'Extreme';
	}

	// The UV gauge is a semicircle arc; the dash length paints the fraction of
	// the 0 to 11+ scale.
	const arcLen = Math.PI * 34;
	let uvFrac = $derived(c ? Math.min(1, c.uvIndex / 11) : 0);

	// compassDir renders a cardinal name from a bearing.
	function compassDir(deg: number): string {
		const points = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
		return points[Math.round(deg / 22.5) % 16];
	}
</script>

<Panel title="Details">
	{#if c}
		<div class="visuals">
			<div class="vis">
				<svg viewBox="0 0 90 90" class="compass" aria-hidden="true">
					<circle cx="45" cy="45" r="38" fill="none" stroke="var(--hair)" stroke-width="1.5" />
					<text x="45" y="14" class="pt">N</text>
					<text x="80" y="49" class="pt">E</text>
					<text x="45" y="86" class="pt">S</text>
					<text x="10" y="49" class="pt">W</text>
					<g transform="rotate({c.windDirDeg} 45 45)">
						<path d="M45 13 L49 27 L45 23.5 L41 27 Z" fill="var(--accent)" stroke="none" />
						<line x1="45" y1="25" x2="45" y2="62" stroke="var(--accent)" stroke-width="1.6" />
					</g>
				</svg>
				<div class="vlabel">
					<span class="k">Wind</span>
					<span class="v">{speedValue(c.windKph, u)} <span class="sub">{speedUnit(u)} {compassDir(c.windDirDeg)}</span></span>
					<span class="sub2">Gusts {speedValue(c.windGustKph, u)} {speedUnit(u)}</span>
				</div>
			</div>
			<div class="vis">
				<svg viewBox="0 0 90 58" class="gauge" aria-hidden="true">
					<path d="M 11 52 A 34 34 0 0 1 79 52" fill="none" stroke="var(--hair)" stroke-width="6" stroke-linecap="round" />
					<path
						d="M 11 52 A 34 34 0 0 1 79 52"
						fill="none"
						stroke={uvColor(c.uvIndex)}
						stroke-width="6"
						stroke-linecap="round"
						stroke-dasharray="{Math.max(0.01, uvFrac) * arcLen} {arcLen}"
					/>
					<text x="45" y="46" class="big">{c.uvIndex.toFixed(1)}</text>
				</svg>
				<div class="vlabel">
					<span class="k">UV index</span>
					<span class="v">{uvLabel(c.uvIndex)}</span>
				</div>
			</div>
		</div>
		<div class="grid">
			<div class="cell">
				<span class="k">Dew point</span>
				<span class="v">{tempValue(c.dewPointC, u)}&deg;</span>
			</div>
			<div class="cell">
				<span class="k">Humidity</span>
				<span class="v">{c.humidity}%</span>
			</div>
			<div class="cell">
				<span class="k">Pressure</span>
				<span class="v">{pressureValue(c.pressureHPa, u)} <span class="sub">{pressureUnit(u)}</span></span>
			</div>
			<div class="cell">
				<span class="k">Visibility</span>
				<span class="v">{distanceValue(c.visibilityKm, u)} <span class="sub">{distanceUnit(u)}</span></span>
			</div>
			<div class="cell">
				<span class="k">Cloud cover</span>
				<span class="v">{c.cloudCover}%</span>
			</div>
			<div class="cell">
				<span class="k">Precip</span>
				<span class="v">{precipValue(c.precipMM, u)} <span class="sub">{precipUnit(u)}</span></span>
			</div>
		</div>
	{:else if loading}
		<p class="dim">Loading...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.visuals {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 16px;
		padding-bottom: 14px;
		border-bottom: 1px solid var(--hair);
	}
	.vis {
		display: flex;
		align-items: center;
		gap: 12px;
	}
	.compass {
		width: 84px;
		height: 84px;
		flex: 0 0 auto;
	}
	.gauge {
		width: 84px;
		height: 54px;
		flex: 0 0 auto;
	}
	.pt {
		font-size: 9px;
		fill: var(--muted);
		text-anchor: middle;
		font-family: var(--mono);
	}
	.big {
		font-size: 17px;
		font-weight: 700;
		fill: var(--text);
		text-anchor: middle;
	}
	.vlabel {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.sub2 {
		font-size: 0.75rem;
		color: var(--muted);
	}
	.grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 12px 20px;
	}
	.cell {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.k {
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--muted);
	}
	.v {
		font-size: 1.1rem;
		font-weight: 600;
	}
	.sub {
		font-size: 0.8rem;
		font-weight: 400;
		color: var(--muted);
	}
	.dim {
		color: var(--muted);
	}
</style>
