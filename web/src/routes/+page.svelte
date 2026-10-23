<script lang="ts">
	import { current } from '$lib/stores/locations';
	import { settings } from '$lib/stores/settings';
	import { pluginsForTier } from '$lib/plugins';
	import PluginHost from '$lib/components/PluginHost.svelte';
	import LocationSearch from '$lib/components/LocationSearch.svelte';
	import ThemeToggle from '$lib/components/ThemeToggle.svelte';
	import SettingsMenu from '$lib/components/SettingsMenu.svelte';

	let loc = $derived({ lat: $current.lat, lon: $current.lon });
	let panels = $derived(
		pluginsForTier($settings.tier).filter((p) => !p.relevant || p.relevant(loc))
	);
</script>

<header class="top">
	<div class="brand">
		<img src="/skua-logo.png" alt="Skua" class="logo" />
		<span class="name">Skua</span>
	</div>
	<div class="controls">
		<LocationSearch />
		<ThemeToggle />
		<SettingsMenu />
	</div>
</header>

<main>
	<div class="place">
		<h1>{$current.name}</h1>
	</div>
	<div class="grid">
		{#each panels as plugin (plugin.id)}
			<PluginHost {plugin} {loc} />
		{/each}
	</div>
</main>

<style>
	.top {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		max-width: 1060px;
		margin: 0 auto;
		padding: 20px 24px;
	}
	.brand {
		display: flex;
		align-items: center;
		gap: 10px;
	}
	.logo {
		width: 34px;
		height: 34px;
		border-radius: 8px;
	}
	.name {
		font-family: var(--serif);
		font-size: 1.3rem;
	}
	.controls {
		display: flex;
		align-items: center;
		gap: 10px;
	}
	main {
		max-width: 1060px;
		margin: 0 auto;
		padding: 8px 24px 64px;
	}
	.place {
		margin: 12px 0 20px;
	}
	h1 {
		font-family: var(--serif);
		font-size: clamp(1.8rem, 5vw, 2.6rem);
		margin: 0;
	}
	.grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 16px;
	}
	@media (min-width: 720px) {
		.grid {
			grid-template-columns: 1fr 1fr;
		}
	}
</style>
