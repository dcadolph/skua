<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Voice } from '$lib/api';
	import Panel from './Panel.svelte';
	import VoiceLevelPicker from './VoiceLevelPicker.svelte';

	let { data, loading }: PanelProps = $props();
	let voice = $derived(data as Voice | null);
</script>

<Panel title="Skua says" accent wide>
	<VoiceLevelPicker />
	{#if voice}
		<p class="line">{voice.line}</p>
		{#if voice.briefing}<p class="brief">{voice.briefing}</p>{/if}
	{:else if loading}
		<p class="dim">The bird is thinking...</p>
	{:else}
		<p class="dim">The bird is speechless right now. Try again in a moment.</p>
	{/if}
</Panel>

<style>
	.line {
		font-family: var(--serif);
		font-size: 1.25rem;
		margin: 0 0 8px;
	}
	.brief {
		color: var(--muted);
		margin: 0;
	}
	.dim {
		color: var(--muted);
		margin: 0;
	}
</style>
