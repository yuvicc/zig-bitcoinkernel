//! Zig bindings for `libbitcoinkernel`, the consensus engine of Bitcoin Core
//! (API as of Bitcoin Core v32.0).
//!
//! The kernel API is experimental upstream and may change between releases.
//!
//! ## Ownership
//!
//! Every wrapper type is a thin handle around a kernel pointer. Values
//! returned by `init`, `copy` and functions documented as returning an
//! *owned* value must be released with `deinit`. Values documented as
//! *borrowed* point into their parent, must not be released and are only
//! valid while the parent is alive; call `copy` on them to obtain an owned
//! value.
//!
//! ## Example
//!
//! ```zig
//! const btck = @import("bitcoinkernel");
//!
//! const tx = try btck.Transaction.init(raw_tx_bytes);
//! defer tx.deinit();
//! const spk = btck.ScriptPubkey.init(spent_script);
//! defer spk.deinit();
//! const valid = try spk.verify(amount, tx, null, 0, .{ .p2sh = true, .dersig = true });
//! ```

const std = @import("std");

/// Raw C declarations, mirroring `bitcoinkernel.h` one-to-one.
pub const c = @import("c.zig");

pub const Error = @import("errors.zig").Error;
pub const ScriptVerifyError = @import("errors.zig").ScriptVerifyError;

const types = @import("types.zig");
pub const ChainType = types.ChainType;
pub const SynchronizationState = types.SynchronizationState;
pub const Warning = types.Warning;
pub const ValidationMode = types.ValidationMode;
pub const BlockValidationResult = types.BlockValidationResult;
pub const TxValidationResult = types.TxValidationResult;
pub const LogCategory = types.LogCategory;
pub const LogLevel = types.LogLevel;
pub const LoggingOptions = types.LoggingOptions;
pub const ScriptVerifyStatus = types.ScriptVerifyStatus;
pub const ScriptVerificationFlags = types.ScriptVerificationFlags;
pub const BlockCheckFlags = types.BlockCheckFlags;

const transaction = @import("transaction.zig");
pub const Transaction = transaction.Transaction;
pub const TxValidationState = transaction.TxValidationState;
pub const ScriptPubkey = transaction.ScriptPubkey;
pub const TransactionOutput = transaction.TransactionOutput;
pub const TransactionInput = transaction.TransactionInput;
pub const WitnessStack = transaction.WitnessStack;
pub const TransactionOutPoint = transaction.TransactionOutPoint;
pub const Txid = transaction.Txid;
pub const PrecomputedTransactionData = transaction.PrecomputedTransactionData;

const block = @import("block.zig");
pub const Block = block.Block;
pub const BlockHeader = block.BlockHeader;
pub const BlockHash = block.BlockHash;
pub const BlockValidationState = block.BlockValidationState;
pub const BlockSpentOutputs = block.BlockSpentOutputs;
pub const TransactionSpentOutputs = block.TransactionSpentOutputs;
pub const Coin = block.Coin;

const context = @import("context.zig");
pub const ChainParameters = context.ChainParameters;
pub const ConsensusParams = context.ConsensusParams;
pub const ContextOptions = context.ContextOptions;
pub const Context = context.Context;

const chainstate = @import("chainstate.zig");
pub const ChainstateManagerOptions = chainstate.ChainstateManagerOptions;
pub const ChainstateManager = chainstate.ChainstateManager;
pub const Chain = chainstate.Chain;
pub const BlockTreeEntry = chainstate.BlockTreeEntry;

/// Global logging configuration.
pub const logging = @import("logging.zig");
pub const LoggingConnection = logging.LoggingConnection;

/// Override the current time used by the kernel with a fixed Unix timestamp
/// (for testing). Pass 0 to restore the system clock. Affects all kernel
/// time reads globally.
pub fn setMockTime(timestamp: i64) Error!void {
    if (c.btck_set_mock_time(timestamp) != 0) return error.InvalidMockTime;
}

test {
    std.testing.refAllDecls(@This());
    _ = types;
}
