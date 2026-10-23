<script lang="ts">
	import { geocode, type GeocodeResult } from '$lib/api';
	import { selectLocation } from '$lib/stores/locations';

	let query = $state('');
	let results = $state<GeocodeResult[]>([]);
	let open = $state(false);
	let ctrl: AbortController | null = null;

	async function search() {
		ctrl?.abort();
		ctrl = new AbortController();
		if (query.trim().length < 2) {
			results = [];
			open = false;
			return;
		}
		try {
			results = await geocode(query, ctrl.signal);
			open = results.length > 0;
		} catch {
			// Ignore search errors.
		}
	}

	function pick(r: GeocodeResult) {
		const label = r.admin1 ? `${r.name}, ${r.admin1}` : r.name;
		selectLocation({ name: label, lat: r.lat, lon: r.lon });
		query = '';
		results = [];
		open = false;
	}
</script>

<div class="search">
	<input
		type="text"
		placeholder="Search a place"
		bind:value={query}
		oninput={search}
		onfocus={() => (open = results.length > 0)}
	/>
	{#if open}
		<ul class="results">
			{#each results as r (r.name + r.lat)}
				<li>
					<button onclick={() => pick(r)}>
						{r.name}{#if r.admin1}, {r.admin1}{/if}{#if r.country}
							<span class="dim">{r.country}</span>{/if}
					</button>
				</li>
			{/each}
		</ul>
	{/if}
</div>

<style>
	.search {
		position: relative;
	}
	input {
		width: 220px;
		max-width: 60vw;
		padding: 9px 12px;
		border-radius: 10px;
		border: 1px solid var(--hair);
		background: var(--surface);
		color: var(--text);
		font: inherit;
		outline: none;
	}
	input:focus {
		border-color: var(--accent);
	}
	.results {
		position: absolute;
		top: calc(100% + 6px);
		left: 0;
		right: 0;
		margin: 0;
		padding: 6px;
		list-style: none;
		background: var(--elevated);
		border: 1px solid var(--hair);
		border-radius: 10px;
		z-index: 10;
		box-shadow: 0 20px 50px -24px rgba(0, 0, 0, 0.6);
	}
	button {
		display: block;
		width: 100%;
		text-align: left;
		background: none;
		border: none;
		color: var(--text);
		font: inherit;
		padding: 8px 10px;
		border-radius: 8px;
		cursor: pointer;
	}
	button:hover {
		background: var(--surface);
	}
	.dim {
		color: var(--muted);
	}
</style>
