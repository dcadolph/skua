<script lang="ts">
	import { settings } from '$lib/stores/settings';
	import type { Tier, Units } from '$lib/stores/settings';

	// open controls the popover visibility.
	let open = $state(false);

	// tiers is the ordered plan ladder shown in the popover.
	const tiers: { id: Tier; label: string }[] = [
		{ id: 'free', label: 'Free' },
		{ id: 'plus', label: 'Plus' },
		{ id: 'pro', label: 'Pro' }
	];

	// unitChoices is the measurement systems shown in the popover.
	const unitChoices: { id: Units; label: string }[] = [
		{ id: 'imperial', label: '°F, mph' },
		{ id: 'metric', label: '°C, kph' }
	];

	// setTier switches the active plan.
	function setTier(t: Tier) {
		settings.update((s) => ({ ...s, tier: t }));
	}

	// setUnits switches the measurement system.
	function setUnits(u: Units) {
		settings.update((s) => ({ ...s, units: u }));
	}
</script>

<div class="menu">
	<button type="button" class="trigger" onclick={() => (open = !open)} aria-expanded={open}>
		{tiers.find((t) => t.id === $settings.tier)?.label ?? 'Free'}
	</button>
	{#if open}
		<button type="button" class="backdrop" aria-label="Close settings" onclick={() => (open = false)}
		></button>
		<div class="pop">
			<p class="lbl">Units</p>
			<div class="seg">
				{#each unitChoices as u (u.id)}
					<button
						type="button"
						class:active={$settings.units === u.id}
						onclick={() => setUnits(u.id)}
					>
						{u.label}
					</button>
				{/each}
			</div>
			<p class="lbl gap">Plan</p>
			<div class="seg">
				{#each tiers as t (t.id)}
					<button type="button" class:active={$settings.tier === t.id} onclick={() => setTier(t.id)}>
						{t.label}
					</button>
				{/each}
			</div>
			<p class="hint">Plus and Pro unlock the crude voice levels and premium plugins.</p>
		</div>
	{/if}
</div>

<style>
	.menu {
		position: relative;
	}
	.trigger {
		padding: 6px 12px;
		border-radius: 8px;
		border: 1px solid var(--hair);
		background: transparent;
		color: var(--muted);
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
	}
	.trigger:hover {
		color: var(--text);
		border-color: var(--accent);
	}
	.backdrop {
		position: fixed;
		inset: 0;
		z-index: 40;
		background: transparent;
		border: none;
		cursor: default;
	}
	.pop {
		position: absolute;
		right: 0;
		top: calc(100% + 8px);
		z-index: 50;
		width: 220px;
		padding: 14px;
		border-radius: 12px;
		border: 1px solid var(--hair);
		background: var(--elevated);
		box-shadow: 0 12px 32px rgba(0, 0, 0, 0.28);
	}
	.lbl {
		margin: 0 0 8px;
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--muted);
	}
	.lbl.gap {
		margin-top: 14px;
	}
	.seg {
		display: flex;
		gap: 4px;
	}
	.seg button {
		flex: 1;
		padding: 6px 0;
		border-radius: 8px;
		border: 1px solid var(--hair);
		background: transparent;
		color: var(--muted);
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
	}
	.seg button.active {
		background: var(--accent);
		border-color: var(--accent);
		color: var(--accent-ink);
	}
	.hint {
		margin: 10px 0 0;
		font-size: 0.78rem;
		line-height: 1.4;
		color: var(--muted);
	}
</style>
