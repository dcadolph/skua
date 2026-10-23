<script lang="ts">
	import type { Plugin } from '$lib/plugins';
	import type { Location } from '$lib/api';
	import { skua } from '$lib/skua';
	import { settings } from '$lib/stores/settings';

	let { plugin, loc }: { plugin: Plugin; loc: Location } = $props();

	let data = $state<unknown>(null);
	let loading = $state(false);
	let error = $state(false);

	let Panel = $derived(plugin.panel);
	// watched is the plugin's settings slice, if any. Reading it here makes the
	// effect reload when it changes; plugins without a watch never touch settings.
	let watched = $derived(plugin.watch ? plugin.watch($settings) : undefined);

	$effect(() => {
		const target = { lat: loc.lat, lon: loc.lon };
		const extra = watched;
		const ctrl = new AbortController();
		data = null;
		loading = true;
		error = false;
		plugin
			.load(target, skua, ctrl.signal, extra)
			.then((d) => {
				data = d;
			})
			.catch(() => {
				if (!ctrl.signal.aborted) error = true;
			})
			.finally(() => {
				if (!ctrl.signal.aborted) loading = false;
			});
		return () => ctrl.abort();
	});
</script>

<Panel {data} {loading} {error} />
