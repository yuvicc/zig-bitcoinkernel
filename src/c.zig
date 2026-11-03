//! Raw declarations for the `libbitcoinkernel` C API, mirroring
//! `src/kernel/bitcoinkernel.h` from Bitcoin Core v32.0 one-to-one.
//!
//! Most users should prefer the idiomatic wrappers exported from the package
//! root. These declarations are kept public for advanced use cases and are
//! checked against the vendored upstream header by `zig build test`.

// ---------------------------------------------------------------------------
// Opaque types
// ---------------------------------------------------------------------------

pub const btck_Transaction = opaque {};
pub const btck_ScriptPubkey = opaque {};
pub const btck_TransactionOutput = opaque {};
pub const btck_LoggingConnection = opaque {};
pub const btck_ChainParameters = opaque {};
pub const btck_ContextOptions = opaque {};
pub const btck_Context = opaque {};
pub const btck_BlockTreeEntry = opaque {};
pub const btck_ChainstateManagerOptions = opaque {};
pub const btck_ChainstateManager = opaque {};
pub const btck_Block = opaque {};
pub const btck_BlockValidationState = opaque {};
pub const btck_ConsensusParams = opaque {};
pub const btck_Chain = opaque {};
pub const btck_TxValidationState = opaque {};
pub const btck_BlockSpentOutputs = opaque {};
pub const btck_TransactionSpentOutputs = opaque {};
pub const btck_Coin = opaque {};
pub const btck_BlockHash = opaque {};
pub const btck_TransactionInput = opaque {};
pub const btck_WitnessStack = opaque {};
pub const btck_TransactionOutPoint = opaque {};
pub const btck_PrecomputedTransactionData = opaque {};
pub const btck_Txid = opaque {};
pub const btck_BlockHeader = opaque {};

// ---------------------------------------------------------------------------
// Enumerations and flags (typedef'd integers in the C header)
// ---------------------------------------------------------------------------

pub const btck_SynchronizationState = u8;
pub const btck_SynchronizationState_INIT_REINDEX: btck_SynchronizationState = 0;
pub const btck_SynchronizationState_INIT_DOWNLOAD: btck_SynchronizationState = 1;
pub const btck_SynchronizationState_POST_INIT: btck_SynchronizationState = 2;

pub const btck_Warning = u8;
pub const btck_Warning_UNKNOWN_NEW_RULES_ACTIVATED: btck_Warning = 0;
pub const btck_Warning_LARGE_WORK_INVALID_CHAIN: btck_Warning = 1;

pub const btck_ValidationMode = u8;
pub const btck_ValidationMode_VALID: btck_ValidationMode = 0;
pub const btck_ValidationMode_INVALID: btck_ValidationMode = 1;
pub const btck_ValidationMode_INTERNAL_ERROR: btck_ValidationMode = 2;

pub const btck_BlockValidationResult = u32;
pub const btck_BlockValidationResult_UNSET: btck_BlockValidationResult = 0;
pub const btck_BlockValidationResult_CONSENSUS: btck_BlockValidationResult = 1;
pub const btck_BlockValidationResult_CACHED_INVALID: btck_BlockValidationResult = 2;
pub const btck_BlockValidationResult_INVALID_HEADER: btck_BlockValidationResult = 3;
pub const btck_BlockValidationResult_MUTATED: btck_BlockValidationResult = 4;
pub const btck_BlockValidationResult_MISSING_PREV: btck_BlockValidationResult = 5;
pub const btck_BlockValidationResult_INVALID_PREV: btck_BlockValidationResult = 6;
pub const btck_BlockValidationResult_TIME_FUTURE: btck_BlockValidationResult = 7;
pub const btck_BlockValidationResult_HEADER_LOW_WORK: btck_BlockValidationResult = 8;

pub const btck_TxValidationResult = u32;
pub const btck_TxValidationResult_UNSET: btck_TxValidationResult = 0;
pub const btck_TxValidationResult_CONSENSUS: btck_TxValidationResult = 1;
pub const btck_TxValidationResult_INPUTS_NOT_STANDARD: btck_TxValidationResult = 2;
pub const btck_TxValidationResult_NOT_STANDARD: btck_TxValidationResult = 3;
pub const btck_TxValidationResult_MISSING_INPUTS: btck_TxValidationResult = 4;
pub const btck_TxValidationResult_PREMATURE_SPEND: btck_TxValidationResult = 5;
pub const btck_TxValidationResult_WITNESS_MUTATED: btck_TxValidationResult = 6;
pub const btck_TxValidationResult_WITNESS_STRIPPED: btck_TxValidationResult = 7;
pub const btck_TxValidationResult_CONFLICT: btck_TxValidationResult = 8;
pub const btck_TxValidationResult_MEMPOOL_POLICY: btck_TxValidationResult = 9;
pub const btck_TxValidationResult_NO_MEMPOOL: btck_TxValidationResult = 10;
pub const btck_TxValidationResult_RECONSIDERABLE: btck_TxValidationResult = 11;
pub const btck_TxValidationResult_UNKNOWN: btck_TxValidationResult = 12;

pub const btck_LogCategory = u8;
pub const btck_LogCategory_ALL: btck_LogCategory = 0;
pub const btck_LogCategory_BENCH: btck_LogCategory = 1;
pub const btck_LogCategory_BLOCKSTORAGE: btck_LogCategory = 2;
pub const btck_LogCategory_COINDB: btck_LogCategory = 3;
pub const btck_LogCategory_LEVELDB: btck_LogCategory = 4;
pub const btck_LogCategory_MEMPOOL: btck_LogCategory = 5;
pub const btck_LogCategory_PRUNE: btck_LogCategory = 6;
pub const btck_LogCategory_RAND: btck_LogCategory = 7;
pub const btck_LogCategory_REINDEX: btck_LogCategory = 8;
pub const btck_LogCategory_VALIDATION: btck_LogCategory = 9;
pub const btck_LogCategory_KERNEL: btck_LogCategory = 10;

pub const btck_LogLevel = u8;
pub const btck_LogLevel_TRACE: btck_LogLevel = 0;
pub const btck_LogLevel_DEBUG: btck_LogLevel = 1;
pub const btck_LogLevel_INFO: btck_LogLevel = 2;

pub const btck_ScriptVerifyStatus = u8;
pub const btck_ScriptVerifyStatus_OK: btck_ScriptVerifyStatus = 0;
pub const btck_ScriptVerifyStatus_ERROR_INVALID_FLAGS_COMBINATION: btck_ScriptVerifyStatus = 1;
pub const btck_ScriptVerifyStatus_ERROR_SPENT_OUTPUTS_REQUIRED: btck_ScriptVerifyStatus = 2;

pub const btck_ScriptVerificationFlags = u32;
pub const btck_ScriptVerificationFlags_NONE: btck_ScriptVerificationFlags = 0;
pub const btck_ScriptVerificationFlags_P2SH: btck_ScriptVerificationFlags = 1 << 0;
pub const btck_ScriptVerificationFlags_DERSIG: btck_ScriptVerificationFlags = 1 << 2;
pub const btck_ScriptVerificationFlags_NULLDUMMY: btck_ScriptVerificationFlags = 1 << 4;
pub const btck_ScriptVerificationFlags_CHECKLOCKTIMEVERIFY: btck_ScriptVerificationFlags = 1 << 9;
pub const btck_ScriptVerificationFlags_CHECKSEQUENCEVERIFY: btck_ScriptVerificationFlags = 1 << 10;
pub const btck_ScriptVerificationFlags_WITNESS: btck_ScriptVerificationFlags = 1 << 11;
pub const btck_ScriptVerificationFlags_TAPROOT: btck_ScriptVerificationFlags = 1 << 17;
pub const btck_ScriptVerificationFlags_ALL: btck_ScriptVerificationFlags =
    btck_ScriptVerificationFlags_P2SH |
    btck_ScriptVerificationFlags_DERSIG |
    btck_ScriptVerificationFlags_NULLDUMMY |
    btck_ScriptVerificationFlags_CHECKLOCKTIMEVERIFY |
    btck_ScriptVerificationFlags_CHECKSEQUENCEVERIFY |
    btck_ScriptVerificationFlags_WITNESS |
    btck_ScriptVerificationFlags_TAPROOT;

pub const btck_ChainType = u8;
pub const btck_ChainType_MAINNET: btck_ChainType = 0;
pub const btck_ChainType_TESTNET: btck_ChainType = 1;
pub const btck_ChainType_TESTNET_4: btck_ChainType = 2;
pub const btck_ChainType_SIGNET: btck_ChainType = 3;
pub const btck_ChainType_REGTEST: btck_ChainType = 4;

pub const btck_BlockCheckFlags = u32;
pub const btck_BlockCheckFlags_BASE: btck_BlockCheckFlags = 0;
pub const btck_BlockCheckFlags_POW: btck_BlockCheckFlags = 1 << 0;
pub const btck_BlockCheckFlags_MERKLE: btck_BlockCheckFlags = 1 << 1;
pub const btck_BlockCheckFlags_ALL: btck_BlockCheckFlags = btck_BlockCheckFlags_POW | btck_BlockCheckFlags_MERKLE;

// ---------------------------------------------------------------------------
// Callback types
// ---------------------------------------------------------------------------

pub const btck_LogCallback = ?*const fn (user_data: ?*anyopaque, message: [*c]const u8, message_len: usize) callconv(.c) void;
pub const btck_DestroyCallback = ?*const fn (user_data: ?*anyopaque) callconv(.c) void;

pub const btck_NotifyBlockTip = ?*const fn (user_data: ?*anyopaque, state: btck_SynchronizationState, entry: ?*const btck_BlockTreeEntry, verification_progress: f64) callconv(.c) void;
pub const btck_NotifyHeaderTip = ?*const fn (user_data: ?*anyopaque, state: btck_SynchronizationState, height: i64, timestamp: i64, presync: c_int) callconv(.c) void;
pub const btck_NotifyProgress = ?*const fn (user_data: ?*anyopaque, title: [*c]const u8, title_len: usize, progress_percent: c_int, resume_possible: c_int) callconv(.c) void;
pub const btck_NotifyWarningSet = ?*const fn (user_data: ?*anyopaque, warning: btck_Warning, message: [*c]const u8, message_len: usize) callconv(.c) void;
pub const btck_NotifyWarningUnset = ?*const fn (user_data: ?*anyopaque, warning: btck_Warning) callconv(.c) void;
pub const btck_NotifyFlushError = ?*const fn (user_data: ?*anyopaque, message: [*c]const u8, message_len: usize) callconv(.c) void;
pub const btck_NotifyFatalError = ?*const fn (user_data: ?*anyopaque, message: [*c]const u8, message_len: usize) callconv(.c) void;

pub const btck_ValidationInterfaceBlockChecked = ?*const fn (user_data: ?*anyopaque, block: ?*btck_Block, state: ?*const btck_BlockValidationState) callconv(.c) void;
pub const btck_ValidationInterfacePoWValidBlock = ?*const fn (user_data: ?*anyopaque, block: ?*btck_Block, entry: ?*const btck_BlockTreeEntry) callconv(.c) void;
pub const btck_ValidationInterfaceBlockConnected = ?*const fn (user_data: ?*anyopaque, block: ?*btck_Block, entry: ?*const btck_BlockTreeEntry) callconv(.c) void;
pub const btck_ValidationInterfaceBlockDisconnected = ?*const fn (user_data: ?*anyopaque, block: ?*btck_Block, entry: ?*const btck_BlockTreeEntry) callconv(.c) void;

pub const btck_WriteBytes = ?*const fn (bytes: ?*const anyopaque, size: usize, userdata: ?*anyopaque) callconv(.c) c_int;

// ---------------------------------------------------------------------------
// Structs
// ---------------------------------------------------------------------------

pub const btck_ValidationInterfaceCallbacks = extern struct {
    user_data: ?*anyopaque = null,
    user_data_destroy: btck_DestroyCallback = null,
    block_checked: btck_ValidationInterfaceBlockChecked = null,
    pow_valid_block: btck_ValidationInterfacePoWValidBlock = null,
    block_connected: btck_ValidationInterfaceBlockConnected = null,
    block_disconnected: btck_ValidationInterfaceBlockDisconnected = null,
};

pub const btck_NotificationInterfaceCallbacks = extern struct {
    user_data: ?*anyopaque = null,
    user_data_destroy: btck_DestroyCallback = null,
    block_tip: btck_NotifyBlockTip = null,
    header_tip: btck_NotifyHeaderTip = null,
    progress: btck_NotifyProgress = null,
    warning_set: btck_NotifyWarningSet = null,
    warning_unset: btck_NotifyWarningUnset = null,
    flush_error: btck_NotifyFlushError = null,
    fatal_error: btck_NotifyFatalError = null,
};

pub const btck_LoggingOptions = extern struct {
    log_timestamps: c_int = 0,
    log_time_micros: c_int = 0,
    log_threadnames: c_int = 0,
    log_sourcelocations: c_int = 0,
    always_print_category_levels: c_int = 0,
};

// ---------------------------------------------------------------------------
// TxValidationState
// ---------------------------------------------------------------------------

pub extern fn btck_tx_validation_state_create() ?*btck_TxValidationState;
pub extern fn btck_tx_validation_state_get_validation_mode(state: *const btck_TxValidationState) btck_ValidationMode;
pub extern fn btck_tx_validation_state_get_tx_validation_result(state: *const btck_TxValidationState) btck_TxValidationResult;
pub extern fn btck_tx_validation_state_destroy(state: ?*btck_TxValidationState) void;

// ---------------------------------------------------------------------------
// Transaction
// ---------------------------------------------------------------------------

pub extern fn btck_transaction_create(raw_transaction: ?*const anyopaque, raw_transaction_len: usize) ?*btck_Transaction;
pub extern fn btck_transaction_copy(transaction: *const btck_Transaction) ?*btck_Transaction;
pub extern fn btck_transaction_to_bytes(transaction: *const btck_Transaction, writer: btck_WriteBytes, user_data: ?*anyopaque) c_int;
pub extern fn btck_transaction_count_outputs(transaction: *const btck_Transaction) usize;
pub extern fn btck_transaction_get_output_at(transaction: *const btck_Transaction, output_index: usize) ?*const btck_TransactionOutput;
pub extern fn btck_transaction_get_input_at(transaction: *const btck_Transaction, input_index: usize) ?*const btck_TransactionInput;
pub extern fn btck_transaction_count_inputs(transaction: *const btck_Transaction) usize;
pub extern fn btck_transaction_get_locktime(transaction: *const btck_Transaction) u32;
pub extern fn btck_transaction_get_txid(transaction: *const btck_Transaction) ?*const btck_Txid;
pub extern fn btck_transaction_check(tx: *const btck_Transaction, validation_state: *btck_TxValidationState) c_int;
pub extern fn btck_transaction_destroy(transaction: ?*btck_Transaction) void;

// ---------------------------------------------------------------------------
// PrecomputedTransactionData
// ---------------------------------------------------------------------------

pub extern fn btck_precomputed_transaction_data_create(
    tx_to: *const btck_Transaction,
    spent_outputs: ?[*]const *const btck_TransactionOutput,
    spent_outputs_len: usize,
) ?*btck_PrecomputedTransactionData;
pub extern fn btck_precomputed_transaction_data_copy(precomputed_txdata: *const btck_PrecomputedTransactionData) ?*btck_PrecomputedTransactionData;
pub extern fn btck_precomputed_transaction_data_destroy(precomputed_txdata: ?*btck_PrecomputedTransactionData) void;

// ---------------------------------------------------------------------------
// ScriptPubkey
// ---------------------------------------------------------------------------

pub extern fn btck_script_pubkey_create(script_pubkey: ?*const anyopaque, script_pubkey_len: usize) ?*btck_ScriptPubkey;
pub extern fn btck_script_pubkey_copy(script_pubkey: *const btck_ScriptPubkey) ?*btck_ScriptPubkey;
pub extern fn btck_script_pubkey_verify(
    script_pubkey: *const btck_ScriptPubkey,
    amount: i64,
    tx_to: *const btck_Transaction,
    precomputed_txdata: ?*const btck_PrecomputedTransactionData,
    input_index: c_uint,
    flags: btck_ScriptVerificationFlags,
    status: ?*btck_ScriptVerifyStatus,
) c_int;
pub extern fn btck_script_pubkey_to_bytes(script_pubkey: *const btck_ScriptPubkey, writer: btck_WriteBytes, user_data: ?*anyopaque) c_int;
pub extern fn btck_script_pubkey_destroy(script_pubkey: ?*btck_ScriptPubkey) void;

// ---------------------------------------------------------------------------
// TransactionOutput
// ---------------------------------------------------------------------------

pub extern fn btck_transaction_output_create(script_pubkey: *const btck_ScriptPubkey, amount: i64) ?*btck_TransactionOutput;
pub extern fn btck_transaction_output_get_script_pubkey(transaction_output: *const btck_TransactionOutput) ?*const btck_ScriptPubkey;
pub extern fn btck_transaction_output_get_amount(transaction_output: *const btck_TransactionOutput) i64;
pub extern fn btck_transaction_output_copy(transaction_output: *const btck_TransactionOutput) ?*btck_TransactionOutput;
pub extern fn btck_transaction_output_destroy(transaction_output: ?*btck_TransactionOutput) void;

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

pub extern fn btck_logging_disable() void;
pub extern fn btck_logging_set_options(options: btck_LoggingOptions) void;
pub extern fn btck_logging_set_level_category(category: btck_LogCategory, level: btck_LogLevel) void;
pub extern fn btck_logging_enable_category(category: btck_LogCategory) void;
pub extern fn btck_logging_disable_category(category: btck_LogCategory) void;
pub extern fn btck_logging_connection_create(
    log_callback: btck_LogCallback,
    user_data: ?*anyopaque,
    user_data_destroy_callback: btck_DestroyCallback,
) ?*btck_LoggingConnection;
pub extern fn btck_logging_connection_destroy(logging_connection: ?*btck_LoggingConnection) void;

// ---------------------------------------------------------------------------
// ChainParameters
// ---------------------------------------------------------------------------

pub extern fn btck_chain_parameters_create(chain_type: btck_ChainType) ?*btck_ChainParameters;
pub extern fn btck_chain_parameters_create_signet(challenge: ?*const anyopaque, challenge_len: usize) ?*btck_ChainParameters;
pub extern fn btck_chain_parameters_copy(chain_parameters: *const btck_ChainParameters) ?*btck_ChainParameters;
pub extern fn btck_chain_parameters_get_consensus_params(chain_parameters: *const btck_ChainParameters) ?*const btck_ConsensusParams;
pub extern fn btck_chain_parameters_destroy(chain_parameters: ?*btck_ChainParameters) void;

// ---------------------------------------------------------------------------
// ContextOptions
// ---------------------------------------------------------------------------

pub extern fn btck_context_options_create() ?*btck_ContextOptions;
pub extern fn btck_context_options_set_chainparams(context_options: *btck_ContextOptions, chain_parameters: *const btck_ChainParameters) void;
pub extern fn btck_context_options_set_notifications(context_options: *btck_ContextOptions, notifications: btck_NotificationInterfaceCallbacks) void;
pub extern fn btck_context_options_set_validation_interface(context_options: *btck_ContextOptions, validation_interface_callbacks: btck_ValidationInterfaceCallbacks) void;
pub extern fn btck_context_options_destroy(context_options: ?*btck_ContextOptions) void;

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------

pub extern fn btck_context_create(context_options: ?*const btck_ContextOptions) ?*btck_Context;
pub extern fn btck_context_copy(context: *const btck_Context) ?*btck_Context;
pub extern fn btck_context_interrupt(context: *btck_Context) c_int;
pub extern fn btck_context_destroy(context: ?*btck_Context) void;

// ---------------------------------------------------------------------------
// BlockTreeEntry
// ---------------------------------------------------------------------------

pub extern fn btck_block_tree_entry_get_previous(block_tree_entry: *const btck_BlockTreeEntry) ?*const btck_BlockTreeEntry;
pub extern fn btck_block_tree_entry_get_block_header(block_tree_entry: *const btck_BlockTreeEntry) ?*btck_BlockHeader;
pub extern fn btck_block_tree_entry_get_height(block_tree_entry: *const btck_BlockTreeEntry) i32;
pub extern fn btck_block_tree_entry_get_block_hash(block_tree_entry: *const btck_BlockTreeEntry) ?*const btck_BlockHash;
pub extern fn btck_block_tree_entry_equals(entry1: *const btck_BlockTreeEntry, entry2: *const btck_BlockTreeEntry) c_int;
pub extern fn btck_block_tree_entry_get_ancestor(block_tree_entry: *const btck_BlockTreeEntry, height: i32) ?*const btck_BlockTreeEntry;

// ---------------------------------------------------------------------------
// ChainstateManagerOptions
// ---------------------------------------------------------------------------

pub extern fn btck_chainstate_manager_options_create(
    context: *const btck_Context,
    data_directory: [*c]const u8,
    data_directory_len: usize,
    blocks_directory: [*c]const u8,
    blocks_directory_len: usize,
) ?*btck_ChainstateManagerOptions;
pub extern fn btck_chainstate_manager_options_set_worker_threads_num(chainstate_manager_options: *btck_ChainstateManagerOptions, worker_threads: c_int) void;
pub extern fn btck_chainstate_manager_options_set_database_cache_bytes(chainstate_manager_options: *btck_ChainstateManagerOptions, database_cache_bytes: u64) c_int;
pub extern fn btck_chainstate_manager_options_set_wipe_dbs(chainstate_manager_options: *btck_ChainstateManagerOptions, wipe_block_tree_db: c_int, wipe_chainstate_db: c_int) c_int;
pub extern fn btck_chainstate_manager_options_update_block_tree_db_in_memory(chainstate_manager_options: *btck_ChainstateManagerOptions, block_tree_db_in_memory: c_int) void;
pub extern fn btck_chainstate_manager_options_update_chainstate_db_in_memory(chainstate_manager_options: *btck_ChainstateManagerOptions, chainstate_db_in_memory: c_int) void;
pub extern fn btck_chainstate_manager_options_destroy(chainstate_manager_options: ?*btck_ChainstateManagerOptions) void;

// ---------------------------------------------------------------------------
// ChainstateManager
// ---------------------------------------------------------------------------

pub extern fn btck_chainstate_manager_create(chainstate_manager_options: *const btck_ChainstateManagerOptions) ?*btck_ChainstateManager;
pub extern fn btck_chainstate_manager_get_best_entry(chainstate_manager: *const btck_ChainstateManager) ?*const btck_BlockTreeEntry;
pub extern fn btck_chainstate_manager_process_block_header(chainstate_manager: *btck_ChainstateManager, header: *const btck_BlockHeader) ?*btck_BlockValidationState;
pub extern fn btck_chainstate_manager_import_blocks(
    chainstate_manager: *btck_ChainstateManager,
    block_file_paths_data: ?[*]const [*]const u8,
    block_file_paths_lens: ?[*]usize,
    block_file_paths_data_len: usize,
) c_int;
pub extern fn btck_chainstate_manager_process_block(chainstate_manager: *btck_ChainstateManager, block: *const btck_Block, new_block: *c_int) c_int;
pub extern fn btck_chainstate_manager_get_active_chain(chainstate_manager: *const btck_ChainstateManager) ?*const btck_Chain;
pub extern fn btck_chainstate_manager_get_block_tree_entry_by_hash(chainstate_manager: *const btck_ChainstateManager, block_hash: *const btck_BlockHash) ?*const btck_BlockTreeEntry;
pub extern fn btck_chainstate_manager_destroy(chainstate_manager: ?*btck_ChainstateManager) void;

// ---------------------------------------------------------------------------
// Block
// ---------------------------------------------------------------------------

pub extern fn btck_block_read(chainstate_manager: *const btck_ChainstateManager, block_tree_entry: *const btck_BlockTreeEntry) ?*btck_Block;
pub extern fn btck_block_create(raw_block: ?*const anyopaque, raw_block_len: usize) ?*btck_Block;
pub extern fn btck_block_copy(block: *const btck_Block) ?*btck_Block;
pub extern fn btck_block_check(block: *const btck_Block, consensus_params: *const btck_ConsensusParams, flags: btck_BlockCheckFlags, validation_state: *btck_BlockValidationState) c_int;
pub extern fn btck_block_count_transactions(block: *const btck_Block) usize;
pub extern fn btck_block_get_transaction_at(block: *const btck_Block, transaction_index: usize) ?*const btck_Transaction;
pub extern fn btck_block_get_header(block: *const btck_Block) ?*btck_BlockHeader;
pub extern fn btck_block_get_hash(block: *const btck_Block) ?*btck_BlockHash;
pub extern fn btck_block_to_bytes(block: *const btck_Block, writer: btck_WriteBytes, user_data: ?*anyopaque) c_int;
pub extern fn btck_block_destroy(block: ?*btck_Block) void;

// ---------------------------------------------------------------------------
// BlockValidationState
// ---------------------------------------------------------------------------

pub extern fn btck_block_validation_state_create() ?*btck_BlockValidationState;
pub extern fn btck_block_validation_state_get_validation_mode(block_validation_state: *const btck_BlockValidationState) btck_ValidationMode;
pub extern fn btck_block_validation_state_get_block_validation_result(block_validation_state: *const btck_BlockValidationState) btck_BlockValidationResult;
pub extern fn btck_block_validation_state_copy(block_validation_state: *const btck_BlockValidationState) ?*btck_BlockValidationState;
pub extern fn btck_block_validation_state_destroy(block_validation_state: ?*btck_BlockValidationState) void;

// ---------------------------------------------------------------------------
// Chain
// ---------------------------------------------------------------------------

pub extern fn btck_chain_get_height(chain: *const btck_Chain) i32;
pub extern fn btck_chain_get_by_height(chain: *const btck_Chain, block_height: i32) ?*const btck_BlockTreeEntry;
pub extern fn btck_chain_contains(chain: *const btck_Chain, block_tree_entry: *const btck_BlockTreeEntry) c_int;

// ---------------------------------------------------------------------------
// BlockSpentOutputs
// ---------------------------------------------------------------------------

pub extern fn btck_block_spent_outputs_read(chainstate_manager: *const btck_ChainstateManager, block_tree_entry: *const btck_BlockTreeEntry) ?*btck_BlockSpentOutputs;
pub extern fn btck_block_spent_outputs_copy(block_spent_outputs: *const btck_BlockSpentOutputs) ?*btck_BlockSpentOutputs;
pub extern fn btck_block_spent_outputs_count(block_spent_outputs: *const btck_BlockSpentOutputs) usize;
pub extern fn btck_block_spent_outputs_get_transaction_spent_outputs_at(block_spent_outputs: *const btck_BlockSpentOutputs, transaction_spent_outputs_index: usize) ?*const btck_TransactionSpentOutputs;
pub extern fn btck_block_spent_outputs_destroy(block_spent_outputs: ?*btck_BlockSpentOutputs) void;

// ---------------------------------------------------------------------------
// TransactionSpentOutputs
// ---------------------------------------------------------------------------

pub extern fn btck_transaction_spent_outputs_copy(transaction_spent_outputs: *const btck_TransactionSpentOutputs) ?*btck_TransactionSpentOutputs;
pub extern fn btck_transaction_spent_outputs_count(transaction_spent_outputs: *const btck_TransactionSpentOutputs) usize;
pub extern fn btck_transaction_spent_outputs_get_coin_at(transaction_spent_outputs: *const btck_TransactionSpentOutputs, coin_index: usize) ?*const btck_Coin;
pub extern fn btck_transaction_spent_outputs_destroy(transaction_spent_outputs: ?*btck_TransactionSpentOutputs) void;

// ---------------------------------------------------------------------------
// TransactionInput
// ---------------------------------------------------------------------------

pub extern fn btck_transaction_input_copy(transaction_input: *const btck_TransactionInput) ?*btck_TransactionInput;
pub extern fn btck_transaction_input_get_out_point(transaction_input: *const btck_TransactionInput) ?*const btck_TransactionOutPoint;
pub extern fn btck_transaction_input_get_sequence(transaction_input: *const btck_TransactionInput) u32;
pub extern fn btck_transaction_input_get_witness_stack(transaction_input: *const btck_TransactionInput) ?*const btck_WitnessStack;
pub extern fn btck_transaction_input_get_script_sig(transaction_input: *const btck_TransactionInput, writer: btck_WriteBytes, user_data: ?*anyopaque) c_int;
pub extern fn btck_transaction_input_destroy(transaction_input: ?*btck_TransactionInput) void;

// ---------------------------------------------------------------------------
// WitnessStack
// ---------------------------------------------------------------------------

pub extern fn btck_witness_stack_count_items(witness_stack: *const btck_WitnessStack) usize;
pub extern fn btck_witness_stack_get_item_at(witness_stack: *const btck_WitnessStack, index: usize, writer: btck_WriteBytes, user_data: ?*anyopaque) c_int;
pub extern fn btck_witness_stack_copy(witness_stack: *const btck_WitnessStack) ?*btck_WitnessStack;
pub extern fn btck_witness_stack_destroy(witness_stack: ?*btck_WitnessStack) void;

// ---------------------------------------------------------------------------
// TransactionOutPoint
// ---------------------------------------------------------------------------

pub extern fn btck_transaction_out_point_copy(transaction_out_point: *const btck_TransactionOutPoint) ?*btck_TransactionOutPoint;
pub extern fn btck_transaction_out_point_get_index(transaction_out_point: *const btck_TransactionOutPoint) u32;
pub extern fn btck_transaction_out_point_get_txid(transaction_out_point: *const btck_TransactionOutPoint) ?*const btck_Txid;
pub extern fn btck_transaction_out_point_destroy(transaction_out_point: ?*btck_TransactionOutPoint) void;

// ---------------------------------------------------------------------------
// Txid
// ---------------------------------------------------------------------------

pub extern fn btck_txid_copy(txid: *const btck_Txid) ?*btck_Txid;
pub extern fn btck_txid_equals(txid1: *const btck_Txid, txid2: *const btck_Txid) c_int;
pub extern fn btck_txid_to_bytes(txid: *const btck_Txid, output: *[32]u8) void;
pub extern fn btck_txid_destroy(txid: ?*btck_Txid) void;

// ---------------------------------------------------------------------------
// Coin
// ---------------------------------------------------------------------------

pub extern fn btck_coin_copy(coin: *const btck_Coin) ?*btck_Coin;
pub extern fn btck_coin_confirmation_height(coin: *const btck_Coin) u32;
pub extern fn btck_coin_is_coinbase(coin: *const btck_Coin) c_int;
pub extern fn btck_coin_get_output(coin: *const btck_Coin) ?*const btck_TransactionOutput;
pub extern fn btck_coin_destroy(coin: ?*btck_Coin) void;

// ---------------------------------------------------------------------------
// BlockHash
// ---------------------------------------------------------------------------

pub extern fn btck_block_hash_create(block_hash: *const [32]u8) ?*btck_BlockHash;
pub extern fn btck_block_hash_equals(hash1: *const btck_BlockHash, hash2: *const btck_BlockHash) c_int;
pub extern fn btck_block_hash_copy(block_hash: *const btck_BlockHash) ?*btck_BlockHash;
pub extern fn btck_block_hash_to_bytes(block_hash: *const btck_BlockHash, output: *[32]u8) void;
pub extern fn btck_block_hash_destroy(block_hash: ?*btck_BlockHash) void;

// ---------------------------------------------------------------------------
// BlockHeader
// ---------------------------------------------------------------------------

pub extern fn btck_block_header_create(raw_block_header: *const anyopaque, raw_block_header_len: usize) ?*btck_BlockHeader;
pub extern fn btck_block_header_copy(header: *const btck_BlockHeader) ?*btck_BlockHeader;
pub extern fn btck_block_header_get_hash(header: *const btck_BlockHeader) ?*btck_BlockHash;
pub extern fn btck_block_header_get_prev_hash(header: *const btck_BlockHeader) ?*const btck_BlockHash;
pub extern fn btck_block_header_get_timestamp(header: *const btck_BlockHeader) u32;
pub extern fn btck_block_header_get_bits(header: *const btck_BlockHeader) u32;
pub extern fn btck_block_header_get_version(header: *const btck_BlockHeader) i32;
pub extern fn btck_block_header_get_nonce(header: *const btck_BlockHeader) u32;
pub extern fn btck_block_header_to_bytes(header: *const btck_BlockHeader, output: *[80]u8) c_int;
pub extern fn btck_block_header_destroy(header: ?*btck_BlockHeader) void;

// ---------------------------------------------------------------------------
// Testing
// ---------------------------------------------------------------------------

pub extern fn btck_set_mock_time(timestamp: i64) c_int;
