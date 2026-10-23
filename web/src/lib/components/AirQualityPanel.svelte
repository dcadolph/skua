<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { AirQuality } from '$lib/api';
	import Panel from './Panel.svelte';

	let { data, loading }: PanelProps = $props();
	let aq = $derived(data as AirQuality | null);

	// aqiColor maps a US AQI value to its standard category color.
	function aqiColor(aqi: number): string {
		if (aqi <= 50) return '#3FB68B';
		if (aqi <= 100) return '#E0B040';
		if (aqi <= 150) return '#E08640';
		if (aqi <= 200) return '#D65454';
		if (aqi <= 300) return '#9B6DD6';
		return '#8B3A3A';
	}
</script>

<Panel title="Air quality">
	{#if aq}
		<div class="top">
			<div class="aqi" style="color:{aqiColor(aq.usAqi)}">{aq.usAqi}</div>
			<div class="meta">
				<div class="cat">{aq.category}</div>
				<div class="dim">US AQI</div>
			</div>
		</div>
		<div class="pollutants">
			<div class="p"><span class="pk">PM2.5</span><span class="pv">{aq.pm25.toFixed(1)}</span></div>
			<div class="p"><span class="pk">PM10</span><span class="pv">{aq.pm10.toFixed(0)}</span></div>
			<div class="p"><span class="pk">Ozone</span><span class="pv">{aq.ozone.toFixed(0)}</span></div>
			<div class="p"><span class="pk">NO2</span><span class="pv">{aq.no2.toFixed(0)}</span></div>
		</div>
	{:else if loading}
		<p class="dim">Sampling the air...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.top {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 14px;
	}
	.aqi {
		font-family: var(--serif);
		font-size: 3rem;
		line-height: 1;
	}
	.cat {
		font-size: 1.05rem;
		font-weight: 600;
	}
	.pollutants {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr 1fr;
		gap: 10px;
	}
	.p {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.pk {
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--muted);
	}
	.pv {
		font-size: 1rem;
		font-weight: 600;
		font-variant-numeric: tabular-nums;
	}
	.dim {
		color: var(--muted);
	}
</style>
