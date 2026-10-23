import { register } from './registry';
import type { VoiceLevel } from '$lib/api';
import CurrentPanel from '$lib/components/CurrentPanel.svelte';
import HourlyPanel from '$lib/components/HourlyPanel.svelte';
import DailyPanel from '$lib/components/DailyPanel.svelte';
import DetailsPanel from '$lib/components/DetailsPanel.svelte';
import VoicePanel from '$lib/components/VoicePanel.svelte';
import AirQualityPanel from '$lib/components/AirQualityPanel.svelte';
import MarinePanel from '$lib/components/MarinePanel.svelte';
import AuroraPanel from '$lib/components/AuroraPanel.svelte';
import RadarPanel from '$lib/components/RadarPanel.svelte';
import AlertsPanel from '$lib/components/AlertsPanel.svelte';
import SunPanel from '$lib/components/SunPanel.svelte';

// registerCorePlugins registers the built-in dashboard panels. It is idempotent.
// Each plugin declares how it loads its own data, so adding a locale-specific
// plugin later is just another entry here. The voice plugin also watches the
// chosen maturity level and reloads when it changes.
export function registerCorePlugins(): void {
	register(
		{ id: 'alerts', name: 'Alerts', tier: 'free', order: 5, load: (loc, c, s) => c.alerts(loc, s), panel: AlertsPanel },
		{
			id: 'voice',
			name: 'The Voice',
			tier: 'free',
			order: 10,
			load: (loc, c, s, watched) => {
				const [level, units] = String(watched ?? 'proper|metric').split('|');
				return c.voice(loc, level as VoiceLevel, units as 'metric' | 'imperial', s);
			},
			watch: (st) => `${st.voiceLevel}|${st.units}`,
			panel: VoicePanel
		},
		{ id: 'current', name: 'Now', tier: 'free', order: 20, load: (loc, c, s) => c.forecast(loc, s), panel: CurrentPanel },
		{ id: 'hourly', name: 'Hourly', tier: 'free', order: 30, load: (loc, c, s) => c.forecast(loc, s), panel: HourlyPanel },
		{ id: 'radar', name: 'Radar', tier: 'free', order: 40, load: (loc, c, s) => c.radar(s), panel: RadarPanel },
		{ id: 'daily', name: '7-Day', tier: 'free', order: 50, load: (loc, c, s) => c.forecast(loc, s), panel: DailyPanel },
		{ id: 'details', name: 'Details', tier: 'free', order: 60, load: (loc, c, s) => c.forecast(loc, s), panel: DetailsPanel },
		{ id: 'sun', name: 'Sun', tier: 'free', order: 65, load: (loc, c, s) => c.forecast(loc, s), panel: SunPanel },
		{ id: 'airquality', name: 'Air Quality', tier: 'free', order: 70, load: (loc, c, s) => c.airQuality(loc, s), panel: AirQualityPanel },
		{ id: 'marine', name: 'Surf and Sea', tier: 'free', order: 75, load: (loc, c, s) => c.marine(loc, s), panel: MarinePanel },
		{
			id: 'aurora',
			name: 'Aurora',
			tier: 'free',
			order: 80,
			load: (loc, c, s) => c.aurora(loc, s),
			relevant: (loc) => Math.abs(loc.lat) >= 50,
			panel: AuroraPanel
		}
	);
}
