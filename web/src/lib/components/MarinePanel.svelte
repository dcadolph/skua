<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Marine } from '$lib/api';
	import { settings } from '$lib/stores/settings';
	import { heightValue, heightUnit } from '$lib/units';
	import Panel from './Panel.svelte';

	let { data }: PanelProps = $props();
	let m = $derived(data as Marine | null);
	let u = $derived($settings.units);

	// dir renders a compass direction from a bearing in degrees.
	function dir(deg: number): string {
		const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
		return points[Math.round(deg / 45) % 8];
	}
</script>

{#if m?.available}
	<Panel title="Surf and sea">
		<div class="top">
			<div class="wave">{heightValue(m.waveHeightM, u)}<span class="unit">{heightUnit(u)}</span></div>
			<div class="meta">
				<div class="lead">Wave height</div>
				<div class="dim">{dir(m.waveDirectionDeg)} at {m.wavePeriodS.toFixed(0)}s period</div>
			</div>
		</div>
		<div class="row">
			<div class="cell"><span class="k">Swell</span><span class="v">{heightValue(m.swellHeightM, u)} {heightUnit(u)}</span></div>
			<div class="cell"><span class="k">Swell period</span><span class="v">{m.swellPeriodS.toFixed(0)} s</span></div>
			<div class="cell"><span class="k">Direction</span><span class="v">{m.waveDirectionDeg}&deg;</span></div>
		</div>
	</Panel>
{/if}

<style>
	.top {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 14px;
	}
	.wave {
		font-family: var(--serif);
		font-size: 2.8rem;
		line-height: 1;
		color: var(--accent);
	}
	.unit {
		font-size: 1.1rem;
		color: var(--muted);
	}
	.lead {
		font-size: 1rem;
		font-weight: 600;
	}
	.row {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 10px;
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
		font-size: 1rem;
		font-weight: 600;
		font-variant-numeric: tabular-nums;
	}
	.dim {
		color: var(--muted);
		font-size: 0.9rem;
	}
</style>
