<script lang="ts">
	let {
		condition,
		night = false,
		size = 24
	}: { condition: string; night?: boolean; size?: number } = $props();

	// kindFor maps a condition string to an icon. Keyword order matters: mainly
	// clear must match before clear, and thunder before rain.
	function kindFor(c: string, n: boolean): string {
		const s = c.toLowerCase();
		if (s.includes('thunder')) return 'storm';
		if (s.includes('snow') || s.includes('sleet') || s.includes('ice') || s.includes('freez')) {
			return 'snow';
		}
		if (s.includes('drizzle')) return 'drizzle';
		if (s.includes('rain') || s.includes('shower')) return 'rain';
		if (s.includes('fog') || s.includes('mist')) return 'fog';
		if (s.includes('overcast')) return 'cloud';
		if (s.includes('mainly clear') || s.includes('partly') || s.includes('cloud')) {
			return n ? 'partlyNight' : 'partly';
		}
		if (s.includes('clear') || s.includes('sunny')) return n ? 'moon' : 'sun';
		return 'cloud';
	}

	let kind = $derived(kindFor(condition, night));
</script>

<svg
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="1.6"
	stroke-linecap="round"
	stroke-linejoin="round"
	aria-hidden="true"
>
	{#if kind === 'sun'}
		<circle cx="12" cy="12" r="4" />
		<path
			d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M18.7 5.3l-1.5 1.5M6.8 17.2l-1.5 1.5"
		/>
	{:else if kind === 'moon'}
		<path d="M19.5 13.5A7.5 7.5 0 1 1 10.5 4.5a6 6 0 0 0 9 9Z" />
	{:else if kind === 'partly'}
		<circle cx="7.5" cy="7" r="2.6" />
		<path d="M7.5 2.6v1.3M2.9 7h1.3M4.2 3.7l.9.9M10.8 3.7l-.9.9" />
		<path d="M10 19a3.4 3.4 0 0 1-.5-6.77 4.7 4.7 0 0 1 9.14-.94A3.2 3.2 0 0 1 17.9 19Z" />
	{:else if kind === 'partlyNight'}
		<path d="M9.8 6a3.6 3.6 0 1 1-4.3-3.5A2.9 2.9 0 0 0 9.8 6Z" />
		<path d="M10 19a3.4 3.4 0 0 1-.5-6.77 4.7 4.7 0 0 1 9.14-.94A3.2 3.2 0 0 1 17.9 19Z" />
	{:else if kind === 'cloud'}
		<path d="M7 18a4 4 0 0 1-.6-7.96 5.5 5.5 0 0 1 10.7-1.1A3.75 3.75 0 0 1 16.75 18Z" />
	{:else if kind === 'fog'}
		<path d="M7 15a4 4 0 0 1-.6-7.96 5.5 5.5 0 0 1 10.7-1.1A3.75 3.75 0 0 1 16.75 15Z" />
		<path d="M6 18h12M8 21h9" />
	{:else if kind === 'drizzle'}
		<path d="M7 15a4 4 0 0 1-.6-7.96 5.5 5.5 0 0 1 10.7-1.1A3.75 3.75 0 0 1 16.75 15Z" />
		<path d="M8.4 17.5l-.4 1M12.4 17.5l-.4 1M16.4 17.5l-.4 1M10.4 20.2l-.4 1M14.4 20.2l-.4 1" />
	{:else if kind === 'rain'}
		<path d="M7 15a4 4 0 0 1-.6-7.96 5.5 5.5 0 0 1 10.7-1.1A3.75 3.75 0 0 1 16.75 15Z" />
		<path d="M8.7 17.3 7.8 20M12.7 17.3l-.9 2.7M16.7 17.3l-.9 2.7" />
	{:else if kind === 'snow'}
		<path d="M7 15a4 4 0 0 1-.6-7.96 5.5 5.5 0 0 1 10.7-1.1A3.75 3.75 0 0 1 16.75 15Z" />
		<circle cx="8.5" cy="18.3" r="0.9" fill="currentColor" stroke="none" />
		<circle cx="12.5" cy="20" r="0.9" fill="currentColor" stroke="none" />
		<circle cx="16.5" cy="18.3" r="0.9" fill="currentColor" stroke="none" />
	{:else if kind === 'storm'}
		<path d="M7 15a4 4 0 0 1-.6-7.96 5.5 5.5 0 0 1 10.7-1.1A3.75 3.75 0 0 1 16.75 15Z" />
		<path d="m12.8 15.5-2 3.3h3l-2 3.3" />
	{/if}
</svg>
