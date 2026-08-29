# Roblox Executor Compatibility Plan

## Goal
Make obfuscated output run in both standard Roblox LocalScripts AND executor environments (Wave, Volt, Fluxus, Solara, Xeno, etc.) **without losing maximum VM protection**.

## Key Finding from Research

### Executor Landscape 2026
- **Discontinued**: Krnl PC (late 2025), Synapse X (Oct 2023)
- **Active**: Wave, Volt, Potassium, Solara, Xeno, Madium, Synapse Z, Fluxus, Delta, Hydrogen
- Most provide: `loadstring`, `getgenv`, `isreadonly`, `setreadonly`, `debug` table access

### Critical Insight
The obfuscator's **true maximum protection** is in the bytecode transformations + VM interpreter:
- Super operator fusion
- NOP camouflage
- Control flow flattening
- Context-sensitive opcodes
- Non-linear jumps
- String pools + lazy decode
- Obfuscated VM dispatch

The `wrapCustomCipher`, `wrapNestedVM`, `wrapStubVM` wrappers are **optional extra layers** that require `loadstring`. They encrypt the VM source and reload it at runtime.

## Design Decision: Universal Mode

Instead of separate `--roblox` and `--executor` flags, implement a **single universal output** that:
1. Preserves ALL maximum bytecode protections
2. Detects environment at runtime
3. Uses `loadstring`-based wrappers if available (executor)
4. Falls back to native VM execution if not (standard Roblox)

### Why this preserves "maximum VM"
- All `level === "max"` transformations happen BEFORE wrappers
- The VM interpreter itself is fully obfuscated in both paths
- Only the wrapper layer (encrypted reload) is conditional
- Executors get full max protection; standard Roblox gets everything except the loader wrapper

## Implementation Plan

### 1. `src/vm/vm-gen.ts` — Universal wrapper selector
- **Current lines:** 3668–3678
- Replace the simple `if (!robloxCompatible)` checks with a runtime detection pattern:
  ```lua
  local _useWrappers = pcall(function() return loadstring end) or pcall(function() return load end)
  ```
- If `_useWrappers` is true → apply `wrapCustomCipher`, `wrapNestedVM`, `wrapStubVM`
- If false → output the raw protected VM source
- This creates ONE output file that adapts to its environment

### 2. `src/vm/vm-gen.ts` — Executor-aware debug handling
- **Current lines:** 2152–2175
- Replace the safe-copy-only approach with:
  ```lua
  if not isreadonly or not isreadonly(debug) then
    -- Direct modification (executor path)
    debug.getupvalue = nil
    -- etc
  else
    -- Safe copy (standard Roblox path)
    local safeDebug = {}
    for k,v in pairs(debug) do safeDebug[k] = v end
    safeDebug.getupvalue = nil
    debug = safeDebug
  end
  ```
- This works in both environments

### 3. `src/vm/reg-vm-gen.ts` — Add `robloxCompatible` support
- Add `robloxCompatible?: boolean` to `RegVMGenOptions`
- Add `robloxCompatible?: boolean` to `BuildCtx`
- Update `buildEnvSetup` (lines 1844–1893):
  - When `robloxCompatible`: avoid `loadstring(...)` pattern, write `getfenv(0) or _G` directly
  - Create private env with `setmetatable({},{__index=genv})`
  - Copy globals directly, build private writable `debug` table
- Update `buildEnvFragments` (lines 1895–1945): same changes
- Skip `encryptAndEncode` + `generateBootstrap` when `robloxCompatible` (lines 3670–3686)
- Add executor-aware debug handling in max mode

### 4. `src/vm/reg-vm-gen.ts` — Universal wrapper selector
- Same pattern as stack VM: runtime detection of `loadstring`/`load`
- Apply wrappers only when available

### 5. `src/cli/obfuscate.ts` — Keep `--roblox` flag
- Keep existing `--roblox` flag
- When `--roblox` is set, enable universal mode (runtime detection)
- Pass `robloxCompatible: true` to `generateVM`

### 6. `src/cli/reg-vm-obfuscate.ts` — Add `--roblox` flag
- Add `--roblox` / `--roblox-compatible` flags
- Pass `robloxCompatible` to `generateRegVM`

### 7. `src/server.ts` — Add `robloxCompatible` option
- Accept `robloxCompatible` from API request body
- Pass to both `generateVM` and `generateRegVM`

### 8. `README.md` — Document universal mode
- Explain that `--roblox` produces output that works in BOTH standard Roblox and executors
- The output detects its environment at runtime and adapts

## Validation
1. `npm run build` succeeds
2. Generate universal output: `npm run obfuscate -- samples/samples --vm --max --roblox -o samples/universal.lua`
3. Verify output contains runtime detection code
4. Verify output works when `loadstring` is present (executor path)
5. Verify output works when `loadstring` is absent (Roblox path)
6. All max-level bytecode protections are active in both paths

## Risks
- Universal mode output is slightly larger than single-mode output (contains both paths)
- Runtime detection adds a small overhead at startup
- `isreadonly` may not exist in some environments; code must handle nil gracefully
