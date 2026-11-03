//! Transactions and their components: inputs, outputs, out points, witness
//! stacks, txids, script pubkeys, precomputed data and validation state.
//!
//! Ownership: values returned by `init`, `copy` and any function documented
//! as returning an *owned* value must be released with `deinit`. Values
//! documented as *borrowed* point into their parent object, must not be
//! released, and are only valid for as long as the parent is alive. A borrowed
//! value can be turned into an owned one with `copy`.

const std = @import("std");
const c = @import("c.zig");
const internal = @import("internal.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");

const Allocator = std.mem.Allocator;
const Error = errors.Error;

/// A Bitcoin transaction.
pub const Transaction = extern struct {
    ptr: *const c.btck_Transaction,

    /// Parse a transaction from its consensus serialization. Returns an owned
    /// transaction.
    pub fn init(raw_transaction: []const u8) Error!Transaction {
        const ptr = c.btck_transaction_create(internal.bytesPtr(raw_transaction), raw_transaction.len) orelse
            return error.InvalidTransaction;
        return .{ .ptr = ptr };
    }

    /// Returns an owned copy. Transactions are reference counted, so this is cheap.
    pub fn copy(self: Transaction) Transaction {
        return .{ .ptr = c.btck_transaction_copy(self.ptr).? };
    }

    pub fn deinit(self: Transaction) void {
        c.btck_transaction_destroy(@constCast(self.ptr));
    }

    /// Consensus-serialize the transaction. Caller owns the returned memory.
    pub fn toBytes(self: Transaction, gpa: Allocator) Allocator.Error![]u8 {
        return internal.collectBytes(gpa, c.btck_transaction_to_bytes, .{self.ptr});
    }

    /// Consensus-serialize the transaction into `writer`.
    pub fn writeTo(self: Transaction, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return internal.forwardBytes(writer, c.btck_transaction_to_bytes, .{self.ptr});
    }

    pub fn countOutputs(self: Transaction) usize {
        return c.btck_transaction_count_outputs(self.ptr);
    }

    /// Returns the output at `index` (borrowed from the transaction).
    pub fn outputAt(self: Transaction, index: usize) TransactionOutput {
        std.debug.assert(index < self.countOutputs());
        return .{ .ptr = c.btck_transaction_get_output_at(self.ptr, index).? };
    }

    pub const OutputIterator = internal.IndexIterator(Transaction, TransactionOutput, outputAt);

    /// Iterate over the transaction's (borrowed) outputs.
    pub fn outputs(self: Transaction) OutputIterator {
        return .{ .parent = self, .len = self.countOutputs() };
    }

    pub fn countInputs(self: Transaction) usize {
        return c.btck_transaction_count_inputs(self.ptr);
    }

    /// Returns the input at `index` (borrowed from the transaction).
    pub fn inputAt(self: Transaction, index: usize) TransactionInput {
        std.debug.assert(index < self.countInputs());
        return .{ .ptr = c.btck_transaction_get_input_at(self.ptr, index).? };
    }

    pub const InputIterator = internal.IndexIterator(Transaction, TransactionInput, inputAt);

    /// Iterate over the transaction's (borrowed) inputs.
    pub fn inputs(self: Transaction) InputIterator {
        return .{ .parent = self, .len = self.countInputs() };
    }

    /// The transaction's nLockTime value.
    pub fn lockTime(self: Transaction) u32 {
        return c.btck_transaction_get_locktime(self.ptr);
    }

    /// The transaction's txid (borrowed from the transaction).
    pub fn txid(self: Transaction) Txid {
        return .{ .ptr = c.btck_transaction_get_txid(self.ptr).? };
    }

    /// Run context-free consensus checks (CheckTransaction) on the
    /// transaction. `state` is overwritten with the result. Returns true if
    /// the transaction is valid.
    pub fn check(self: Transaction, state: TxValidationState) bool {
        return c.btck_transaction_check(self.ptr, state.ptr) == 1;
    }
};

/// Holds the result of transaction validation.
pub const TxValidationState = extern struct {
    ptr: *c.btck_TxValidationState,

    /// Returns an owned, empty validation state.
    pub fn init() TxValidationState {
        return .{ .ptr = c.btck_tx_validation_state_create().? };
    }

    pub fn deinit(self: TxValidationState) void {
        c.btck_tx_validation_state_destroy(self.ptr);
    }

    pub fn validationMode(self: TxValidationState) types.ValidationMode {
        return @enumFromInt(c.btck_tx_validation_state_get_validation_mode(self.ptr));
    }

    pub fn result(self: TxValidationState) types.TxValidationResult {
        return @enumFromInt(c.btck_tx_validation_state_get_tx_validation_result(self.ptr));
    }
};

/// A script pubkey (output script).
pub const ScriptPubkey = extern struct {
    ptr: *const c.btck_ScriptPubkey,

    /// Create an owned script pubkey from its serialized bytes.
    pub fn init(script: []const u8) ScriptPubkey {
        return .{ .ptr = c.btck_script_pubkey_create(internal.bytesPtr(script), script.len).? };
    }

    pub fn copy(self: ScriptPubkey) ScriptPubkey {
        return .{ .ptr = c.btck_script_pubkey_copy(self.ptr).? };
    }

    pub fn deinit(self: ScriptPubkey) void {
        c.btck_script_pubkey_destroy(@constCast(self.ptr));
    }

    /// Serialized script bytes. Caller owns the returned memory.
    pub fn toBytes(self: ScriptPubkey, gpa: Allocator) Allocator.Error![]u8 {
        return internal.collectBytes(gpa, c.btck_script_pubkey_to_bytes, .{self.ptr});
    }

    pub fn writeTo(self: ScriptPubkey, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return internal.forwardBytes(writer, c.btck_script_pubkey_to_bytes, .{self.ptr});
    }

    /// Verify that input `input_index` of `tx_to` correctly spends this script
    /// pubkey under the constraints given by `flags`.
    ///
    /// `amount` is only used if the witness flag is set. If the taproot flag
    /// is set, `precomputed_txdata` must be provided and hold the outputs
    /// spent by `tx_to`.
    ///
    /// Returns true if the script is valid, false if it is invalid, and an
    /// error if the verification could not be performed.
    pub fn verify(
        self: ScriptPubkey,
        amount: i64,
        tx_to: Transaction,
        precomputed_txdata: ?PrecomputedTransactionData,
        input_index: u32,
        flags: types.ScriptVerificationFlags,
    ) errors.ScriptVerifyError!bool {
        std.debug.assert(input_index < tx_to.countInputs());
        // The kernel aborts on flag bits outside of the known set, which can
        // only be set through `ScriptVerificationFlags.fromInt`.
        if (flags.toInt() & ~types.ScriptVerificationFlags.all.toInt() != 0) return error.InvalidFlagsCombination;
        var status: c.btck_ScriptVerifyStatus = c.btck_ScriptVerifyStatus_OK;
        const rc = c.btck_script_pubkey_verify(
            self.ptr,
            amount,
            tx_to.ptr,
            if (precomputed_txdata) |p| p.ptr else null,
            input_index,
            flags.toInt(),
            &status,
        );
        return switch (@as(types.ScriptVerifyStatus, @enumFromInt(status))) {
            .ok => rc == 1,
            .error_invalid_flags_combination => error.InvalidFlagsCombination,
            .error_spent_outputs_required => error.SpentOutputsRequired,
            _ => false,
        };
    }
};

/// A transaction output: a script pubkey and an amount.
pub const TransactionOutput = extern struct {
    ptr: *const c.btck_TransactionOutput,

    /// Create an owned transaction output.
    pub fn init(script_pubkey: ScriptPubkey, amount_sats: i64) TransactionOutput {
        return .{ .ptr = c.btck_transaction_output_create(script_pubkey.ptr, amount_sats).? };
    }

    pub fn copy(self: TransactionOutput) TransactionOutput {
        return .{ .ptr = c.btck_transaction_output_copy(self.ptr).? };
    }

    pub fn deinit(self: TransactionOutput) void {
        c.btck_transaction_output_destroy(@constCast(self.ptr));
    }

    /// The output's script pubkey (borrowed from the output).
    pub fn scriptPubkey(self: TransactionOutput) ScriptPubkey {
        return .{ .ptr = c.btck_transaction_output_get_script_pubkey(self.ptr).? };
    }

    /// The output's amount in satoshis.
    pub fn amount(self: TransactionOutput) i64 {
        return c.btck_transaction_output_get_amount(self.ptr);
    }
};

/// A transaction input.
pub const TransactionInput = extern struct {
    ptr: *const c.btck_TransactionInput,

    pub fn copy(self: TransactionInput) TransactionInput {
        return .{ .ptr = c.btck_transaction_input_copy(self.ptr).? };
    }

    pub fn deinit(self: TransactionInput) void {
        c.btck_transaction_input_destroy(@constCast(self.ptr));
    }

    /// The out point this input spends (borrowed from the input).
    pub fn outPoint(self: TransactionInput) TransactionOutPoint {
        return .{ .ptr = c.btck_transaction_input_get_out_point(self.ptr).? };
    }

    /// The input's nSequence value.
    pub fn sequence(self: TransactionInput) u32 {
        return c.btck_transaction_input_get_sequence(self.ptr);
    }

    /// The input's witness stack (borrowed from the input).
    pub fn witnessStack(self: TransactionInput) WitnessStack {
        return .{ .ptr = c.btck_transaction_input_get_witness_stack(self.ptr).? };
    }

    /// The input's script sig. Caller owns the returned memory.
    pub fn scriptSig(self: TransactionInput, gpa: Allocator) Allocator.Error![]u8 {
        return internal.collectBytes(gpa, c.btck_transaction_input_get_script_sig, .{self.ptr});
    }

    pub fn writeScriptSig(self: TransactionInput, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return internal.forwardBytes(writer, c.btck_transaction_input_get_script_sig, .{self.ptr});
    }
};

/// The witness stack of a transaction input.
pub const WitnessStack = extern struct {
    ptr: *const c.btck_WitnessStack,

    pub fn copy(self: WitnessStack) WitnessStack {
        return .{ .ptr = c.btck_witness_stack_copy(self.ptr).? };
    }

    pub fn deinit(self: WitnessStack) void {
        c.btck_witness_stack_destroy(@constCast(self.ptr));
    }

    pub fn countItems(self: WitnessStack) usize {
        return c.btck_witness_stack_count_items(self.ptr);
    }

    /// The witness item at `index`. Caller owns the returned memory.
    pub fn itemAt(self: WitnessStack, gpa: Allocator, index: usize) Allocator.Error![]u8 {
        std.debug.assert(index < self.countItems());
        return internal.collectBytes(gpa, c.btck_witness_stack_get_item_at, .{ self.ptr, index });
    }

    pub fn writeItemAt(self: WitnessStack, writer: *std.Io.Writer, index: usize) std.Io.Writer.Error!void {
        std.debug.assert(index < self.countItems());
        return internal.forwardBytes(writer, c.btck_witness_stack_get_item_at, .{ self.ptr, index });
    }
};

/// A reference to a specific output of a previous transaction.
pub const TransactionOutPoint = extern struct {
    ptr: *const c.btck_TransactionOutPoint,

    pub fn copy(self: TransactionOutPoint) TransactionOutPoint {
        return .{ .ptr = c.btck_transaction_out_point_copy(self.ptr).? };
    }

    pub fn deinit(self: TransactionOutPoint) void {
        c.btck_transaction_out_point_destroy(@constCast(self.ptr));
    }

    /// The output index within the referenced transaction.
    pub fn index(self: TransactionOutPoint) u32 {
        return c.btck_transaction_out_point_get_index(self.ptr);
    }

    /// The txid of the referenced transaction (borrowed from the out point).
    pub fn txid(self: TransactionOutPoint) Txid {
        return .{ .ptr = c.btck_transaction_out_point_get_txid(self.ptr).? };
    }

    /// True if this is the null out point used by coinbase inputs.
    pub fn isNull(self: TransactionOutPoint) bool {
        if (self.index() != std.math.maxInt(u32)) return false;
        const bytes = self.txid().toBytes();
        return std.mem.allEqual(u8, &bytes, 0);
    }
};

/// A transaction identifier.
pub const Txid = extern struct {
    ptr: *const c.btck_Txid,

    pub fn copy(self: Txid) Txid {
        return .{ .ptr = c.btck_txid_copy(self.ptr).? };
    }

    pub fn deinit(self: Txid) void {
        c.btck_txid_destroy(@constCast(self.ptr));
    }

    pub fn eql(self: Txid, other: Txid) bool {
        return c.btck_txid_equals(self.ptr, other.ptr) != 0;
    }

    /// The txid bytes in internal (little-endian) byte order.
    pub fn toBytes(self: Txid) [32]u8 {
        var out: [32]u8 = undefined;
        c.btck_txid_to_bytes(self.ptr, &out);
        return out;
    }

    /// Formats the txid as hex in the conventional (reversed) display order.
    /// Use with the `{f}` format specifier.
    pub fn format(self: Txid, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        return writeReversedHex(writer, self.toBytes());
    }
};

/// Precomputed transaction data, reusable when verifying multiple inputs of
/// the same transaction. Required when verifying taproot inputs.
pub const PrecomputedTransactionData = extern struct {
    ptr: *const c.btck_PrecomputedTransactionData,

    /// Create owned precomputed data for `tx_to`. `spent_outputs` may be
    /// empty for non-taproot verification; otherwise it must contain exactly
    /// one output per input of `tx_to`, in input order.
    pub fn init(tx_to: Transaction, spent_outputs: []const TransactionOutput) Error!PrecomputedTransactionData {
        std.debug.assert(spent_outputs.len == 0 or spent_outputs.len == tx_to.countInputs());
        // `TransactionOutput` is an extern struct holding a single pointer, so
        // a slice of them has the same layout as an array of C pointers.
        const outputs_ptr: ?[*]const *const c.btck_TransactionOutput =
            if (spent_outputs.len == 0) null else @ptrCast(spent_outputs.ptr);
        const ptr = c.btck_precomputed_transaction_data_create(tx_to.ptr, outputs_ptr, spent_outputs.len) orelse
            return error.PrecomputedTransactionDataCreationFailed;
        return .{ .ptr = ptr };
    }

    pub fn copy(self: PrecomputedTransactionData) PrecomputedTransactionData {
        return .{ .ptr = c.btck_precomputed_transaction_data_copy(self.ptr).? };
    }

    pub fn deinit(self: PrecomputedTransactionData) void {
        c.btck_precomputed_transaction_data_destroy(@constCast(self.ptr));
    }
};

/// Writes 32 bytes as hex in reversed order, the way Bitcoin displays hashes.
pub fn writeReversedHex(writer: *std.Io.Writer, bytes: [32]u8) std.Io.Writer.Error!void {
    var reversed = bytes;
    std.mem.reverse(u8, &reversed);
    const hex = std.fmt.bytesToHex(reversed, .lower);
    try writer.writeAll(&hex);
}

comptime {
    // The slice cast in `PrecomputedTransactionData.init` relies on this.
    std.debug.assert(@sizeOf(TransactionOutput) == @sizeOf(*const c.btck_TransactionOutput));
}
