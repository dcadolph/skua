import { writable } from 'svelte/store';
import { themes, type ThemeName } from './tokens';

// storageKey is where the chosen theme is persisted.
const storageKey = 'skua.theme';

// initial reads the saved theme, defaulting to storm.
function initial(): ThemeName {
	if (typeof localStorage !== 'undefined') {
		const v = localStorage.getItem(storageKey);
		if (v === 'storm' || v === 'overcast') return v;
	}
	return 'storm';
}

// kebab converts a camelCase token name to a CSS custom-property name.
function kebab(s: string): string {
	return s.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
}

// theme holds the active theme name.
export const theme = writable<ThemeName>(initial());

// Applying tokens to the document root keeps the CSS variables in sync with the
// active theme, and persists the choice.
theme.subscribe((name) => {
	if (typeof document === 'undefined') return;
	const root = document.documentElement;
	for (const [key, value] of Object.entries(themes[name])) {
		root.style.setProperty(`--${kebab(key)}`, value);
	}
	root.style.setProperty('color-scheme', name === 'storm' ? 'dark' : 'light');
	if (typeof localStorage !== 'undefined') localStorage.setItem(storageKey, name);
});

// toggleTheme flips between storm and overcast.
export function toggleTheme(): void {
	theme.update((n) => (n === 'storm' ? 'overcast' : 'storm'));
}
