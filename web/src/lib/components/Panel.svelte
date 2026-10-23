<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		title,
		accent = false,
		wide = false,
		children
	}: { title?: string; accent?: boolean; wide?: boolean; children: Snippet } = $props();
</script>

<section class="panel" class:accent class:wide>
	{#if title}<h2>{title}</h2>{/if}
	{@render children()}
</section>

<style>
	.panel {
		background: var(--surface);
		border: 1px solid var(--hair);
		border-radius: 18px;
		padding: 20px 22px;
	}
	.panel.wide {
		grid-column: 1 / -1;
	}
	.panel.accent {
		border-color: color-mix(in srgb, var(--accent) 45%, var(--hair));
	}
	h2 {
		font-family: var(--serif);
		font-size: 1.05rem;
		font-weight: 600;
		margin: 0 0 12px;
		color: var(--muted);
		letter-spacing: 0.01em;
	}
</style>
