import { defineWranglerConfig } from "wrangler/experimental-config";

export default defineWranglerConfig((ctx) => {
	switch (ctx.mode) {
		case "preview": {
			return {
				assetsDirectory: "./_build/cloudflare/browser-demo",
			};
		}
		case "production": {
			return {
				assetsDirectory: "./_build/cloudflare/browser-demo",
			};
		}
		default: {
			return {
				assetsDirectory: "./_build/cloudflare/browser-demo",
			};
		}
	}
});
