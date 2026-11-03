//! Blocks, block headers, block hashes, block validation state and the
//! spent outputs (undo data) of blocks.
//!
//! See `transaction.zig` for the ownership conventions.

const std = @import("std");
const c = @import("c.zig");
const internal = @import("internal.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");
const transaction = @import("transaction.zig");
const ConsensusParams = @import("context.zig").ConsensusParams;

const Allocator = std.mem.Allocator;
const Error = errors.Error;
const Transaction = transaction.Transaction;
const TransactionOutput = transaction.TransactionOutput;

/// A Bitcoin block.
pub const Block = extern struct {
    ptr: *const c.btck_Block,

    /// Parse a block from its consensus serialization. Returns an owned block.
    pub fn init(raw_block: []const u8) Error!Block {
        const ptr = c.btck_block_create(internal.bytesPtr(raw_block), raw_block.len) orelse
            return error.InvalidBlock;
        return .{ .ptr = ptr };
    }

    /// Returns an owned copy. Blocks are reference counted, so this is cheap.
    pub fn copy(self: Block) Block {
        return .{ .ptr = c.btck_block_copy(self.ptr).? };
    }

    pub fn deinit(self: Block) void {
        c.btck_block_destroy(@constCast(self.ptr));
    }

    /// Perform context-free validation checks on the block: size limits,
    /// coinbase structure, transaction checks and sigop limits, plus the
    /// optional proof-of-work and merkle-root checks selected by `flags`.
    /// `state` is overwritten with the result. Returns true if the block
    /// passed the checks.
    pub fn check(
        self: Block,
        consensus_params: ConsensusParams,
        flags: types.BlockCheckFlags,
        state: BlockValidationState,
    ) bool {
        return c.btck_block_check(self.ptr, consensus_params.ptr, flags.toInt(), state.ptr) == 1;
    }

    pub fn countTransactions(self: Block) usize {
        return c.btck_block_count_transactions(self.ptr);
    }

    /// Returns the transaction at `index` (borrowed from the block).
    pub fn transactionAt(self: Block, index: usize) Transaction {
        std.debug.assert(index < self.countTransactions());
        return .{ .ptr = c.btck_block_get_transaction_at(self.ptr, index).? };
    }

    pub const TransactionIterator = internal.IndexIterator(Block, Transaction, transactionAt);

    /// Iterate over the block's (borrowed) transactions.
    pub fn transactions(self: Block) TransactionIterator {
        return .{ .parent = self, .len = self.countTransactions() };
    }

    /// Returns the block's header (owned).
    pub fn header(self: Block) BlockHeader {
        return .{ .ptr = c.btck_block_get_header(self.ptr).? };
    }

    /// Calculates the block's hash (owned).
    pub fn hash(self: Block) BlockHash {
        return .{ .ptr = c.btck_block_get_hash(self.ptr).? };
    }

    /// Consensus-serialize the block. Caller owns the returned memory.
    pub fn toBytes(self: Block, gpa: Allocator) Allocator.Error![]u8 {
        return internal.collectBytes(gpa, c.btck_block_to_bytes, .{self.ptr});
    }

    /// Consensus-serialize the block into `writer`.
    pub fn writeTo(self: Block, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return internal.forwardBytes(writer, c.btck_block_to_bytes, .{self.ptr});
    }
};

/// An 80-byte block header.
pub const BlockHeader = extern struct {
    ptr: *const c.btck_BlockHeader,

    pub const serialized_size = 80;

    /// Parse a block header from its 80-byte serialization. Returns an owned
    /// header, or an error if `raw_header` is not exactly 80 bytes or fails
    /// to decode.
    pub fn init(raw_header: []const u8) Error!BlockHeader {
        // The kernel asserts on any other length.
        if (raw_header.len != serialized_size) return error.InvalidBlockHeader;
        const ptr = c.btck_block_header_create(raw_header.ptr, raw_header.len) orelse
            return error.InvalidBlockHeader;
        return .{ .ptr = ptr };
    }

    pub fn copy(self: BlockHeader) BlockHeader {
        return .{ .ptr = c.btck_block_header_copy(self.ptr).? };
    }

    pub fn deinit(self: BlockHeader) void {
        c.btck_block_header_destroy(@constCast(self.ptr));
    }

    /// Calculates the header's block hash (owned).
    pub fn hash(self: BlockHeader) BlockHash {
        return .{ .ptr = c.btck_block_header_get_hash(self.ptr).? };
    }

    /// The hash of the previous block (borrowed from the header).
    pub fn prevHash(self: BlockHeader) BlockHash {
        return .{ .ptr = c.btck_block_header_get_prev_hash(self.ptr).? };
    }

    /// Block timestamp in Unix epoch seconds.
    pub fn timestamp(self: BlockHeader) u32 {
        return c.btck_block_header_get_timestamp(self.ptr);
    }

    /// The nBits difficulty target in compact format.
    pub fn bits(self: BlockHeader) u32 {
        return c.btck_block_header_get_bits(self.ptr);
    }

    pub fn version(self: BlockHeader) i32 {
        return c.btck_block_header_get_version(self.ptr);
    }

    pub fn nonce(self: BlockHeader) u32 {
        return c.btck_block_header_get_nonce(self.ptr);
    }

    /// The 80-byte consensus serialization of the header.
    pub fn toBytes(self: BlockHeader) Error![serialized_size]u8 {
        var out: [serialized_size]u8 = undefined;
        if (c.btck_block_header_to_bytes(self.ptr, &out) != 0) return error.SerializationFailed;
        return out;
    }
};

/// A block hash.
pub const BlockHash = extern struct {
    ptr: *const c.btck_BlockHash,

    /// Create an owned block hash from its 32 bytes in internal (little-endian) byte order.
    pub fn init(bytes: [32]u8) BlockHash {
        return .{ .ptr = c.btck_block_hash_create(&bytes).? };
    }

    pub fn copy(self: BlockHash) BlockHash {
        return .{ .ptr = c.btck_block_hash_copy(self.ptr).? };
    }

    pub fn deinit(self: BlockHash) void {
        c.btck_block_hash_destroy(@constCast(self.ptr));
    }

    pub fn eql(self: BlockHash, other: BlockHash) bool {
        return c.btck_block_hash_equals(self.ptr, other.ptr) != 0;
    }

    /// The hash bytes in internal (little-endian) byte order.
    pub fn toBytes(self: BlockHash) [32]u8 {
        var out: [32]u8 = undefined;
        c.btck_block_hash_to_bytes(self.ptr, &out);
        return out;
    }

    /// Formats the hash as hex in the conventional (reversed) display order.
    /// Use with the `{f}` format specifier.
    pub fn format(self: BlockHash, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return transaction.writeReversedHex(writer, self.toBytes());
    }
};

/// Holds the result of block validation.
pub const BlockValidationState = extern struct {
    ptr: *c.btck_BlockValidationState,

    /// Returns an owned, empty validation state.
    pub fn init() BlockValidationState {
        return .{ .ptr = c.btck_block_validation_state_create().? };
    }

    pub fn copy(self: BlockValidationState) BlockValidationState {
        return .{ .ptr = c.btck_block_validation_state_copy(self.ptr).? };
    }

    pub fn deinit(self: BlockValidationState) void {
        c.btck_block_validation_state_destroy(self.ptr);
    }

    pub fn validationMode(self: BlockValidationState) types.ValidationMode {
        return @enumFromInt(c.btck_block_validation_state_get_validation_mode(self.ptr));
    }

    pub fn result(self: BlockValidationState) types.BlockValidationResult {
        return @enumFromInt(c.btck_block_validation_state_get_block_validation_result(self.ptr));
    }
};

/// All outputs spent by the transactions of a block, excluding the coinbase.
/// Holds one `TransactionSpentOutputs` per non-coinbase transaction, in block order.
pub const BlockSpentOutputs = extern struct {
    ptr: *const c.btck_BlockSpentOutputs,

    pub fn copy(self: BlockSpentOutputs) BlockSpentOutputs {
        return .{ .ptr = c.btck_block_spent_outputs_copy(self.ptr).? };
    }

    pub fn deinit(self: BlockSpentOutputs) void {
        c.btck_block_spent_outputs_destroy(@constCast(self.ptr));
    }

    pub fn count(self: BlockSpentOutputs) usize {
        return c.btck_block_spent_outputs_count(self.ptr);
    }

    /// The spent outputs of the transaction at `index` (borrowed).
    pub fn transactionSpentOutputsAt(self: BlockSpentOutputs, index: usize) TransactionSpentOutputs {
        std.debug.assert(index < self.count());
        return .{ .ptr = c.btck_block_spent_outputs_get_transaction_spent_outputs_at(self.ptr, index).? };
    }

    pub const Iterator = internal.IndexIterator(BlockSpentOutputs, TransactionSpentOutputs, transactionSpentOutputsAt);

    pub fn iterator(self: BlockSpentOutputs) Iterator {
        return .{ .parent = self, .len = self.count() };
    }
};

/// The coins spent by a single transaction, in the order of its inputs.
pub const TransactionSpentOutputs = extern struct {
    ptr: *const c.btck_TransactionSpentOutputs,

    pub fn copy(self: TransactionSpentOutputs) TransactionSpentOutputs {
        return .{ .ptr = c.btck_transaction_spent_outputs_copy(self.ptr).? };
    }

    pub fn deinit(self: TransactionSpentOutputs) void {
        c.btck_transaction_spent_outputs_destroy(@constCast(self.ptr));
    }

    pub fn count(self: TransactionSpentOutputs) usize {
        return c.btck_transaction_spent_outputs_count(self.ptr);
    }

    /// The coin at `index` (borrowed).
    pub fn coinAt(self: TransactionSpentOutputs, index: usize) Coin {
        std.debug.assert(index < self.count());
        return .{ .ptr = c.btck_transaction_spent_outputs_get_coin_at(self.ptr, index).? };
    }

    pub const Iterator = internal.IndexIterator(TransactionSpentOutputs, Coin, coinAt);

    pub fn iterator(self: TransactionSpentOutputs) Iterator {
        return .{ .parent = self, .len = self.count() };
    }
};

/// A coin: a transaction output together with metadata about its creation.
pub const Coin = extern struct {
    ptr: *const c.btck_Coin,

    pub fn copy(self: Coin) Coin {
        return .{ .ptr = c.btck_coin_copy(self.ptr).? };
    }

    pub fn deinit(self: Coin) void {
        c.btck_coin_destroy(@constCast(self.ptr));
    }

    /// Height of the block that included the transaction creating this coin.
    pub fn confirmationHeight(self: Coin) u32 {
        return c.btck_coin_confirmation_height(self.ptr);
    }

    pub fn isCoinbase(self: Coin) bool {
        return c.btck_coin_is_coinbase(self.ptr) != 0;
    }

    /// The coin's transaction output (borrowed from the coin).
    pub fn output(self: Coin) TransactionOutput {
        return .{ .ptr = c.btck_coin_get_output(self.ptr).? };
    }
};
