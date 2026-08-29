# Fix: executor-full.lua "attempt to call a nil value"

## Root Cause
`buildEnvSetup` in both VM generators hardcodes `loadstring` when initializing the global environment lookup:

**`src/vm/vm-gen.ts` line ~1993**
```typescript
L.push(`local ${n.genv}=loadstring(${dec}(${encS("return (type(getfenv)=='function' and getfenv(0)) or _G")}))()`);
```

**`src/vm/reg-vm-gen.ts` line ~1872**
```typescript
L.push(`local ${n.genv}=loadstring(${dec}(${encS("return (type(getfenv)=='function' and getfenv(0)) or _G")}))()`);
```

**`src/vm/reg-vm-gen.ts` line ~1917 (buildEnvFragments)**
```typescript
fragments.push({ code: `${n.genv}=loadstring(${dec}(${encS("return (type(getfenv)=='function' and getfenv(0)) or _G")}))()`, layer: 1 });
```

In executors that expose `load` but not `loadstring`, or in environments where `loadstring` is unavailable at the time the VM runtime executes, this produces `nil` and the VM crashes on startup.

The `wrapCustomCipher`/`wrapNestedVM`/`wrapStubVM` bootstraps already resolve `loadstring or load` safely, but the inner VM runtime does not.

## Fix

### 1. `src/vm/vm-gen.ts` — `buildEnvSetup`
Replace hardcoded `loadstring` with a runtime fallback pattern:

```typescript
const loadFn = randomName(3);
L.push(`local ${loadFn}=${bRG}(${genv},${encLookup("loadstring")}) or ${bRG}(${genv},${encLookup("load")})`);
L.push(`local ${n.genv}=${loadFn}(${dec}(${encS("return (type(getfenv)=='function' and getfenv(0)) or _G")}))()`);
```

### 2. `src/vm/reg-vm-gen.ts` — `buildEnvSetup`
Same change at line ~1872:

```typescript
const loadFn = randomName(3);
L.push(`local ${loadFn}=${n.bRG}(${n.genv},${encLookup("loadstring")}) or ${n.bRG}(${n.genv},${encLookup("load")})`);
L.push(`local ${n.genv}=${loadFn}(${dec}(${encS("return (type(getfenv)=='function' and getfenv(0)) or _G")}))()`);
```

### 3. `src/vm/reg-vm-gen.ts` — `buildEnvFragments`
Same change at line ~1917:

```typescript
const loadFn = randomName(3);
forwardDecls.push(loadFn, n.genv, n.env);
fragments.push({ code: `${loadFn}=${n.bRG}(${n.genv},${encLookup("loadstring")}) or ${n.bRG}(${n.genv},${encLookup("load")})`, layer: 0 });
fragments.push({ code: `${n.genv}=${loadFn}(${dec}(${encS("return (type(getfenv)=='function' and getfenv(0)) or _G")}))()`, layer: 1 });
```

### 4. `src/vm/vm-gen.ts` — `buildEnvSetup` non-roblox path
The same hardcoded `loadstring` issue exists in the stack VM's `buildEnvSetup` around line 1993. Apply the identical fix there.

## Validation
1. `npm run build`
2. `npm run obfuscate -- samples/samples --vm --max -o samples/executor-fixed.lua`
3. Verify the output loads without `attempt to call a nil value` in the target executor

## Notes
- This is the exact same pattern already used successfully in `wrapCustomCipher`/`wrapNestedVM`/`wrapStubVM` bootstraps.
- No obfuscation strength is lost; only the loader function resolution becomes more robust.
- The `--roblox` path already avoids this because it never uses `loadstring` at all.
