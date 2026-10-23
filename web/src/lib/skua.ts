import { SkuaClient } from '$lib/api';
import { API_BASE } from '$lib/config';

// skua is the shared backend client instance used across the app.
export const skua = new SkuaClient({ baseUrl: API_BASE });
