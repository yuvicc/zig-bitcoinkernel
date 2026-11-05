# zig-bitcoinkernel

Zig bindings for [`libbitcoinkernel`](https://github.com/bitcoin/bitcoin/blob/v32.0/src/kernel/bitcoinkernel.h),
the consensus engine of Bitcoin Core, targeting the C API shipped with **Bitcoin Core v32.0**.

> The kernel API is experimental upstream and may change in breaking ways between releases.

The package provides two layers:

- `bitcoinkernel.c` — raw `extern` declarations mirroring `bitcoinkernel.h` one-to-one.
  A compile-time test checks them against the header in the Bitcoin Core
  subtree (`depend/bitcoin/src/kernel/bitcoinkernel.h`), so drift is caught by
  `zig build test`.
- An idiomatic wrapper (the package root) with error unions, slices, enums,
  packed-struct flags, iterators and comptime-generated callback trampolines.

## Requirements

- Zig 0.17.0
- `libbitcoinkernel` built from Bitcoin Core v32.0:

```sh
git clone --branch v32.0 https://github.com/bitcoin/bitcoin.git
cd bitcoin
cmake -B build -DBUILD_KERNEL_LIB=ON -DBUILD_SHARED_LIBS=ON
cmake --build build --target bitcoinkernel -j"$(nproc)"
# the library ends up in build/lib/
```

## Building and testing

```sh
zig build test -Dkernel-lib-dir=/path/to/bitcoin/build/lib
zig build run-verify_script -Dkernel-lib-dir=/path/to/bitcoin/build/lib
```

Build options:

| Option | Description |
| --- | --- |
| `-Dkernel-lib-dir=DIR` | Link the library found in `DIR` (and add it to the rpath). The file is linked directly, so other copies on the default search paths cannot shadow it. Without this option the system library paths are searched. |
| `-Dkernel-static=true` | Link `libbitcoinkernel.a` instead of the shared library (also links libc++). Requires a kernel built with `-DBUILD_SHARED_LIBS=OFF`. |

## Using it as a dependency

```sh
zig fetch --save git+https://github.com/<you>/zig-bitcoinkernel
```

```zig
// build.zig
const btck_dep = b.dependency("bitcoinkernel", .{
    .target = target,
    .optimize = optimize,
    .@"kernel-lib-dir" = @as([]const u8, "/path/to/bitcoin/build/lib"),
});
exe.root_module.addImport("bitcoinkernel", btck_dep.module("bitcoinkernel"));
```

## Example

```zig
const std = @import("std");
const btck = @import("bitcoinkernel");

pub fn verifyTaprootInput(raw_tx: []const u8, spent_script: []const u8, amount: i64) !bool {
    const tx = try btck.Transaction.init(raw_tx);
    defer tx.deinit();
    const spk = btck.ScriptPubkey.init(spent_script);
    defer spk.deinit();

    // Taproot signatures commit to all spent outputs.
    const spent = btck.TransactionOutput.init(spk, amount);
    defer spent.deinit();
    const precomputed = try btck.PrecomputedTransactionData.init(tx, &.{spent});
    defer precomputed.deinit();

    return spk.verify(amount, tx, precomputed, 0, .all);
}
```

Validating blocks with a chainstate manager:

```zig
const Events = struct {
    pub fn blockConnected(self: *Events, block: btck.Block, entry: btck.BlockTreeEntry) void {
        _ = self;
        _ = block;
        std.debug.print("connected block at height {d}\n", .{entry.height()});
    }
};

var events: Events = .{};

const options = btck.ContextOptions.init();
defer options.deinit();
const params = btck.ChainParameters.init(.regtest);
defer params.deinit();
options.setChainParams(params);
options.setValidationInterface(&events);

const context = try btck.Context.init(options);
defer context.deinit();

const cm_options = try btck.ChainstateManagerOptions.init(context, "/tmp/regtest", "/tmp/regtest/blocks");
defer cm_options.deinit();
const chainman = try btck.ChainstateManager.init(cm_options);
defer chainman.deinit();

const block = try btck.Block.init(raw_block);
defer block.deinit();
_ = try chainman.processBlock(block);

const chain = chainman.activeChain();
var it = chain.entries();
while (it.next()) |entry| {
    const blk = try chainman.readBlock(entry);
    defer blk.deinit();
    std.debug.print("{d}: {f}\n", .{ entry.height(), entry.blockHash() });
}
```

## API overview

| Kernel object | Zig type | Notes |
| --- | --- | --- |
| `btck_Transaction` | `Transaction` | `init`, `toBytes`, `writeTo`, `inputs()`, `outputs()`, `txid`, `lockTime`, `check` |
| `btck_TransactionInput` / `OutPoint` / `WitnessStack` | `TransactionInput`, `TransactionOutPoint`, `WitnessStack` | `scriptSig`, `sequence`, `itemAt` |
| `btck_TransactionOutput` / `ScriptPubkey` | `TransactionOutput`, `ScriptPubkey` | `ScriptPubkey.verify` |
| `btck_PrecomputedTransactionData` | `PrecomputedTransactionData` | required for taproot |
| `btck_Txid`, `btck_BlockHash` | `Txid`, `BlockHash` | `eql`, `toBytes`, `{f}` formats as display hex |
| `btck_Block`, `btck_BlockHeader` | `Block`, `BlockHeader` | `check` (context-free), `transactions()`, `header`, `hash` |
| `btck_BlockSpentOutputs` / `TransactionSpentOutputs` / `Coin` | same names | undo data |
| `btck_TxValidationState`, `btck_BlockValidationState` | same names | `validationMode`, `result` |
| `btck_ChainParameters`, `btck_ConsensusParams` | same names | `initSignet` for custom challenges |
| `btck_ContextOptions`, `btck_Context` | same names | `setNotifications`, `setValidationInterface`, `interrupt` |
| `btck_ChainstateManagerOptions`, `btck_ChainstateManager` | same names | `processBlock`, `processBlockHeader`, `importBlocks`, `readBlock`, `readSpentOutputs` |
| `btck_Chain`, `btck_BlockTreeEntry` | same names | `entries()`, `tip`, `entryAt`, `ancestor`, `previous` |
| logging | `logging.*`, `LoggingConnection` | handler struct or plain function |
| `btck_set_mock_time` | `setMockTime` | testing helper |

### Ownership

Every wrapper type is a thin handle around a kernel pointer:

- Values returned by `init`, `copy` and functions documented as returning an
  **owned** value must be released with `deinit`.
- **Borrowed** values (e.g. `tx.outputAt(i)`, `block.transactionAt(i)`,
  `tx.txid()`) point into their parent, must not be released, and are only
  valid while the parent is alive. Call `copy()` to keep one around.

### Callbacks

Notification, validation interface and logging callbacks are registered with
a pointer to a handler struct. Only the methods the struct declares are
registered, for example:

```zig
const Handler = struct {
    pub fn blockTip(self: *Handler, state: btck.SynchronizationState, entry: btck.BlockTreeEntry, progress: f64) void { ... }
    pub fn fatalError(self: *Handler, message: []const u8) void { ... }
};
```

The handler must outlive the context (or logging connection) unless it
declares `pub fn destroy(self: *Handler) void`, which the kernel calls when
releasing it. Callbacks may run on kernel threads.

### Errors and preconditions

Fallible kernel calls return `btck.Error` (e.g. `error.InvalidTransaction`,
`error.BlockReadFailed`). Script verification returns `false` for an invalid
script and `btck.ScriptVerifyError` for misuse (invalid flags, missing spent
outputs for taproot). Index arguments are checked with `std.debug.assert`,
mirroring the kernel's own preconditions.

### Notes

- Block files written by Bitcoin Core v28+ are XOR-obfuscated per data
  directory. `ChainstateManager.importBlocks` reads external files without
  de-obfuscation, so it can only import plain block files.
