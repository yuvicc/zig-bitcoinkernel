//! Enumerations, flags and plain option structs of the kernel API.

const c = @import("c.zig");

/// The chain a context is configured for.
pub const ChainType = enum(c.btck_ChainType) {
    mainnet = c.btck_ChainType_MAINNET,
    testnet = c.btck_ChainType_TESTNET,
    testnet_4 = c.btck_ChainType_TESTNET_4,
    signet = c.btck_ChainType_SIGNET,
    regtest = c.btck_ChainType_REGTEST,
};

/// Current sync state passed to tip changed callbacks.
pub const SynchronizationState = enum(c.btck_SynchronizationState) {
    init_reindex = c.btck_SynchronizationState_INIT_REINDEX,
    init_download = c.btck_SynchronizationState_INIT_DOWNLOAD,
    post_init = c.btck_SynchronizationState_POST_INIT,
    _,
};

/// Possible warning types issued by validation.
pub const Warning = enum(c.btck_Warning) {
    unknown_new_rules_activated = c.btck_Warning_UNKNOWN_NEW_RULES_ACTIVATED,
    large_work_invalid_chain = c.btck_Warning_LARGE_WORK_INVALID_CHAIN,
    _,
};

/// Whether a validated data structure is valid, invalid, or an error was
/// encountered during processing.
pub const ValidationMode = enum(c.btck_ValidationMode) {
    valid = c.btck_ValidationMode_VALID,
    invalid = c.btck_ValidationMode_INVALID,
    internal_error = c.btck_ValidationMode_INTERNAL_ERROR,
    _,
};

/// A granular "reason" why a block was invalid.
pub const BlockValidationResult = enum(c.btck_BlockValidationResult) {
    /// Initial value. Block has not yet been rejected.
    unset = c.btck_BlockValidationResult_UNSET,
    /// Invalid by consensus rules (excluding any below reasons).
    consensus = c.btck_BlockValidationResult_CONSENSUS,
    /// This block was cached as being invalid and we didn't store the reason why.
    cached_invalid = c.btck_BlockValidationResult_CACHED_INVALID,
    /// Invalid proof of work or time too old.
    invalid_header = c.btck_BlockValidationResult_INVALID_HEADER,
    /// The block's data didn't match the data committed to by the PoW.
    mutated = c.btck_BlockValidationResult_MUTATED,
    /// We don't have the previous block the checked one is built on.
    missing_prev = c.btck_BlockValidationResult_MISSING_PREV,
    /// A block this one builds on is invalid.
    invalid_prev = c.btck_BlockValidationResult_INVALID_PREV,
    /// Block timestamp was > 2 hours in the future (or our clock is bad).
    time_future = c.btck_BlockValidationResult_TIME_FUTURE,
    /// The block header may be on a too-little-work chain.
    header_low_work = c.btck_BlockValidationResult_HEADER_LOW_WORK,
    _,
};

/// The reason why a transaction failed validation. The subset of values
/// reachable depends on which validation function was used.
pub const TxValidationResult = enum(c.btck_TxValidationResult) {
    /// Initial value. Tx has not yet been rejected.
    unset = c.btck_TxValidationResult_UNSET,
    /// Invalid by consensus rules.
    consensus = c.btck_TxValidationResult_CONSENSUS,
    /// Inputs (covered by txid) failed policy rules.
    inputs_not_standard = c.btck_TxValidationResult_INPUTS_NOT_STANDARD,
    /// Otherwise didn't meet local policy rules.
    not_standard = c.btck_TxValidationResult_NOT_STANDARD,
    /// Transaction was missing some of its inputs.
    missing_inputs = c.btck_TxValidationResult_MISSING_INPUTS,
    /// Transaction spends a coinbase too early, or violates locktime/sequence locks.
    premature_spend = c.btck_TxValidationResult_PREMATURE_SPEND,
    /// Witness may have been malleated or is prior to SegWit activation.
    witness_mutated = c.btck_TxValidationResult_WITNESS_MUTATED,
    /// Transaction is missing a witness.
    witness_stripped = c.btck_TxValidationResult_WITNESS_STRIPPED,
    /// Tx already in mempool or conflicts with a tx in the chain.
    conflict = c.btck_TxValidationResult_CONFLICT,
    /// Violated mempool's fee/size/descendant/RBF/etc limits.
    mempool_policy = c.btck_TxValidationResult_MEMPOOL_POLICY,
    /// This node does not have a mempool so can't validate the transaction.
    no_mempool = c.btck_TxValidationResult_NO_MEMPOOL,
    /// Fails some policy, but might be acceptable if submitted in a (different) package.
    reconsiderable = c.btck_TxValidationResult_RECONSIDERABLE,
    /// Transaction was not validated because package failed.
    unknown = c.btck_TxValidationResult_UNKNOWN,
    _,
};

/// Logging categories that may be encountered by kernel code.
pub const LogCategory = enum(c.btck_LogCategory) {
    all = c.btck_LogCategory_ALL,
    bench = c.btck_LogCategory_BENCH,
    blockstorage = c.btck_LogCategory_BLOCKSTORAGE,
    coindb = c.btck_LogCategory_COINDB,
    leveldb = c.btck_LogCategory_LEVELDB,
    mempool = c.btck_LogCategory_MEMPOOL,
    prune = c.btck_LogCategory_PRUNE,
    rand = c.btck_LogCategory_RAND,
    reindex = c.btck_LogCategory_REINDEX,
    validation = c.btck_LogCategory_VALIDATION,
    kernel = c.btck_LogCategory_KERNEL,
};

/// The level at which logs should be produced.
pub const LogLevel = enum(c.btck_LogLevel) {
    trace = c.btck_LogLevel_TRACE,
    debug = c.btck_LogLevel_DEBUG,
    info = c.btck_LogLevel_INFO,
};

/// Options controlling the format of log messages.
pub const LoggingOptions = struct {
    /// Prepend a timestamp to log messages.
    log_timestamps: bool = false,
    /// Log timestamps in microsecond precision.
    log_time_micros: bool = false,
    /// Prepend the name of the thread to log messages.
    log_threadnames: bool = false,
    /// Prepend the source location to log messages.
    log_sourcelocations: bool = false,
    /// Prepend the log category and level to log messages.
    always_print_category_levels: bool = false,

    pub fn toC(self: LoggingOptions) c.btck_LoggingOptions {
        return .{
            .log_timestamps = @intFromBool(self.log_timestamps),
            .log_time_micros = @intFromBool(self.log_time_micros),
            .log_threadnames = @intFromBool(self.log_threadnames),
            .log_sourcelocations = @intFromBool(self.log_sourcelocations),
            .always_print_category_levels = @intFromBool(self.always_print_category_levels),
        };
    }
};

/// Status codes that may be issued by the script verify function.
pub const ScriptVerifyStatus = enum(c.btck_ScriptVerifyStatus) {
    ok = c.btck_ScriptVerifyStatus_OK,
    /// The flags were combined in an invalid way.
    error_invalid_flags_combination = c.btck_ScriptVerifyStatus_ERROR_INVALID_FLAGS_COMBINATION,
    /// The taproot flag was set, so valid spent_outputs have to be provided.
    error_spent_outputs_required = c.btck_ScriptVerifyStatus_ERROR_SPENT_OUTPUTS_REQUIRED,
    _,
};

/// Script verification flags that may be composed with each other.
pub const ScriptVerificationFlags = packed struct(c.btck_ScriptVerificationFlags) {
    /// Evaluate P2SH (BIP16) subscripts.
    p2sh: bool = false,
    _reserved1: u1 = 0,
    /// Enforce strict DER (BIP66) compliance.
    dersig: bool = false,
    _reserved3: u1 = 0,
    /// Enforce NULLDUMMY (BIP147).
    nulldummy: bool = false,
    _reserved5: u4 = 0,
    /// Enable CHECKLOCKTIMEVERIFY (BIP65).
    checklocktimeverify: bool = false,
    /// Enable CHECKSEQUENCEVERIFY (BIP112).
    checksequenceverify: bool = false,
    /// Enable WITNESS (BIP141).
    witness: bool = false,
    _reserved12: u5 = 0,
    /// Enable TAPROOT (BIPs 341 & 342).
    taproot: bool = false,
    _reserved18: u14 = 0,

    pub const none: ScriptVerificationFlags = .{};
    pub const all: ScriptVerificationFlags = .{
        .p2sh = true,
        .dersig = true,
        .nulldummy = true,
        .checklocktimeverify = true,
        .checksequenceverify = true,
        .witness = true,
        .taproot = true,
    };

    pub fn toInt(self: ScriptVerificationFlags) c.btck_ScriptVerificationFlags {
        return @bitCast(self);
    }

    pub fn fromInt(value: c.btck_ScriptVerificationFlags) ScriptVerificationFlags {
        return @bitCast(value);
    }
};

/// Flags controlling the optional context-free block checks.
pub const BlockCheckFlags = packed struct(c.btck_BlockCheckFlags) {
    /// Run CheckProofOfWork via CheckBlockHeader.
    pow: bool = false,
    /// Verify the merkle root (and mutation detection).
    merkle: bool = false,
    _reserved: u30 = 0,

    /// Run the base context-free block checks only.
    pub const base: BlockCheckFlags = .{};
    /// Enable all optional context-free block checks.
    pub const all: BlockCheckFlags = .{ .pow = true, .merkle = true };

    pub fn toInt(self: BlockCheckFlags) c.btck_BlockCheckFlags {
        return @bitCast(self);
    }
};

test "flag constants match the C API" {
    const std = @import("std");
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_ALL, ScriptVerificationFlags.all.toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_NONE, ScriptVerificationFlags.none.toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_P2SH, (ScriptVerificationFlags{ .p2sh = true }).toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_DERSIG, (ScriptVerificationFlags{ .dersig = true }).toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_NULLDUMMY, (ScriptVerificationFlags{ .nulldummy = true }).toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_CHECKLOCKTIMEVERIFY, (ScriptVerificationFlags{ .checklocktimeverify = true }).toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_CHECKSEQUENCEVERIFY, (ScriptVerificationFlags{ .checksequenceverify = true }).toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_WITNESS, (ScriptVerificationFlags{ .witness = true }).toInt());
    try std.testing.expectEqual(c.btck_ScriptVerificationFlags_TAPROOT, (ScriptVerificationFlags{ .taproot = true }).toInt());
    try std.testing.expectEqual(c.btck_BlockCheckFlags_ALL, BlockCheckFlags.all.toInt());
    try std.testing.expectEqual(c.btck_BlockCheckFlags_BASE, BlockCheckFlags.base.toInt());
    try std.testing.expectEqual(c.btck_BlockCheckFlags_POW, (BlockCheckFlags{ .pow = true }).toInt());
    try std.testing.expectEqual(c.btck_BlockCheckFlags_MERKLE, (BlockCheckFlags{ .merkle = true }).toInt());
}
