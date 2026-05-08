export function registerModelContextTools(tools) {
  const modelContext = globalThis.navigator?.modelContext;
  if (!modelContext || tools.length === 0) return () => {};

  const controller = new AbortController();
  for (const tool of tools) {
    modelContext.registerTool(tool, { signal: controller.signal });
  }
  return () => controller.abort();
}

export function runWithUserInteraction(client, action) {
  return new Promise((resolve, reject) => {
    const invoke = () => {
      Promise.resolve()
        .then(action)
        .then(resolve, reject);
    };

    if (typeof client?.requestUserInteraction === "function") {
      client.requestUserInteraction(invoke);
      return;
    }

    invoke();
  });
}
