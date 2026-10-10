import { bindings, defineConfig } from "cf/config";

/**
 * Secret-like files were detected but not read or migrated: examples/browser-demo/.env.opz.example. Only `secrets.required` entries are migrated.
 * @see https://developers.cloudflare.com/workers/configuration/secrets/
 */

/**
 * Wrangler environments are selected through ctx.mode and the cf --mode flag.
 * @see https://developers.cloudflare.com/workers/wrangler/environments/
 */

export default defineConfig((ctx) => {
	switch (ctx.mode) {
		case "preview": {
			return {
				worker: {
					name: "vizprocess-browser-demo-preview",
					compatibilityDate: "2026-05-07",
					entrypoint: "./examples/browser-demo/worker.mjs",
					assets: {
						htmlHandling: "auto-trailing-slash",
						notFoundHandling: "404-page",
					},
					env: {
						ASSETS: bindings.assets(),
					},
				},
			};
		}
		case "production": {
			return {
				worker: {
					name: "vizprocess-browser-demo",
					compatibilityDate: "2026-05-07",
					entrypoint: "./examples/browser-demo/worker.mjs",
					assets: {
						htmlHandling: "auto-trailing-slash",
						notFoundHandling: "404-page",
					},
					domains: [
						"vizprocess.f12o.com",
					],
					env: {
						ASSETS: bindings.assets(),
					},
				},
			};
		}
		default: {
			return {
				worker: {
					name: "vizprocess-browser-demo",
					compatibilityDate: "2026-05-07",
					entrypoint: "./examples/browser-demo/worker.mjs",
					assets: {
						htmlHandling: "auto-trailing-slash",
						notFoundHandling: "404-page",
					},
					env: {
						ASSETS: bindings.assets(),
					},
				},
			};
		}
	}
});
