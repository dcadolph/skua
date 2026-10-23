<script lang="ts">
	import type { PanelProps } from '$lib/plugins';
	import type { Alerts } from '$lib/api';
	import { weatherColors } from '$lib/theme';
	import Panel from './Panel.svelte';

	let { data }: PanelProps = $props();
	let alerts = $derived((data as Alerts | null)?.alerts ?? []);

	// severityColor maps an NWS severity band to the shared color language.
	function severityColor(severity: string): string {
		switch (severity) {
			case 'Extreme':
			case 'Severe':
				return weatherColors.warning;
			case 'Moderate':
				return weatherColors.tempWarm;
			default:
				return 'var(--muted)';
		}
	}

	// until renders an alert end time, empty when the feed gave none.
	function until(iso: string): string {
		const d = new Date(iso);
		if (d.getFullYear() < 2000) return '';
		return `until ${d.toLocaleString([], { weekday: 'short', hour: 'numeric', minute: '2-digit' })}`;
	}
</script>

{#if alerts.length > 0}
	<Panel title="Alerts" wide>
		<div class="list">
			{#each alerts as a (a.event + a.area + a.ends)}
				<details class="alert" style="border-left-color:{severityColor(a.severity)}">
					<summary>
						<span class="head">
							<span class="event" style="color:{severityColor(a.severity)}">{a.event}</span>
							<span class="until">{until(a.ends)}</span>
						</span>
						<span class="area">{a.area}</span>
					</summary>
					<div class="body">
						{#if a.description}<p class="text">{a.description}</p>{/if}
						{#if a.instruction}<p class="text act">{a.instruction}</p>{/if}
					</div>
				</details>
			{/each}
		</div>
	</Panel>
{/if}

<style>
	.list {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.alert {
		border: 1px solid var(--hair);
		border-left: 3px solid;
		border-radius: 10px;
		padding: 10px 14px;
	}
	summary {
		cursor: pointer;
		list-style: none;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	summary::-webkit-details-marker {
		display: none;
	}
	.head {
		display: flex;
		align-items: baseline;
		gap: 10px;
		flex-wrap: wrap;
	}
	.event {
		font-weight: 700;
		font-size: 1rem;
	}
	.until {
		font-size: 0.82rem;
		color: var(--muted);
	}
	.area {
		font-size: 0.85rem;
		color: var(--muted);
	}
	.body {
		margin-top: 10px;
		border-top: 1px solid var(--hair);
		padding-top: 10px;
	}
	.text {
		margin: 0 0 8px;
		font-size: 0.85rem;
		line-height: 1.5;
		color: var(--muted);
		white-space: pre-line;
	}
	.text.act {
		color: var(--text);
		font-weight: 600;
	}
</style>
