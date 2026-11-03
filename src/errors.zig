//! Error sets returned by the wrapper API.

/// Errors reported by the kernel library.
pub const Error = error{
    /// The serialized transaction could not be parsed.
    InvalidTransaction,
    /// The serialized block could not be parsed.
    InvalidBlock,
    /// The serialized block header could not be parsed (it must be 80 bytes).
    InvalidBlockHeader,
    /// Precomputed transaction data could not be created.
    PrecomputedTransactionDataCreationFailed,
    /// The kernel context could not be created.
    ContextCreationFailed,
    /// Interrupting the kernel context failed.
    InterruptFailed,
    /// The chainstate manager options could not be created (e.g. invalid path).
    InvalidChainstateManagerOptions,
    /// The requested database cache size was rejected.
    InvalidDatabaseCacheSize,
    /// The requested wipe database combination was rejected.
    InvalidWipeOptions,
    /// The chainstate manager could not be created.
    ChainstateManagerCreationFailed,
    /// Importing block files or reindexing failed.
    ImportBlocksFailed,
    /// Processing a block failed.
    ProcessBlockFailed,
    /// Processing a block header failed.
    ProcessBlockHeaderFailed,
    /// Reading a block from disk failed.
    BlockReadFailed,
    /// Reading block spent outputs (undo data) from disk failed.
    SpentOutputsReadFailed,
    /// The logging connection could not be created.
    LoggingConnectionFailed,
    /// The mock timestamp is out of the valid range.
    InvalidMockTime,
    /// Serializing a value failed.
    SerializationFailed,
};

/// Errors that can be reported by script verification. An invalid script is
/// not an error: it is reported as `false` by `ScriptPubkey.verify`.
pub const ScriptVerifyError = error{
    /// The verification flags were combined in an invalid way.
    InvalidFlagsCombination,
    /// The taproot flag was set, so precomputed data holding the spent outputs has to be provided.
    SpentOutputsRequired,
};
