# Roblox Compatibility Plan

## Goal
Add a `robloxCompatible` option to the Luau obfuscator so generated output can run in a standard Roblox LocalScript without hitting:
- `attempt to modify a readonly table` (global `debug` table)
- `attempt to call a nil value` (missing `loadstring`/`load`)

## Context
The current maximum VM path in `src/vm/vm-gen.ts`:
- Directly mutates the global `debug` table (lines ~2131–2143).
- Relies on dynamic global resolution via generated loaders in `buildEnvSetup` (lines ~1972–2147).
- Wraps the final output in `wrapCustomCipher`, `wrapNestedVM`, and `wrapStubVM` (lines ~3632–3642), all of which use `loadstring`/`load`.

## Decisions
1. **Safe debug copy** – In `buildEnvSetup`, instead of writing into the readonly global `debug` table, copy it into a new writable table and mutate the copy.
2. **Roblox env mode** – Add a `robloxCompatible` flag to `VMGenOptions`. When true, `buildEnvSetup` uses `getfenv(0)/_G` directly, copies globals into a private environment, and builds a private writable debug table.
3. **Disable loader wrappers in Roblox mode** – When `robloxCompatible` is true, skip `wrapCustomCipher`, `wrapNestedVM`, and `wrapStubVM` because Roblox LocalScripts do not expose `loadstring`/`load`.
4. **CLI flag** – Add `--roblox` / `--roblox-compatible` to `src/cli/obfuscate.ts`.
5. **Forwarding** – Pass `robloxCompatible` through inner VM, outer VM, and fallback VM recursive calls.

## Tasks

### 1. `src/vm/vm-gen.ts` – Safe debug table copy
- **Current lines:** ~2121–2144
- **Change:** Replace direct mutation of `dbV` and `dbEnvV` with a copy-then-mutate pattern:
  ```lua
  local safeDebug = {}
  for key, value in pairs(debug) do
    safeDebug[key] = value
  end
  -- then remove/replace dangerous functions in safeDebug
  ```
- Also replace the `dbEnvV` mutation to use the safe copy instead of the readonly global.

### 2. `src/vm/vm-gen.ts` – Roblox compatibility in `buildEnvSetup`
- **Current signature:** `buildEnvSetup(n, level, includeExecutor)` (line ~1972)
- **Change:** Add parameter `robloxCompatible: boolean = false`.
- When `robloxCompatible` is true:
  - Use `getfenv(0)` or `_G` directly for `genv`.
  - Create a private VM environment table.
  - Copy needed globals into the private environment instead of dynamic runtime resolution.
  - Build a private writable `debug` table (copy of global `debug` with dangerous functions removed).

### 3. `src/vm/vm-gen.ts` – Add option to interface
- **Current line:** ~3339 (`export interface VMGenOptions {`)
- **Change:** Add `robloxCompatible?: boolean;` to the interface.

### 4. `src/vm/vm-gen.ts` – Forward option through nested calls
- **Current lines:** ~3392–3407 (inner VM), ~3418–3424 (outer VM), ~3442–3448 (fallback VM)
- **Change:** Add `robloxCompatible: options.robloxCompatible` to each recursive `generateVM(...)` call.

### 5. `src/vm/vm-gen.ts` – Pass option into env generation
- **Current line:** ~3499
- **Change:** `buildEnvSetup(n, level, includeExecutor, options.robloxCompatible)`

### 6. `src/vm/vm-gen.ts` – Disable loader wrappers in Roblox mode
- **Current lines:** ~3632–3642
- **Change:**
  ```ts
  if (level === "max" && !options.robloxCompatible) {
    output = wrapCustomCipher(output);
  }
  if (level === "max" && !options.robloxCompatible) {
    output = wrapNestedVM(output);
  }
  if (level === "max" && !options.robloxCompatible && !options.noCompression) {
    output = wrapStubVM(output);
  }
  ```

### 7. `src/cli/obfuscate.ts` – Add CLI flag
- **Current line:** ~27 (after `const maxOpt = ...`)
- **Change:** Add `const robloxCompatibleOpt = args.includes("--roblox") || args.includes("--roblox-compatible");`
- **Current line:** ~72
- **Change:** Pass `robloxCompatible: robloxCompatibleOpt` into `generateVM(...)` options.

### 8. `README.md` – Document Roblox usage
- **Current lines:** ~197–203 (CLI Usage section)
- **Change:** Add example:
  ```bash
  npm run obfuscate -- input.lua --vm --max --roblox -o output.lua
  ```
  and note that `--roblox` avoids dynamic-loader wrappers.

## Validation
1. Build: `npm run build`
2. Obfuscate sample with Roblox mode:
   ```bash
   npm run obfuscate -- samples/samples --vm --max --roblox -o samples/roblox-obfuscated.lua
   ```
3. Verify no `readonly table` or `nil value` errors when the output is loaded in a Roblox LocalScript context.
4. Run existing tests if any: `npm test`

## Risks / Notes
- Skipping `wrapCustomCipher` / `wrapNestedVM` / `wrapStubVM` reduces maximum obfuscation layer count for Roblox outputs. This is an intentional compatibility tradeoff.
- The safe debug copy increases output size slightly.
- Roblox may still strip or restrict some globals; the private environment approach mitigates this but does not guarantee all executor-specific globals are available.
