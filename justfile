set shell := ["bash", "-cu"]

demo_item := "vizprocess-cloudflare-dev"
demo_env_example := "examples/browser-demo/.env.opz.example"
demo_env_file := "examples/browser-demo/.env.opz"

default:
    @just --list

fmt:
    moon fmt

check:
    moon check

build:
    moon build

test:
    moon test

test-js:
    moon build packages/wasm --target js --release
    node --test examples/browser-demo/worker.test.mjs examples/browser-demo/webmcp.test.mjs

clean:
    moon clean

ci: fmt check test test-js

_require-cloudflare-env:
    test -n "${CLOUDFLARE_API_TOKEN:-}" || { echo "CLOUDFLARE_API_TOKEN is required" >&2; exit 1; }
    test -n "${CLOUDFLARE_ACCOUNT_ID:-}" || { echo "CLOUDFLARE_ACCOUNT_ID is required" >&2; exit 1; }

_require-worker-tooling:
    command -v pnpm >/dev/null 2>&1 || { echo "pnpm is required" >&2; exit 1; }
    test -x node_modules/.bin/wrangler || { echo 'Run `pnpm install` to install wrangler' >&2; exit 1; }

_demo-build: _require-worker-tooling
    moon build --target js --release
    pnpm run build:cloudflare-demo-assets

demo-build item=demo_item:
    opz run {{item}} -- just _demo-build

_demo-dev: _demo-build
    pnpm run dev:worker

demo-dev item=demo_item:
    opz run {{item}} -- just _demo-dev

_demo-deploy-app: _require-cloudflare-env _demo-build
    pnpm run deploy:worker

demo-deploy-app item=demo_item:
    opz run {{item}} -- just _demo-deploy-app

_demo-deploy-preview-app: _require-cloudflare-env _demo-build
    pnpm run deploy:preview-worker

demo-deploy-preview-app item=demo_item:
    opz run {{item}} -- just _demo-deploy-preview-app

_demo-deploy: _demo-deploy-app

demo-deploy item=demo_item:
    opz run {{item}} -- just _demo-deploy

_demo-deploy-preview: _demo-deploy-preview-app

demo-deploy-preview item=demo_item:
    opz run {{item}} -- just _demo-deploy-preview

demo-op-create item=demo_item:
    tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT; cp {{demo_env_example}} "$tmpdir/.env"; cd "$tmpdir"; opz create {{item}} .env

demo-op-env item=demo_item:
    rm -f {{demo_env_file}}
    opz gen {{item}} --env-file {{demo_env_file}}
    echo "generated {{demo_env_file}}"
