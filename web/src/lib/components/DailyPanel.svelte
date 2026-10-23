<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Forecast } from '$lib/api';
	import { tempColor } from '$lib/theme';
	import { settings } from '$lib/stores/settings';
	import { tempValue } from '$lib/units';
	import Panel from './Panel.svelte';
	import ConditionIcon from './ConditionIcon.svelte';

	let { data, loading }: PanelProps = $props();
	let days = $derived(((data as Forecast | null)?.daily ?? []).slice(0, 7));
	let u = $derived($settings.units);

	// The range bars share one scale across the week, so a mild day reads as a
	// short bar and a scorcher stretches wide.
	let weekLow = $derived(Math.min(...days.map((d) => d.lowC)));
	let weekHigh = $derived(Math.max(...days.map((d) => d.highC)));
	let span = $derived(Math.max(1, weekHigh - weekLow));

	function dow(t: string): string {
		return new Date(t).toLocaleDateString([], { weekday: 'short' });
	}
</script>

<Panel title="7-day">
	{#if days.length > 0}
		<div class="list">
			{#each days as d (d.date)}
				<div class="day" title={d.condition}>
					<div class="dow">{dow(d.date)}</div>
					<div class="ico" style="color:{tempColor(d.highC)}">
						<ConditionIcon condition={d.condition} size={18} />
					</div>
					<div class="rain dim" class:wet={d.precipProb >= 30}>{d.precipProb}%</div>
					<div class="lo" style="color:{tempColor(d.lowC)}">{tempValue(d.lowC, u)}&deg;</div>
					<div class="track">
						<div
							class="bar"
							style="left:{((d.lowC - weekLow) / span) * 100}%;width:{Math.max(
								6,
								((d.highC - d.lowC) / span) * 100
							)}%;background:linear-gradient(90deg, {tempColor(d.lowC)}, {tempColor(d.highC)})"
						></div>
					</div>
					<div class="hi" style="color:{tempColor(d.highC)}">{tempValue(d.highC, u)}&deg;</div>
				</div>
			{/each}
		</div>
	{:else if loading}
		<p class="dim">Loading...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.list {
		display: flex;
		flex-direction: column;
	}
	.day {
		display: grid;
		grid-template-columns: 3.5ch 20px 4ch 4ch 1fr 4ch;
		align-items: center;
		gap: 10px;
		padding: 10px 0;
		border-bottom: 1px solid var(--hair);
	}
	.day:last-child {
		border-bottom: none;
	}
	.dow {
		font-weight: 600;
	}
	.ico {
		display: flex;
	}
	.rain {
		font-size: 0.78rem;
		text-align: right;
	}
	.rain.wet {
		color: #38a9ff;
		font-weight: 600;
	}
	.lo,
	.hi {
		font-weight: 600;
		font-size: 0.92rem;
		text-align: right;
		font-variant-numeric: tabular-nums;
	}
	.track {
		position: relative;
		height: 6px;
		border-radius: 3px;
		background: var(--hair);
	}
	.bar {
		position: absolute;
		top: 0;
		bottom: 0;
		border-radius: 3px;
	}
	.dim {
		color: var(--muted);
	}
</style>
