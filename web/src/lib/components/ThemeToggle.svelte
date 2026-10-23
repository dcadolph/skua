<script lang="ts">
	import { theme, toggleTheme } from '$lib/theme';
</script>

<button class="toggle" onclick={toggleTheme} title="Toggle theme">
	{$theme === 'storm' ? 'Storm' : 'Overcast'}
</button>

<style>
	.toggle {
		background: var(--surface);
		border: 1px solid var(--hair);
		color: var(--muted);
		font: inherit;
		font-size: 0.85rem;
		padding: 8px 14px;
		border-radius: 10px;
		cursor: pointer;
	}
	.toggle:hover {
		color: var(--text);
		border-color: var(--accent);
	}
</style>
