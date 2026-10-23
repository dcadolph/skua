// ThemeName identifies a theme. New premium themes add names here.
export type ThemeName = 'storm' | 'overcast';

// ThemeTokens is the set of CSS custom-property values for a theme. A new theme
// is just a new ThemeTokens object.
export interface ThemeTokens {
	ground: string;
	surface: string;
	elevated: string;
	text: string;
	muted: string;
	accent: string;
	accentInk: string;
	hair: string;
}

// themes holds the built-in theme token sets. Storm is the dark default, Overcast
// is the light option.
export const themes: Record<ThemeName, ThemeTokens> = {
	storm: {
		ground: '#06070B',
		surface: '#0E1119',
		elevated: '#161B26',
		text: '#EDF1F8',
		muted: '#8792A6',
		accent: '#FF7F32',
		accentInk: '#180B02',
		hair: 'rgba(202, 204, 210, 0.12)'
	},
	overcast: {
		ground: '#F6F8FC',
		surface: '#FFFFFF',
		elevated: '#FFFFFF',
		text: '#0B0E18',
		muted: '#5A6472',
		accent: '#E4671C',
		accentInk: '#FFFFFF',
		hair: 'rgba(15, 25, 45, 0.10)'
	}
};

// weatherColors is the functional color language shared across every theme.
export const weatherColors = {
	tempCold: '#5EA0FF',
	tempMild: '#47D1A6',
	tempWarm: '#F5A742',
	tempHot: '#FF5D5D',
	clear: '#F5A742',
	clouds: '#8A94AC',
	rain: '#38A9FF',
	snow: '#CFE6FF',
	watch: '#B57BFF',
	warning: '#FF4D6D'
};
