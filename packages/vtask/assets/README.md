`tasks.schema.json` is generated from Microsoft's VS Code task schema at
revision `351b2610d336c9861fe223bded4214cb95a6eed9` (MIT; see
`VSCODE-LICENSE.txt`). It replaces the older SchemaStore snapshot considered
initially, which omitted inputs and quoted command arguments.

The inputs are:

- `src/vs/workbench/contrib/tasks/common/jsonSchema_v2.ts`
- `src/vs/workbench/contrib/tasks/common/jsonSchemaCommon.ts`
- The `Schemas` namespace of `src/vs/workbench/contrib/tasks/common/problemMatcher.ts`
- `src/vs/workbench/services/configurationResolver/common/configurationResolverSchema.ts`
- `src/vs/base/common/codicons.ts` and `codiconsLibrary.ts`

The snapshot evaluates these schema definitions with English localization,
structured cloning, the built-in codicon list, and empty extension task and
problem-matcher registries. No editor extension host is embedded. Consequently,
it describes built-in shell/process tasks, rather than extension-provided task
types. Deprecated-variable messages affect only editor descriptions.

To reproduce it, check out that VS Code revision and run
`pnpm schema:export /path/to/vscode` from `packages/vtask`. The exporter preserves
TypeScript namespace member exports and rejects undefined values, so missing
definitions cannot silently become `null` in JSON arrays. VS Code currently
mixes `prefixItems` with `additionalItems`; the export converts those tuple
definitions to Draft-07 `items` before Effect performs its dialect conversion.

At runtime, Effect converts Draft-07 to Draft 2020-12 and imports the result into
its own schema decoder. Effect cannot represent typed `additionalProperties`
alongside declared properties: the importer permits those extra keys, while
still validating all declared fields. The typed execution projection validates
the fields vtask uses, including inputs and dependency labels. This is not a
lossless implementation of VS Code's extension-aware validator.

Upstream source:
https://github.com/microsoft/vscode/tree/351b2610d336c9861fe223bded4214cb95a6eed9/src/vs/workbench/contrib/tasks/common
