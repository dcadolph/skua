/// <reference types="vite/client" />

interface ImportMetaEnv {
	readonly VITE_SKUA_API?: string;
}

interface ImportMeta {
	readonly env: ImportMetaEnv;
}
