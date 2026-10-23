<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Forecast } from '$lib/api';
	import { tempColor } from '$lib/theme';
	import { settings } from '$lib/stores/settings';
	import { tempValue } from '$lib/units';
	import Panel from './Panel.svelte';
	import ConditionIcon from './ConditionIcon.svelte';

	let { data, loading }: PanelProps = $props();
	let hours = $derived(((data as Forecast | null)?.hourly ?? []).slice(0, 24));
	let u = $derived($settings.units);

	// Chart geometry in a fixed coordinate space, scaled to the panel width.
	const W = 720;
	const H = 130;
	const TOP = 14;
	const BOTTOM = 116;

	// points maps each hour onto the chart, x centered per column so the labels
	// above align with the curve.
	let points = $derived.by(() => {
		if (hours.length < 2) return [];
		const temps = hours.map((h) => h.tempC);
		const min = Math.min(...temps);
		const max = Math.max(...temps);
		const span = Math.max(1, max - min);
		return hours.map((h, i) => ({
			x: ((i + 0.5) / hours.length) * W,
			y: BOTTOM - ((h.tempC - min) / span) * (BOTTOM - TOP),
			h
		}));
	});

	// linePath renders the temperature curve with Catmull-Rom smoothing.
	let linePath = $derived.by(() => {
		const pts = points;
		if (pts.length < 2) return '';
		let d = `M ${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`;
		for (let i = 0; i < pts.length - 1; i++) {
			const p0 = pts[Math.max(0, i - 1)];
			const p1 = pts[i];
			const p2 = pts[i + 1];
			const p3 = pts[Math.min(pts.length - 1, i + 2)];
			const c1x = p1.x + (p2.x - p0.x) / 6;
			const c1y = p1.y + (p2.y - p0.y) / 6;
			const c2x = p2.x - (p3.x - p1.x) / 6;
			const c2y = p2.y - (p3.y - p1.y) / 6;
			d += ` C ${c1x.toFixed(1)} ${c1y.toFixed(1)}, ${c2x.toFixed(1)} ${c2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`;
		}
		return d;
	});

	// areaPath closes the curve down to the baseline for the gradient fill.
	let areaPath = $derived(
		linePath === ''
			? ''
			: `${linePath} L ${points[points.length - 1].x.toFixed(1)} ${H} L ${points[0].x.toFixed(1)} ${H} Z`
	);

	// labeled picks every third hour for the icon and temperature row.
	let labeled = $derived(points.filter((_, i) => i % 3 === 0));

	// The precip row only appears when rain is actually in play, and bars scale
	// on the absolute percent so a 1% hour reads as nearly nothing.
	let showPrecip = $derived(hours.some((h) => h.precipProb >= 10));

	function hr(t: string): string {
		return new Date(t).toLocaleTimeString([], { hour: 'numeric' });
	}

	function night(t: string): boolean {
		const h = new Date(t).getHours();
		return h < 6 || h >= 20;
	}
</script>

<Panel title="Next 24 hours" wide>
	{#if points.length > 1}
		<div class="chart">
			<div class="labels">
				{#each labeled as p (p.h.time)}
					<div class="lab" style="left:{(p.x / W) * 100}%">
						<div class="t dim">{hr(p.h.time)}</div>
						<div class="ico" style="color:{tempColor(p.h.tempC)}">
							<ConditionIcon condition={p.h.condition} night={night(p.h.time)} size={18} />
						</div>
						<div class="deg">{tempValue(p.h.tempC, u)}&deg;</div>
					</div>
				{/each}
			</div>
			<svg viewBox="0 0 {W} {H}" preserveAspectRatio="none" aria-hidden="true">
				<defs>
					<linearGradient id="skua-temp-fill" x1="0" y1="0" x2="0" y2="1">
						<stop offset="0" stop-color="var(--accent)" stop-opacity="0.22" />
						<stop offset="1" stop-color="var(--accent)" stop-opacity="0" />
					</linearGradient>
				</defs>
				<path d={areaPath} fill="url(#skua-temp-fill)" />
				<path
					d={linePath}
					fill="none"
					stroke="var(--accent)"
					stroke-width="2.2"
					vector-effect="non-scaling-stroke"
					stroke-linecap="round"
				/>
			</svg>
			{#if showPrecip}
				<div class="precip">
					{#each hours as h (h.time)}
						<div
							class="pbar"
							class:wet={h.precipProb >= 30}
							style="height:{Math.max(6, h.precipProb)}%"
							title="{hr(h.time)}: {h.precipProb}%"
						></div>
					{/each}
				</div>
			{/if}
		</div>
	{:else if loading}
		<p class="dim">Loading...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.chart {
		display: flex;
		flex-direction: column;
	}
	.labels {
		position: relative;
		height: 64px;
	}
	.lab {
		position: absolute;
		top: 0;
		transform: translateX(-50%);
		text-align: center;
	}
	.t {
		font-size: 0.7rem;
		font-family: var(--mono);
		white-space: nowrap;
	}
	.ico {
		display: flex;
		justify-content: center;
		margin: 5px 0 3px;
	}
	.deg {
		font-weight: 600;
		font-size: 0.85rem;
	}
	svg {
		width: 100%;
		height: 130px;
		display: block;
	}
	.precip {
		display: flex;
		align-items: flex-end;
		gap: 3px;
		height: 22px;
		margin-top: 6px;
	}
	.pbar {
		flex: 1;
		border-radius: 2px 2px 0 0;
		background: var(--hair);
		min-height: 2px;
	}
	.pbar.wet {
		background: #38a9ff;
	}
	.dim {
		color: var(--muted);
	}
</style>
