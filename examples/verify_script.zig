//! Verifies the taproot input of mainnet transaction
//! 33e794d097969002ee05d336686fc03c9e15a597c1b9827669460fac98799036.

const std = @import("std");
const btck = @import("bitcoinkernel");

const spending_tx_hex = "01000000000101d1f1c1f8cdf6759167b90f52c9ad358a369f95284e841d7a2536cef31c0549580100000000fdffffff020000000000000000316a2f49206c696b65205363686e6f7272207369677320616e6420492063616e6e6f74206c69652e204062697462756734329e06010000000000225120a37c3903c8d0db6512e2b40b0dffa05e5a3ab73603ce8c9c4b7771e5412328f90140a60c383f71bac0ec919b1d7dbc3eb72dd56e7aa99583615564f9f99b8ae4e837b758773a5b2e4c51348854c8389f008e05029db7f464a5ff2e01d5e6e626174affd30a00";
const spent_script_hex = "5120339ce7e165e67d93adb3fef88a6d4beed33f01fa876f05a225242b82a631abc0";
const spent_amount: i64 = 88480;

pub fn main() !void {
    var tx_buf: [spending_tx_hex.len / 2]u8 = undefined;
    var script_buf: [spent_script_hex.len / 2]u8 = undefined;

    const tx = try btck.Transaction.init(try std.fmt.hexToBytes(&tx_buf, spending_tx_hex));
    defer tx.deinit();
    const spent_script = btck.ScriptPubkey.init(try std.fmt.hexToBytes(&script_buf, spent_script_hex));
    defer spent_script.deinit();

    // Taproot signatures commit to all spent outputs, so they have to be
    // supplied through precomputed transaction data.
    const spent_output = btck.TransactionOutput.init(spent_script, spent_amount);
    defer spent_output.deinit();
    const precomputed = try btck.PrecomputedTransactionData.init(tx, &.{spent_output});
    defer precomputed.deinit();

    const valid = try spent_script.verify(spent_amount, tx, precomputed, 0, .all);
    std.debug.print("txid {f}: input 0 is {s}\n", .{ tx.txid(), if (valid) "valid" else "INVALID" });
    if (!valid) return error.InvalidScript;
}
