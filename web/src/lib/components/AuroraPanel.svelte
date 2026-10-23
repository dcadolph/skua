<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Aurora } from '$lib/api';
	import Panel from './Panel.svelte';

	let { data, loading }: PanelProps = $props();
	let a = $derived(data as Aurora | null);
</script>

<Panel title="Aurora">
	{#if a}
		<div class="top">
			<div class="kp" class:active={a.visible}>{a.kp.toFixed(1)}</div>
			<div class="meta">
				<div class="lead">Kp index</div>
				<div class="dim">{a.level}</div>
			</div>
		</div>
		<p class="verdict" class:go={a.visible}>
			{a.visible
				? 'Aurora may be visible tonight at your latitude.'
				: 'Kp is too low for aurora at your latitude right now.'}
		</p>
	{:else if loading}
		<p class="dim">Reading the magnetosphere...</p>
	{:else}
		<p class="dim">No data.</p>
	{/if}
</Panel>

<style>
	.top {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 12px;
	}
	.kp {
		font-family: var(--serif);
		font-size: 3rem;
		line-height: 1;
		color: var(--muted);
	}
	.kp.active {
		color: var(--accent);
	}
	.lead {
		font-size: 1rem;
		font-weight: 600;
	}
	.verdict {
		margin: 0;
		font-size: 0.92rem;
		color: var(--muted);
	}
	.verdict.go {
		color: var(--text);
	}
	.dim {
		color: var(--muted);
	}
</style>
