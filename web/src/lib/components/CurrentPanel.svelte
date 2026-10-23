<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Forecast } from '$lib/api';
	import { tempColor } from '$lib/theme';
	import { settings } from '$lib/stores/settings';
	import { tempValue, speedValue, speedUnit } from '$lib/units';
	import Panel from './Panel.svelte';
	import ConditionIcon from './ConditionIcon.svelte';

	let { data, loading }: PanelProps = $props();
	let fc = $derived(data as Forecast | null);
	let c = $derived(fc?.current ?? null);
	let today = $derived(fc?.daily?.[0] ?? null);
	let u = $derived($settings.units);

	// rain summarizes the fine-grained precipitation outlook: the first wet
	// interval becomes the call, and the intervals become the intensity bars.
	let rain = $derived.by(() => {
		const pts = fc?.minutely ?? [];
		if (pts.length === 0) return null;
		const max = Math.max(...pts.map((p) => p.precipMM));
		const wetIdx = pts.findIndex((p) => p.precipMM >= 0.1);
		if (wetIdx < 0) {
			return { text: 'No rain expected for the next 2 hours.', wet: false, pts, max };
		}
		const mins = Math.max(
			0,
			Math.round((new Date(pts[wetIdx].time).getTime() - Date.now()) / 60000)
		);
		const text = mins <= 1 ? 'Rain falling now.' : `Rain starting in about ${mins} min.`;
		return { text, wet: true, pts, max };
	});
</script>

<Panel wide>
	{#if c}
		<div class="hero">
			<div class="face">
				<div class="ico" style="color:{tempColor(c.tempC)}">
					<ConditionIcon condition={c.condition} night={!c.isDay} size={62} />
				</div>
				<div class="temp" style="color:{tempColor(c.tempC)}">{tempValue(c.tempC, u)}&deg;</div>
				<div class="condcol">
					<div class="cond">{c.condition}</div>
					{#if today}
						<div class="hl">
							<span style="color:{tempColor(today.highC)}">H {tempValue(today.highC, u)}&deg;</span>
							<span style="color:{tempColor(today.lowC)}">L {tempValue(today.lowC, u)}&deg;</span>
						</div>
					{/if}
				</div>
			</div>
			<div class="chips">
				<span class="chip">Feels {tempValue(c.apparentTempC, u)}&deg;</span>
				<span class="chip">Wind {speedValue(c.windKph, u)} {speedUnit(u)}</span>
				<span class="chip">Humidity {c.humidity}%</span>
			</div>
		</div>
		{#if rain}
			<div class="rain" class:wet={rain.wet}>
				{#if rain.wet}
					<div class="bars" aria-hidden="true">
						{#each rain.pts as p (p.time)}
							<div
								class="bar"
								class:on={p.precipMM > 0}
								style="height:{p.precipMM > 0 ? Math.max(18, (p.precipMM / rain.max) * 100) : 8}%"
							></div>
						{/each}
					</div>
				{/if}
				<span class="call">{rain.text}</span>
			</div>
		{/if}
	{:else if loading}
		<p class="dim">Reading the sky...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.hero {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 18px;
		flex-wrap: wrap;
	}
	.face {
		display: flex;
		align-items: center;
		gap: 18px;
	}
	.ico {
		display: flex;
		opacity: 0.9;
	}
	.temp {
		font-family: var(--serif);
		font-size: 4.6rem;
		line-height: 1;
		letter-spacing: -0.02em;
	}
	.cond {
		font-size: 1.2rem;
		font-weight: 600;
	}
	.hl {
		display: flex;
		gap: 12px;
		font-size: 0.95rem;
		font-weight: 600;
		margin-top: 2px;
	}
	.chips {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.chip {
		padding: 6px 12px;
		border: 1px solid var(--hair);
		border-radius: 999px;
		font-size: 0.85rem;
		color: var(--muted);
		white-space: nowrap;
	}
	.rain {
		display: flex;
		align-items: center;
		gap: 10px;
		margin-top: 16px;
		padding-top: 14px;
		border-top: 1px solid var(--hair);
	}
	.rain .call {
		font-size: 0.85rem;
		color: var(--muted);
	}
	.rain.wet .call {
		color: var(--text);
		font-weight: 600;
	}
	.bars {
		display: flex;
		align-items: flex-end;
		gap: 3px;
		height: 22px;
	}
	.bar {
		width: 6px;
		border-radius: 2px;
		background: var(--hair);
	}
	.bar.on {
		background: var(--accent);
	}
	.dim {
		color: var(--muted);
	}
</style>
