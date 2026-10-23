<script lang="ts">
	import '../app.css';
	import '$lib/theme';
	import { registerCorePlugins } from '$lib/plugins/core';
	import type { Snippet } from 'svelte';

	let { children }: { children: Snippet } = $props();

	registerCorePlugins();
</script>

<svelte:head>
	<title>Skua</title>
	<link rel="icon" href="/skua-logo.png" />
</svelte:head>

{@render children()}
