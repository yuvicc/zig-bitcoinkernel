//! The chainstate manager, its options, the active chain and block tree entries.

const std = @import("std");
const c = @import("c.zig");
const internal = @import("internal.zig");
const errors = @import("errors.zig");
const block = @import("block.zig");
const Context = @import("context.zig").Context;

const Allocator = std.mem.Allocator;
const Error = errors.Error;
const Block = block.Block;
const BlockHash = block.BlockHash;
const BlockHeader = block.BlockHeader;
const BlockSpentOutputs = block.BlockSpentOutputs;
const BlockValidationState = block.BlockValidationState;

/// Options for creating a `ChainstateManager`.
pub const ChainstateManagerOptions = extern struct {
    ptr: *c.btck_ChainstateManagerOptions,

    /// Create owned options. `data_directory` holds the chainstate data and
    /// `blocks_directory` the block data; both are created if they don't
    /// exist. The options, and the chainstate manager created from them,
    /// are associated with `context` for their whole lifetime.
    pub fn init(context: Context, data_directory: []const u8, blocks_directory: []const u8) Error!ChainstateManagerOptions {
        const ptr = c.btck_chainstate_manager_options_create(
            context.ptr,
            data_directory.ptr,
            data_directory.len,
            blocks_directory.ptr,
            blocks_directory.len,
        ) orelse return error.InvalidChainstateManagerOptions;
        return .{ .ptr = ptr };
    }

    pub fn deinit(self: ChainstateManagerOptions) void {
        c.btck_chainstate_manager_options_destroy(self.ptr);
    }

    /// Set the number of worker threads used for parallel script validation.
    /// 0 disables parallel verification; the value is clamped to [0, 15].
    pub fn setWorkerThreads(self: ChainstateManagerOptions, worker_threads: i32) void {
        c.btck_chainstate_manager_options_set_worker_threads_num(self.ptr, worker_threads);
    }

    /// Set the total database cache size in bytes (default 450 MiB). Values
    /// below 4 MiB (and above 1 GiB on 32-bit systems) are rejected.
    pub fn setDatabaseCacheBytes(self: ChainstateManagerOptions, database_cache_bytes: u64) Error!void {
        if (c.btck_chainstate_manager_options_set_database_cache_bytes(self.ptr, database_cache_bytes) != 0)
            return error.InvalidDatabaseCacheSize;
    }

    /// Wipe the block tree and/or chainstate databases. `wipe_block_tree_db`
    /// requires `wipe_chainstate_db`. When a wipe is set,
    /// `ChainstateManager.importBlocks` must be called on the resulting
    /// chainstate manager before using it for anything else.
    pub fn setWipeDbs(self: ChainstateManagerOptions, wipe_block_tree_db: bool, wipe_chainstate_db: bool) Error!void {
        if (c.btck_chainstate_manager_options_set_wipe_dbs(
            self.ptr,
            internal.toCBool(wipe_block_tree_db),
            internal.toCBool(wipe_chainstate_db),
        ) != 0) return error.InvalidWipeOptions;
    }

    /// Keep the block tree database in memory.
    pub fn setBlockTreeDbInMemory(self: ChainstateManagerOptions, in_memory: bool) void {
        c.btck_chainstate_manager_options_update_block_tree_db_in_memory(self.ptr, internal.toCBool(in_memory));
    }

    /// Keep the chainstate database in memory.
    pub fn setChainstateDbInMemory(self: ChainstateManagerOptions, in_memory: bool) void {
        c.btck_chainstate_manager_options_update_chainstate_db_in_memory(self.ptr, internal.toCBool(in_memory));
    }
};

/// The central object for validation and for retrieving data from the chain.
pub const ChainstateManager = extern struct {
    ptr: *c.btck_ChainstateManager,

    /// Create an owned chainstate manager.
    pub fn init(options: ChainstateManagerOptions) Error!ChainstateManager {
        const ptr = c.btck_chainstate_manager_create(options.ptr) orelse
            return error.ChainstateManagerCreationFailed;
        return .{ .ptr = ptr };
    }

    pub fn deinit(self: ChainstateManager) void {
        c.btck_chainstate_manager_destroy(self.ptr);
    }

    /// The block tree entry with the most cumulative proof of work, or null
    /// if no headers have been loaded.
    pub fn bestEntry(self: ChainstateManager) ?BlockTreeEntry {
        const ptr = c.btck_chainstate_manager_get_best_entry(self.ptr) orelse return null;
        return .{ .ptr = ptr };
    }

    /// Process and validate a block header. Returns the owned validation state.
    pub fn processBlockHeader(self: ChainstateManager, header: BlockHeader) Error!BlockValidationState {
        const ptr = c.btck_chainstate_manager_process_block_header(self.ptr, header.ptr) orelse
            return error.ProcessBlockHeaderFailed;
        return .{ .ptr = ptr };
    }

    /// Trigger a reindex if wipe options were set and/or import the given
    /// block files (full filesystem paths). `gpa` is only used for temporary
    /// storage when `block_file_paths` is non-empty.
    pub fn importBlocks(self: ChainstateManager, gpa: Allocator, block_file_paths: []const []const u8) (Error || Allocator.Error)!void {
        if (block_file_paths.len == 0) {
            if (c.btck_chainstate_manager_import_blocks(self.ptr, null, null, 0) != 0)
                return error.ImportBlocksFailed;
            return;
        }
        const data = try gpa.alloc([*]const u8, block_file_paths.len);
        defer gpa.free(data);
        const lens = try gpa.alloc(usize, block_file_paths.len);
        defer gpa.free(lens);
        for (block_file_paths, data, lens) |path, *d, *l| {
            d.* = path.ptr;
            l.* = path.len;
        }
        if (c.btck_chainstate_manager_import_blocks(self.ptr, data.ptr, lens.ptr, block_file_paths.len) != 0)
            return error.ImportBlocksFailed;
    }

    /// Process and validate a block: run checks, save it to disk, validate it
    /// against the UTXO set and extend the chain if it is valid.
    ///
    /// Returns whether the block was new (not processed before). A successful
    /// return does not indicate validity; register a validation interface
    /// `blockChecked` callback to learn the validation result.
    pub fn processBlock(self: ChainstateManager, blk: Block) Error!bool {
        var new_block: c_int = 0;
        if (c.btck_chainstate_manager_process_block(self.ptr, blk.ptr, &new_block) != 0)
            return error.ProcessBlockFailed;
        return new_block == 1;
    }

    /// The currently active best chain. It is a live view whose contents
    /// change as blocks are processed, and it is valid for the lifetime of
    /// the chainstate manager.
    pub fn activeChain(self: ChainstateManager) Chain {
        return .{ .ptr = c.btck_chainstate_manager_get_active_chain(self.ptr).? };
    }

    /// Look up a block tree entry by block hash.
    pub fn blockTreeEntryByHash(self: ChainstateManager, hash: BlockHash) ?BlockTreeEntry {
        const ptr = c.btck_chainstate_manager_get_block_tree_entry_by_hash(self.ptr, hash.ptr) orelse return null;
        return .{ .ptr = ptr };
    }

    /// Read the block of `entry` from disk. Returns an owned block.
    pub fn readBlock(self: ChainstateManager, entry: BlockTreeEntry) Error!Block {
        const ptr = c.btck_block_read(self.ptr, entry.ptr) orelse return error.BlockReadFailed;
        return .{ .ptr = ptr };
    }

    /// Read the spent outputs (undo data) of the block of `entry` from disk.
    /// Returns owned spent outputs.
    pub fn readSpentOutputs(self: ChainstateManager, entry: BlockTreeEntry) Error!BlockSpentOutputs {
        const ptr = c.btck_block_spent_outputs_read(self.ptr, entry.ptr) orelse
            return error.SpentOutputsReadFailed;
        return .{ .ptr = ptr };
    }
};

/// A view on the currently active best chain of a chainstate manager.
pub const Chain = extern struct {
    ptr: *const c.btck_Chain,

    /// Height of the chain tip, or -1 if the chain is empty.
    pub fn height(self: Chain) i32 {
        return c.btck_chain_get_height(self.ptr);
    }

    /// Number of entries (height + 1).
    pub fn countEntries(self: Chain) usize {
        return @intCast(@max(self.height() + 1, 0));
    }

    /// The entry at `block_height`, or null if out of bounds. There is no
    /// guarantee the entry remains in the active chain afterwards.
    pub fn entryAt(self: Chain, block_height: i32) ?BlockTreeEntry {
        const ptr = c.btck_chain_get_by_height(self.ptr, block_height) orelse return null;
        return .{ .ptr = ptr };
    }

    /// The chain tip, or null if the chain is empty.
    pub fn tip(self: Chain) ?BlockTreeEntry {
        return self.entryAt(self.height());
    }

    /// The genesis entry, or null if the chain is empty.
    pub fn genesis(self: Chain) ?BlockTreeEntry {
        return self.entryAt(0);
    }

    pub fn contains(self: Chain, entry: BlockTreeEntry) bool {
        return c.btck_chain_contains(self.ptr, entry.ptr) != 0;
    }

    pub const Iterator = struct {
        chain: Chain,
        next_height: i32 = 0,
        end_height: i32,

        pub fn next(self: *Iterator) ?BlockTreeEntry {
            if (self.next_height > self.end_height) return null;
            defer self.next_height += 1;
            return self.chain.entryAt(self.next_height);
        }
    };

    /// Iterate over the entries from genesis to the current tip. The tip
    /// height is captured when the iterator is created.
    pub fn entries(self: Chain) Iterator {
        return .{ .chain = self, .end_height = self.height() };
    }
};

/// An entry in the block index: a single block and its position in the
/// block tree. Valid for the lifetime of the chainstate manager it came from.
pub const BlockTreeEntry = extern struct {
    ptr: *const c.btck_BlockTreeEntry,

    /// The parent entry, or null for the genesis block.
    pub fn previous(self: BlockTreeEntry) ?BlockTreeEntry {
        const ptr = c.btck_block_tree_entry_get_previous(self.ptr) orelse return null;
        return .{ .ptr = ptr };
    }

    /// The block header of this entry (owned).
    pub fn header(self: BlockTreeEntry) BlockHeader {
        return .{ .ptr = c.btck_block_tree_entry_get_block_header(self.ptr).? };
    }

    pub fn height(self: BlockTreeEntry) i32 {
        return c.btck_block_tree_entry_get_height(self.ptr);
    }

    /// The block hash of this entry (borrowed from the entry).
    pub fn blockHash(self: BlockTreeEntry) BlockHash {
        return .{ .ptr = c.btck_block_tree_entry_get_block_hash(self.ptr).? };
    }

    /// True if both entries point to the same block.
    pub fn eql(self: BlockTreeEntry, other: BlockTreeEntry) bool {
        return c.btck_block_tree_entry_equals(self.ptr, other.ptr) != 0;
    }

    /// The ancestor at `ancestor_height`, which must be in `[0, self.height()]`.
    pub fn ancestor(self: BlockTreeEntry, ancestor_height: i32) BlockTreeEntry {
        std.debug.assert(ancestor_height >= 0 and ancestor_height <= self.height());
        return .{ .ptr = c.btck_block_tree_entry_get_ancestor(self.ptr, ancestor_height).? };
    }
};
