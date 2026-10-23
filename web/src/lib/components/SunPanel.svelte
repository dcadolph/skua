<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Forecast } from '$lib/api';
	import Panel from './Panel.svelte';

	let { data, loading }: PanelProps = $props();
	let today = $derived((data as Forecast | null)?.daily?.[0] ?? null);

	// The arc is a quadratic curve from sunrise to sunset; t places the sun by
	// the current time, clamped to the horizon at night.
	const P0 = { x: 24, y: 92 };
	const P1 = { x: 150, y: -26 };
	const P2 = { x: 276, y: 92 };

	let t = $derived.by(() => {
		if (!today) return 0;
		const rise = new Date(today.sunrise).getTime();
		const set = new Date(today.sunset).getTime();
		if (set <= rise) return 0;
		return (Date.now() - rise) / (set - rise);
	});

	let up = $derived(t > 0 && t < 1);

	// sunPoint evaluates the quadratic Bezier at the clamped time fraction.
	let sunPoint = $derived.by(() => {
		const ct = Math.min(1, Math.max(0, t));
		const omt = 1 - ct;
		return {
			x: omt * omt * P0.x + 2 * omt * ct * P1.x + ct * ct * P2.x,
			y: omt * omt * P0.y + 2 * omt * ct * P1.y + ct * ct * P2.y
		};
	});

	function clock(iso: string): string {
		return new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
	}
</script>

<Panel title="Sun">
	{#if today}
		<svg viewBox="0 0 300 104" class="arc" aria-hidden="true">
			<path
				d="M {P0.x} {P0.y} Q {P1.x} {P1.y} {P2.x} {P2.y}"
				fill="none"
				stroke="var(--hair)"
				stroke-width="2"
				stroke-dasharray="3 5"
				stroke-linecap="round"
			/>
			<line x1="8" y1="92" x2="292" y2="92" stroke="var(--hair)" stroke-width="1.5" />
			{#if up}
				<circle cx={sunPoint.x} cy={sunPoint.y} r="10" fill="var(--accent)" opacity="0.25" />
				<circle cx={sunPoint.x} cy={sunPoint.y} r="5.5" fill="var(--accent)" />
			{:else}
				<circle cx={sunPoint.x} cy="92" r="5.5" fill="var(--muted)" opacity="0.7" />
			{/if}
		</svg>
		<div class="times">
			<div class="cell">
				<span class="k">Sunrise</span>
				<span class="v">{clock(today.sunrise)}</span>
			</div>
			{#if !up}
				<span class="down">The sun is down.</span>
			{/if}
			<div class="cell right">
				<span class="k">Sunset</span>
				<span class="v">{clock(today.sunset)}</span>
			</div>
		</div>
	{:else if loading}
		<p class="dim">Loading...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.arc {
		width: 100%;
		height: auto;
		display: block;
	}
	.times {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-top: 8px;
	}
	.cell {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.cell.right {
		text-align: right;
	}
	.k {
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--muted);
	}
	.v {
		font-size: 1.05rem;
		font-weight: 600;
	}
	.down {
		font-size: 0.82rem;
		color: var(--muted);
	}
	.dim {
		color: var(--muted);
	}
</style>
