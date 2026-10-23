<script lang="ts">
	import type { VoiceLevel } from '$lib/api';
	import { settings, tierAtLeast } from '$lib/stores/settings';
	import { VOICE_LEVELS, voiceLevelMeta } from '$lib/voiceLevels';

	// pending holds a crude level awaiting an 18+ confirmation.
	let pending = $state<VoiceLevel | null>(null);

	// locked reports whether the current tier cannot reach a level.
	function locked(id: VoiceLevel): boolean {
		return !tierAtLeast($settings.tier, voiceLevelMeta(id).minTier);
	}

	// choose selects a level, gating on tier and the one-time adult opt-in.
	function choose(id: VoiceLevel) {
		if (locked(id)) return;
		const m = voiceLevelMeta(id);
		if (m.adult && !$settings.adult) {
			pending = id;
			return;
		}
		settings.update((s) => ({ ...s, voiceLevel: id }));
	}

	// confirmAdult records the 18+ acknowledgment and applies the pending level.
	function confirmAdult() {
		if (!pending) return;
		const id = pending;
		settings.update((s) => ({ ...s, adult: true, voiceLevel: id }));
		pending = null;
	}
</script>

<div class="picker" role="group" aria-label="Voice level">
	{#each VOICE_LEVELS as l (l.id)}
		<button
			type="button"
			class="lvl"
			class:active={$settings.voiceLevel === l.id}
			class:locked={locked(l.id)}
			title={locked(l.id) ? `${l.label} is part of Skua Plus` : l.blurb}
			aria-pressed={$settings.voiceLevel === l.id}
			onclick={() => choose(l.id)}
		>
			<span>{l.label}</span>
			{#if locked(l.id)}<span class="tag">Plus</span>{/if}
		</button>
	{/each}
</div>

{#if pending}
	<div class="gate">
		<p class="gate-text">
			{voiceLevelMeta(pending).label} gets crude and lewd. Confirm you are 18 or older.
		</p>
		<div class="gate-actions">
			<button type="button" class="ok" onclick={confirmAdult}>I'm 18+</button>
			<button type="button" class="no" onclick={() => (pending = null)}>Cancel</button>
		</div>
	</div>
{/if}

<style>
	.picker {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
		margin-bottom: 14px;
	}
	.lvl {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 5px 12px;
		border-radius: 999px;
		border: 1px solid var(--hair);
		background: transparent;
		color: var(--muted);
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition:
			border-color 0.15s,
			color 0.15s,
			background 0.15s;
	}
	.lvl:hover:not(.locked) {
		color: var(--text);
		border-color: var(--accent);
	}
	.lvl.active {
		background: var(--accent);
		border-color: var(--accent);
		color: var(--accent-ink);
	}
	.lvl.locked {
		opacity: 0.55;
		cursor: not-allowed;
	}
	.tag {
		font-size: 0.62rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		padding: 1px 5px;
		border-radius: 4px;
		background: var(--elevated);
		color: var(--accent);
	}
	.lvl.active .tag {
		background: var(--accent-ink);
		color: var(--accent);
	}
	.gate {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		flex-wrap: wrap;
		padding: 10px 12px;
		border: 1px solid var(--hair);
		border-radius: 10px;
		margin-bottom: 14px;
	}
	.gate-text {
		margin: 0;
		font-size: 0.85rem;
		color: var(--muted);
	}
	.gate-actions {
		display: flex;
		gap: 8px;
	}
	.ok,
	.no {
		padding: 5px 12px;
		border-radius: 8px;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		border: 1px solid var(--hair);
	}
	.ok {
		background: var(--accent);
		border-color: var(--accent);
		color: var(--accent-ink);
	}
	.no {
		background: transparent;
		color: var(--muted);
	}
</style>
