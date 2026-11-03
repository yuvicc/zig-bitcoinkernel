//! Integration tests for the bitcoinkernel bindings. Test vectors are taken
//! from Bitcoin Core's `src/test/kernel/test_kernel.cpp` (v32.0).

const std = @import("std");
const btck = @import("bitcoinkernel");

const testing = std.testing;
const gpa = testing.allocator;

const regtest_block_data = @embedFile("data/regtest_blocks.txt");

fn hexAlloc(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(out);
    _ = try std.fmt.hexToBytes(out, hex);
    return out;
}

/// Decodes all regtest blocks. Free with `freeRegtestBlocks`.
fn loadRegtestBlocks(allocator: std.mem.Allocator) ![][]u8 {
    var list: std.ArrayList([]u8) = .empty;
    errdefer {
        for (list.items) |b| allocator.free(b);
        list.deinit(allocator);
    }
    var it = std.mem.tokenizeScalar(u8, regtest_block_data, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) continue;
        try list.append(allocator, try hexAlloc(allocator, trimmed));
    }
    return list.toOwnedSlice(allocator);
}

fn freeRegtestBlocks(allocator: std.mem.Allocator, blocks: [][]u8) void {
    for (blocks) |b| allocator.free(b);
    allocator.free(blocks);
}

fn displayHex(bytes: [32]u8) [64]u8 {
    var reversed = bytes;
    std.mem.reverse(u8, &reversed);
    return std.fmt.bytesToHex(reversed, .lower);
}

const legacy_tx_hex = "02000000013f7cebd65c27431a90bba7f796914fe8cc2ddfc3f2cbd6f7e5f2fc854534da95000000006b483045022100de1ac3bcdfb0332207c4a91f3832bd2c2915840165f876ab47c5f8996b971c3602201c6c053d750fadde599e6f5c4e1963df0f01fc0d97815e8157e3d59fe09ca30d012103699b464d1d8bc9e47d4fb1cdaa89a1c5783d68363c4dbc4b524ed3d857148617feffffff02836d3c01000000001976a914fc25d6d5c94003bf5b0c7b640a248e2c637fcfb088ac7ada8202000000001976a914fbed3d9b11183209a57999d54d59f67c019e756c88ac6acb0700";
const taproot_tx_hex = "02000000000101904f4ee5c87d20090b642f116e458cd6693292ad9ece23e72f15fb6c05b956210500000000fdffffff02e2010000000000002251200839a723933b56560487ec4d67dda58f09bae518ffa7e148313c5696ac837d9f10060000000000002251205826bcdae7abfb1c468204170eab00d887b61ab143464a4a09e1450bdc59a3340140f26e7af574e647355830772946356c27e7bbc773c5293688890f58983499581be84de40be7311a14e6d6422605df086620e75adae84ff06b75ce5894de5e994a00000000";
const mainnet_block_1_hex = "010000006fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000982051fd1e4ba744bbbe680e1fee14677ba1a3c3540bf7b1cdb606e857233e0e61bc6649ffff001d01e362990101000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0704ffff001d0104ffffffff0100f2052a0100000043410496b538e853519c726a2c91e61ec11600ae1390813a627c66fb8be7947be63c52da7589379515d4e0a604f8141781e62294721166bf621e73a82cbf2342c858eeac00000000";

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

test "transaction parsing, accessors and serialization" {
    const raw = try hexAlloc(gpa, legacy_tx_hex);
    defer gpa.free(raw);

    const tx = try btck.Transaction.init(raw);
    defer tx.deinit();

    try testing.expectEqual(@as(usize, 1), tx.countInputs());
    try testing.expectEqual(@as(usize, 2), tx.countOutputs());
    try testing.expectEqual(@as(u32, 510826), tx.lockTime());

    const bytes = try tx.toBytes(gpa);
    defer gpa.free(bytes);
    try testing.expectEqualSlices(u8, raw, bytes);

    // Streaming serialization into a std.Io.Writer.
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    try tx.writeTo(&aw.writer);
    try testing.expectEqualSlices(u8, raw, aw.written());

    var printed: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&printed, "{f}", .{tx.txid()});
    try testing.expectEqualStrings("aca326a724eda9a461c10a876534ecd5ae7b27f10f26c3862fb996f80ea2d45d", &printed);

    var total: i64 = 0;
    var outputs = tx.outputs();
    while (outputs.next()) |out| total += out.amount();
    try testing.expectEqual(@as(i64, 20737411 + 42130042), total);

    const copy = tx.copy();
    defer copy.deinit();
    try testing.expect(copy.txid().eql(tx.txid()));

    const owned_txid = tx.txid().copy();
    defer owned_txid.deinit();
    try testing.expect(owned_txid.eql(tx.txid()));

    try testing.expectError(error.InvalidTransaction, btck.Transaction.init(&.{ 0x01, 0x23, 0x00 }));
    try testing.expectError(error.InvalidTransaction, btck.Transaction.init(&.{}));
}

test "transaction inputs, out points and witness stacks" {
    const raw = try hexAlloc(gpa, "020000000248c03e66fd371c7033196ce24298628e59ebefa00363026044e0f35e0325a65d000000006a473044022004893432347f39beaa280e99da595681ddb20fc45010176897e6e055d716dbfa022040a9e46648a5d10c33ef7cee5e6cf4b56bd513eae3ae044f0039824b02d0f44c012102982331a52822fd9b62e9b5d120da1d248558fac3da3a3c51cd7d9c8ad3da760efeffffffb856678c6e4c3c84e39e2ca818807049d6fba274b42af3c6d3f9d4b6513212d2000000006a473044022068bcedc7fe39c9f21ad318df2c2da62c2dc9522a89c28c8420ff9d03d2e6bf7b0220132afd752754e5cb1ea2fd0ed6a38ec666781e34b0e93dc9a08f2457842cf5660121033aeb9c079ea3e08ea03556182ab520ce5c22e6b0cb95cee6435ee17144d860cdfeffffff0260d50b00000000001976a914363cc8d55ea8d0500de728ef6d63804ddddbdc9888ac67040f00000000001976a914c303bdc5064bf9c9a8b507b5496bd0987285707988ac6acb0700");
    defer gpa.free(raw);
    const tx = try btck.Transaction.init(raw);
    defer tx.deinit();

    try testing.expectEqual(@as(usize, 2), tx.countInputs());
    const input_0 = tx.inputAt(0);
    const input_1 = tx.inputAt(1);

    const expected_sig_0 = try hexAlloc(gpa, "473044022004893432347f39beaa280e99da595681ddb20fc45010176897e6e055d716dbfa022040a9e46648a5d10c33ef7cee5e6cf4b56bd513eae3ae044f0039824b02d0f44c012102982331a52822fd9b62e9b5d120da1d248558fac3da3a3c51cd7d9c8ad3da760e");
    defer gpa.free(expected_sig_0);
    const sig_0 = try input_0.scriptSig(gpa);
    defer gpa.free(sig_0);
    try testing.expectEqualSlices(u8, expected_sig_0, sig_0);

    try testing.expectEqual(@as(u32, 0xfffffffe), input_0.sequence());
    try testing.expectEqual(@as(usize, 0), input_0.witnessStack().countItems());
    try testing.expectEqual(@as(u32, 0), input_0.outPoint().index());
    try testing.expect(!input_0.outPoint().isNull());
    try testing.expect(!input_0.outPoint().txid().eql(input_1.outPoint().txid()));

    // Owned copies outlive the transaction they came from.
    const owned_input = input_1.copy();
    defer owned_input.deinit();
    const owned_point = owned_input.outPoint().copy();
    defer owned_point.deinit();
    try testing.expect(owned_point.txid().eql(input_1.outPoint().txid()));

    var inputs = tx.inputs();
    var n: usize = 0;
    while (inputs.next()) |_| n += 1;
    try testing.expectEqual(@as(usize, 2), n);

    const segwit_raw = try hexAlloc(gpa, "010000000001011f97548fbbe7a0db7588a66e18d803d0089315aa7d4cc28360b6ec50ef36718a0100000000ffffffff02df1776000000000017a9146c002a686959067f4866b8fb493ad7970290ab728757d29f0000000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d04004730440220565d170eed95ff95027a69b313758450ba84a01224e1f7f130dda46e94d13f8602207bdd20e307f062594022f12ed5017bbf4a055a06aea91c10110a0e3bb23117fc014730440220647d2dc5b15f60bc37dc42618a370b2a1490293f9e5c8464f53ec4fe1dfe067302203598773895b4b16d37485cbe21b337f4e4b650739880098c592553add7dd4355016952210375e00eb72e29da82b89367947f29ef34afb75e8654f6ea368e0acdfd92976b7c2103a1b26313f430c4b15bb1fdce663207659d8cac749a0e53d70eff01874496feff2103c96d495bfdd5ba4145e3e046fee45e84a8a48ad05bd8dbb395c011a32cf9f88053ae00000000");
    defer gpa.free(segwit_raw);
    const segwit_tx = try btck.Transaction.init(segwit_raw);
    defer segwit_tx.deinit();
    const ws = segwit_tx.inputAt(0).witnessStack();
    try testing.expectEqual(@as(usize, 4), ws.countItems());

    const item_0 = try ws.itemAt(gpa, 0);
    defer gpa.free(item_0);
    try testing.expectEqual(@as(usize, 0), item_0.len);

    const expected_item_3 = try hexAlloc(gpa, "52210375e00eb72e29da82b89367947f29ef34afb75e8654f6ea368e0acdfd92976b7c2103a1b26313f430c4b15bb1fdce663207659d8cac749a0e53d70eff01874496feff2103c96d495bfdd5ba4145e3e046fee45e84a8a48ad05bd8dbb395c011a32cf9f88053ae");
    defer gpa.free(expected_item_3);
    const item_3 = try ws.itemAt(gpa, 3);
    defer gpa.free(item_3);
    try testing.expectEqualSlices(u8, expected_item_3, item_3);

    const owned_ws = ws.copy();
    defer owned_ws.deinit();
    try testing.expectEqual(@as(usize, 4), owned_ws.countItems());
}

test "script pubkey and transaction output" {
    const script = try hexAlloc(gpa, "76a9144bfbaf6afb76cc5771bc6404810d1cc041a6933988ac");
    defer gpa.free(script);

    const spk = btck.ScriptPubkey.init(script);
    defer spk.deinit();
    const spk_bytes = try spk.toBytes(gpa);
    defer gpa.free(spk_bytes);
    try testing.expectEqualSlices(u8, script, spk_bytes);

    const empty = btck.ScriptPubkey.init(&.{});
    defer empty.deinit();
    const empty_bytes = try empty.toBytes(gpa);
    defer gpa.free(empty_bytes);
    try testing.expectEqual(@as(usize, 0), empty_bytes.len);

    const output = btck.TransactionOutput.init(spk, 1);
    defer output.deinit();
    try testing.expectEqual(@as(i64, 1), output.amount());
    const out_spk = try output.scriptPubkey().toBytes(gpa);
    defer gpa.free(out_spk);
    try testing.expectEqualSlices(u8, script, out_spk);

    const output_copy = output.copy();
    defer output_copy.deinit();
    try testing.expectEqual(@as(i64, 1), output_copy.amount());
}

test "transaction check" {
    const valid_raw = try hexAlloc(gpa, "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000");
    defer gpa.free(valid_raw);
    const invalid_raw = try hexAlloc(gpa, "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022100f16703104aab4e4088317c862daec83440242411b039d14280e03dd33b487ab802201318a7be236672c5c56083eb7a5a195bc57a40af7923ff8545016cd3b571e2a601232103c40e5d339df3f30bf753e7e04450ae4ef76c9e45587d1d993bdc4cd06f0651c7acffffffff0000000000");
    defer gpa.free(invalid_raw);

    const state = btck.TxValidationState.init();
    defer state.deinit();
    try testing.expectEqual(btck.ValidationMode.valid, state.validationMode());
    try testing.expectEqual(btck.TxValidationResult.unset, state.result());

    const valid_tx = try btck.Transaction.init(valid_raw);
    defer valid_tx.deinit();
    try testing.expect(valid_tx.check(state));
    try testing.expectEqual(btck.ValidationMode.valid, state.validationMode());

    const invalid_tx = try btck.Transaction.init(invalid_raw);
    defer invalid_tx.deinit();
    try testing.expect(!invalid_tx.check(state));
    try testing.expectEqual(btck.ValidationMode.invalid, state.validationMode());
    try testing.expectEqual(btck.TxValidationResult.consensus, state.result());

    // The state is overwritten in place.
    try testing.expect(valid_tx.check(state));
    try testing.expectEqual(btck.TxValidationResult.unset, state.result());
}

// ---------------------------------------------------------------------------
// Script verification
// ---------------------------------------------------------------------------

const verify_all_pre_taproot: btck.ScriptVerificationFlags = blk: {
    var f = btck.ScriptVerificationFlags.all;
    f.taproot = false;
    break :blk f;
};
const verify_all_pre_segwit: btck.ScriptVerificationFlags = blk: {
    var f = verify_all_pre_taproot;
    f.witness = false;
    break :blk f;
};

fn runVerifyTest(
    spent_script_pubkey: btck.ScriptPubkey,
    spending_tx: btck.Transaction,
    precomputed: ?btck.PrecomputedTransactionData,
    amount: i64,
    input_index: u32,
    taproot: bool,
) !void {
    if (taproot) {
        try testing.expect(try spent_script_pubkey.verify(amount, spending_tx, precomputed, input_index, .all));
    } else {
        try testing.expectError(
            error.SpentOutputsRequired,
            spent_script_pubkey.verify(amount, spending_tx, precomputed, input_index, .all),
        );
    }
    try testing.expect(try spent_script_pubkey.verify(amount, spending_tx, precomputed, input_index, verify_all_pre_taproot));
    try testing.expect(try spent_script_pubkey.verify(0, spending_tx, precomputed, input_index, verify_all_pre_segwit));
}

test "script verification: legacy, segwit and taproot" {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Legacy transaction aca326a724eda9a461c10a876534ecd5ae7b27f10f26c3862fb996f80ea2d45d
    {
        const spk = btck.ScriptPubkey.init(try hexAlloc(arena, "76a9144bfbaf6afb76cc5771bc6404810d1cc041a6933988ac"));
        defer spk.deinit();
        const tx = try btck.Transaction.init(try hexAlloc(arena, legacy_tx_hex));
        defer tx.deinit();
        try runVerifyTest(spk, tx, null, 0, 0, false);

        const precomputed = try btck.PrecomputedTransactionData.init(tx, &.{});
        defer precomputed.deinit();
        try runVerifyTest(spk, tx, precomputed, 0, 0, false);

        // A wrong amount does not matter without the witness flag, but a
        // wrong script must fail.
        const wrong_spk = btck.ScriptPubkey.init(try hexAlloc(arena, "76a9144bfbaf6afb76cc5771bc6404810d1cc041a6933988ad"));
        defer wrong_spk.deinit();
        try testing.expect(!try wrong_spk.verify(0, tx, null, 0, verify_all_pre_segwit));
    }

    // Segwit transaction 1a3e89644985fbbb41e0dcfe176739813542b5937003c46a07de1e3ee7a4a7f3
    {
        const spk = btck.ScriptPubkey.init(try hexAlloc(arena, "0020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d"));
        defer spk.deinit();
        const tx = try btck.Transaction.init(try hexAlloc(arena, "010000000001011f97548fbbe7a0db7588a66e18d803d0089315aa7d4cc28360b6ec50ef36718a0100000000ffffffff02df1776000000000017a9146c002a686959067f4866b8fb493ad7970290ab728757d29f0000000000220020701a8d401c84fb13e6baf169d59684e17abd9fa216c8cc5b9fc63d622ff8c58d04004730440220565d170eed95ff95027a69b313758450ba84a01224e1f7f130dda46e94d13f8602207bdd20e307f062594022f12ed5017bbf4a055a06aea91c10110a0e3bb23117fc014730440220647d2dc5b15f60bc37dc42618a370b2a1490293f9e5c8464f53ec4fe1dfe067302203598773895b4b16d37485cbe21b337f4e4b650739880098c592553add7dd4355016952210375e00eb72e29da82b89367947f29ef34afb75e8654f6ea368e0acdfd92976b7c2103a1b26313f430c4b15bb1fdce663207659d8cac749a0e53d70eff01874496feff2103c96d495bfdd5ba4145e3e046fee45e84a8a48ad05bd8dbb395c011a32cf9f88053ae00000000"));
        defer tx.deinit();
        try runVerifyTest(spk, tx, null, 18393430, 0, false);

        const precomputed = try btck.PrecomputedTransactionData.init(tx, &.{});
        defer precomputed.deinit();
        try runVerifyTest(spk, tx, precomputed, 18393430, 0, false);

        // With the witness flag the amount is committed to.
        try testing.expect(!try spk.verify(18393431, tx, null, 0, verify_all_pre_taproot));
    }

    // Taproot transaction 33e794d097969002ee05d336686fc03c9e15a597c1b9827669460fac98799036
    {
        const spk = btck.ScriptPubkey.init(try hexAlloc(arena, "5120339ce7e165e67d93adb3fef88a6d4beed33f01fa876f05a225242b82a631abc0"));
        defer spk.deinit();
        const tx = try btck.Transaction.init(try hexAlloc(arena, "01000000000101d1f1c1f8cdf6759167b90f52c9ad358a369f95284e841d7a2536cef31c0549580100000000fdffffff020000000000000000316a2f49206c696b65205363686e6f7272207369677320616e6420492063616e6e6f74206c69652e204062697462756734329e06010000000000225120a37c3903c8d0db6512e2b40b0dffa05e5a3ab73603ce8c9c4b7771e5412328f90140a60c383f71bac0ec919b1d7dbc3eb72dd56e7aa99583615564f9f99b8ae4e837b758773a5b2e4c51348854c8389f008e05029db7f464a5ff2e01d5e6e626174affd30a00"));
        defer tx.deinit();
        const spent = btck.TransactionOutput.init(spk, 88480);
        defer spent.deinit();
        const precomputed = try btck.PrecomputedTransactionData.init(tx, &.{spent});
        defer precomputed.deinit();
        try runVerifyTest(spk, tx, precomputed, 88480, 0, true);

        // Taproot without precomputed spent outputs is a usage error.
        try testing.expectError(error.SpentOutputsRequired, spk.verify(88480, tx, null, 0, .all));
    }

    // Two-input taproot transaction e8e8320f40c31ed511570e9cdf1d241f8ec9a5cc392e6105240ac8dbea2098de
    {
        const spk0 = btck.ScriptPubkey.init(try hexAlloc(arena, "5120b7da80f57e36930b0515eb09293e25858d13e6b91fee6184943f5a584cb4248e"));
        defer spk0.deinit();
        const spk1 = btck.ScriptPubkey.init(try hexAlloc(arena, "5120ab78e077d062e7b8acd7063668b4db5355a1b5d5fd2a46a8e98e62e5e63fab77"));
        defer spk1.deinit();
        const tx = try btck.Transaction.init(try hexAlloc(arena, "02000000000102c0f01ead18750892c84b1d4f595149ad38f16847df1fbf490e235b3b78c1f98a0100000000ffffffff456764a19c2682bf5b1567119f06a421849ad1664cf42b5ef95b69d6e2159e9d0000000000ffffffff022202000000000000225120b6c0c2a8ee25a2ae0322ab7f1a06f01746f81f6b90d179c3c2a51a356e6188f1d70e020000000000225120b7da80f57e36930b0515eb09293e25858d13e6b91fee6184943f5a584cb4248e0141933fdc49eb1af1f08ed1e9cf5559259309a8acd25ff1e6999b6955124438aef4fceaa4e6a5f85286631e24837329563595bc3cf4b31e1c687442abb01c4206818101401c9620faf1e8c84187762ad14d04ae3857f59a2f03f1dcbb99290e16dfc572a63b4ea435780a5787af59beb5742fd71cda8a95381517a1ff14b4c67996c4bf8100000000"));
        defer tx.deinit();
        const out0 = btck.TransactionOutput.init(spk0, 546);
        defer out0.deinit();
        const out1 = btck.TransactionOutput.init(spk1, 135125);
        defer out1.deinit();
        const precomputed = try btck.PrecomputedTransactionData.init(tx, &.{ out0, out1 });
        defer precomputed.deinit();
        const precomputed_copy = precomputed.copy();
        defer precomputed_copy.deinit();
        try runVerifyTest(spk0, tx, precomputed, 546, 0, true);
        try runVerifyTest(spk1, tx, precomputed_copy, 135125, 1, true);
    }
}

test "script verification rejects invalid flag combinations" {
    const spk = btck.ScriptPubkey.init(&.{0x51});
    defer spk.deinit();
    const raw = try hexAlloc(gpa, legacy_tx_hex);
    defer gpa.free(raw);
    const tx = try btck.Transaction.init(raw);
    defer tx.deinit();
    // Witness verification requires P2SH.
    try testing.expectError(error.InvalidFlagsCombination, spk.verify(0, tx, null, 0, .{ .witness = true }));
    // Bits outside of the known flags are rejected (the kernel would abort).
    try testing.expectError(
        error.InvalidFlagsCombination,
        spk.verify(0, tx, null, 0, btck.ScriptVerificationFlags.fromInt(1 << 31)),
    );
}

// ---------------------------------------------------------------------------
// Logging, chain parameters and contexts
// ---------------------------------------------------------------------------

const TestLogger = struct {
    count: std.atomic.Value(usize) = .init(0),

    pub fn log(self: *TestLogger, message: []const u8) void {
        _ = message;
        _ = self.count.fetchAdd(1, .monotonic);
    }
};

fn discardLog(message: []const u8) void {
    _ = message;
}

test "logging" {
    btck.logging.setOptions(.{
        .log_timestamps = true,
        .log_time_micros = true,
        .always_print_category_levels = true,
    });
    btck.logging.setLevelCategory(.bench, .trace);
    btck.logging.disableCategory(.bench);
    btck.logging.enableCategory(.validation);
    btck.logging.disableCategory(.validation);

    btck.logging.setLevelCategory(.kernel, .trace);
    btck.logging.enableCategory(.kernel);

    var logger: TestLogger = .{};
    {
        const conn = try btck.LoggingConnection.init(&logger);
        defer conn.deinit();
        const conn_2 = try btck.LoggingConnection.initFn(discardLog);
        defer conn_2.deinit();

        // Creating a context produces kernel log messages.
        const ctx = try btck.Context.init(null);
        ctx.deinit();
    }
    try testing.expect(logger.count.load(.monotonic) > 0);

    const conn = try btck.LoggingConnection.initFn(discardLog);
    conn.deinit();
    btck.logging.disableCategory(.kernel);
}

test "chain parameters" {
    const signet = btck.ChainParameters.init(.signet);
    defer signet.deinit();
    const custom_signet = btck.ChainParameters.initSignet(&.{0x51});
    defer custom_signet.deinit();
    const copy = custom_signet.copy();
    defer copy.deinit();
    _ = copy.consensusParams();

    for (std.enums.values(btck.ChainType)) |chain_type| {
        const params = btck.ChainParameters.init(chain_type);
        params.deinit();
    }
}

const TestNotifications = struct {
    block_tips: std.atomic.Value(usize) = .init(0),
    header_tips: std.atomic.Value(usize) = .init(0),
    fatal_errors: std.atomic.Value(usize) = .init(0),

    pub fn blockTip(self: *TestNotifications, state: btck.SynchronizationState, entry: btck.BlockTreeEntry, progress: f64) void {
        _ = state;
        _ = progress;
        std.debug.assert(entry.height() >= 0);
        _ = self.block_tips.fetchAdd(1, .monotonic);
    }

    pub fn headerTip(self: *TestNotifications, state: btck.SynchronizationState, height: i64, timestamp: i64, presync: bool) void {
        _ = state;
        _ = height;
        _ = timestamp;
        _ = presync;
        _ = self.header_tips.fetchAdd(1, .monotonic);
    }

    pub fn warningSet(self: *TestNotifications, warning: btck.Warning, message: []const u8) void {
        _ = self;
        _ = warning;
        _ = message;
    }

    pub fn fatalError(self: *TestNotifications, message: []const u8) void {
        _ = message;
        _ = self.fatal_errors.fetchAdd(1, .monotonic);
    }
};

test "context creation" {
    {
        const ctx = try btck.Context.init(null);
        defer ctx.deinit();
        const ctx_copy = ctx.copy();
        defer ctx_copy.deinit();
    }
    {
        const options = btck.ContextOptions.init();
        defer options.deinit();
        const ctx = try btck.Context.init(options);
        defer ctx.deinit();
    }
    {
        var notifications: TestNotifications = .{};
        const options = btck.ContextOptions.init();
        defer options.deinit();
        const params = btck.ChainParameters.init(.mainnet);
        defer params.deinit();
        options.setChainParams(params);
        options.setNotifications(&notifications);
        const ctx = try btck.Context.init(options);
        defer ctx.deinit();
        try ctx.interrupt();
    }
}

test "mock time" {
    try btck.setMockTime(1_700_000_000);
    try btck.setMockTime(0);
    try testing.expectError(error.InvalidMockTime, btck.setMockTime(-1));
    try testing.expectError(error.InvalidMockTime, btck.setMockTime(1 << 32));
}

// ---------------------------------------------------------------------------
// Blocks and block headers
// ---------------------------------------------------------------------------

test "block header" {
    const raw_0 = try hexAlloc(gpa, "00e07a26beaaeee2e71d7eb19279545edbaf15de0999983626ec00000000000000000000579cf78b65229bfb93f4a11463af2eaa5ad91780f27f5d147a423bea5f7e4cdf2a47e268b4dd01173a9662ee");
    defer gpa.free(raw_0);
    const header_0 = try btck.BlockHeader.init(raw_0);
    defer header_0.deinit();
    const hash_0 = header_0.hash();
    defer hash_0.deinit();
    try testing.expectEqualStrings("00000000000000000000325c7e14a4ee3b4fcb2343089a839287308a0ddbee4f", &displayHex(hash_0.toBytes()));

    const raw_block = try hexAlloc(gpa, mainnet_block_1_hex);
    defer gpa.free(raw_block);
    const raw_header = raw_block[0..80];

    const header = try btck.BlockHeader.init(raw_header);
    defer header.deinit();
    try testing.expectEqual(@as(i32, 1), header.version());
    try testing.expectEqual(@as(u32, 1231469665), header.timestamp());
    try testing.expectEqual(@as(u32, 0x1d00ffff), header.bits());
    try testing.expectEqual(@as(u32, 2573394689), header.nonce());

    const hash = header.hash();
    defer hash.deinit();
    var printed: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&printed, "{f}", .{hash});
    try testing.expectEqualStrings("00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048", &printed);
    try testing.expectEqualStrings("000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f", &displayHex(header.prevHash().toBytes()));

    const serialized = try header.toBytes();
    try testing.expectEqualSlices(u8, raw_header, &serialized);

    const header_copy = header.copy();
    defer header_copy.deinit();
    const copy_hash = header_copy.hash();
    defer copy_hash.deinit();
    try testing.expect(copy_hash.eql(hash));

    // Header from block.
    const block = try btck.Block.init(raw_block);
    defer block.deinit();
    const block_header = block.header();
    defer block_header.deinit();
    try testing.expectEqualSlices(u8, raw_header, &(try block_header.toBytes()));
    const block_hash = block.hash();
    defer block_hash.deinit();
    try testing.expect(block_hash.eql(hash));

    try testing.expectError(error.InvalidBlockHeader, btck.BlockHeader.init(raw_header[0..79]));
    try testing.expectError(error.InvalidBlockHeader, btck.BlockHeader.init(&.{}));
}

test "block hash" {
    var bytes: [32]u8 = undefined;
    for (&bytes, 0..) |*b, i| b.* = @intCast(i);
    const hash = btck.BlockHash.init(bytes);
    defer hash.deinit();
    try testing.expectEqualSlices(u8, &bytes, &hash.toBytes());

    const copy = hash.copy();
    defer copy.deinit();
    try testing.expect(copy.eql(hash));

    bytes[0] ^= 1;
    const other = btck.BlockHash.init(bytes);
    defer other.deinit();
    try testing.expect(!other.eql(hash));
}

test "block parsing and serialization" {
    const blocks = try loadRegtestBlocks(gpa);
    defer freeRegtestBlocks(gpa, blocks);
    try testing.expectEqual(@as(usize, 206), blocks.len);

    const block = try btck.Block.init(blocks[205]);
    defer block.deinit();
    const block_copy = block.copy();
    defer block_copy.deinit();

    const serialized = try block_copy.toBytes(gpa);
    defer gpa.free(serialized);
    try testing.expectEqualSlices(u8, blocks[205], serialized);

    var count: usize = 0;
    var txs = block.transactions();
    while (txs.next()) |tx| {
        _ = tx.txid();
        count += 1;
    }
    try testing.expectEqual(block.countTransactions(), count);
    try testing.expect(count > 1);
    try testing.expect(block.transactionAt(0).inputAt(0).outPoint().isNull());

    try testing.expectError(error.InvalidBlock, btck.Block.init(&.{ 0x01, 0x23, 0x00 }));
    try testing.expectError(error.InvalidBlock, btck.Block.init(&.{}));
}

test "context-free block checks" {
    const merkle_root_offset = 4 + 32;
    const nbits_offset = 4 + 32 + 32 + 4;
    const coinbase_prevout_n_offset = 4 + 32 + 32 + 4 + 4 + 4 + 1 + 4 + 1 + 32;

    const raw = try hexAlloc(gpa, mainnet_block_1_hex);
    defer gpa.free(raw);

    const params = btck.ChainParameters.init(.mainnet);
    defer params.deinit();
    const consensus = params.consensusParams();

    const state = btck.BlockValidationState.init();
    defer state.deinit();

    const block = try btck.Block.init(raw);
    defer block.deinit();
    try testing.expect(block.check(consensus, .base, state));
    try testing.expectEqual(btck.ValidationMode.valid, state.validationMode());
    try testing.expect(block.check(consensus, .all, state));
    try testing.expectEqual(btck.ValidationMode.valid, state.validationMode());

    {
        const data = try gpa.dupe(u8, raw);
        defer gpa.free(data);
        data[merkle_root_offset] ^= 0x01;
        const bad = try btck.Block.init(data);
        defer bad.deinit();
        try testing.expect(!bad.check(consensus, .{ .merkle = true }, state));
        try testing.expectEqual(btck.ValidationMode.invalid, state.validationMode());
        try testing.expectEqual(btck.BlockValidationResult.mutated, state.result());
        try testing.expect(bad.check(consensus, .base, state));
    }
    {
        const data = try gpa.dupe(u8, raw);
        defer gpa.free(data);
        data[nbits_offset + 3] = 0x1c;
        const bad = try btck.Block.init(data);
        defer bad.deinit();
        try testing.expect(!bad.check(consensus, .{ .pow = true }, state));
        try testing.expectEqual(btck.BlockValidationResult.invalid_header, state.result());
        const state_copy = state.copy();
        defer state_copy.deinit();
        try testing.expectEqual(btck.BlockValidationResult.invalid_header, state_copy.result());
        try testing.expect(bad.check(consensus, .{ .merkle = true }, state));
    }
    {
        const data = try gpa.dupe(u8, raw);
        defer gpa.free(data);
        data[coinbase_prevout_n_offset] = 0x00;
        const bad = try btck.Block.init(data);
        defer bad.deinit();
        try testing.expect(!bad.check(consensus, .base, state));
        try testing.expectEqual(btck.BlockValidationResult.consensus, state.result());
    }

    try testing.expectError(error.InvalidBlock, btck.Block.init(raw[0..80]));
}

// ---------------------------------------------------------------------------
// Chainstate manager
// ---------------------------------------------------------------------------

const TestValidationInterface = struct {
    checked: std.atomic.Value(usize) = .init(0),
    checked_valid: std.atomic.Value(usize) = .init(0),
    pow_valid: std.atomic.Value(usize) = .init(0),
    connected: std.atomic.Value(usize) = .init(0),
    disconnected: std.atomic.Value(usize) = .init(0),

    pub fn blockChecked(self: *TestValidationInterface, block: btck.Block, state: btck.BlockValidationState) void {
        std.debug.assert(block.countTransactions() > 0);
        _ = self.checked.fetchAdd(1, .monotonic);
        if (state.validationMode() == .valid) _ = self.checked_valid.fetchAdd(1, .monotonic);
    }

    pub fn powValidBlock(self: *TestValidationInterface, block: btck.Block, entry: btck.BlockTreeEntry) void {
        _ = block;
        _ = entry;
        _ = self.pow_valid.fetchAdd(1, .monotonic);
    }

    pub fn blockConnected(self: *TestValidationInterface, block: btck.Block, entry: btck.BlockTreeEntry) void {
        const header = block.header();
        defer header.deinit();
        const hash = header.hash();
        defer hash.deinit();
        std.debug.assert(hash.eql(entry.blockHash()));
        _ = self.connected.fetchAdd(1, .monotonic);
    }

    pub fn blockDisconnected(self: *TestValidationInterface, block: btck.Block, entry: btck.BlockTreeEntry) void {
        _ = block;
        _ = entry;
        _ = self.disconnected.fetchAdd(1, .monotonic);
    }
};

const TestDir = struct {
    tmp: testing.TmpDir,
    path: []u8,
    blocks_path: []u8,

    fn init() !TestDir {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const path = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}", .{tmp.sub_path});
        errdefer gpa.free(path);
        const blocks_path = try std.fmt.allocPrint(gpa, "{s}/blocks", .{path});
        return .{ .tmp = tmp, .path = path, .blocks_path = blocks_path };
    }

    fn deinit(self: *TestDir) void {
        gpa.free(self.blocks_path);
        gpa.free(self.path);
        self.tmp.cleanup();
    }
};

fn createContext(chain_type: btck.ChainType, notifications: ?*TestNotifications, validation: ?*TestValidationInterface) !btck.Context {
    const options = btck.ContextOptions.init();
    defer options.deinit();
    const params = btck.ChainParameters.init(chain_type);
    defer params.deinit();
    options.setChainParams(params);
    if (notifications) |n| options.setNotifications(n);
    if (validation) |v| options.setValidationInterface(v);
    return btck.Context.init(options);
}

fn createChainman(ctx: btck.Context, dir: *const TestDir, in_memory: bool) !btck.ChainstateManager {
    const options = try btck.ChainstateManagerOptions.init(ctx, dir.path, dir.blocks_path);
    defer options.deinit();
    options.setWorkerThreads(2);
    try options.setDatabaseCacheBytes(16 << 20);
    options.setBlockTreeDbInMemory(in_memory);
    options.setChainstateDbInMemory(in_memory);
    return btck.ChainstateManager.init(options);
}

test "chainstate manager options" {
    var dir = try TestDir.init();
    defer dir.deinit();
    const ctx = try createContext(.regtest, null, null);
    defer ctx.deinit();

    const options = try btck.ChainstateManagerOptions.init(ctx, dir.path, dir.blocks_path);
    defer options.deinit();
    try testing.expectError(error.InvalidDatabaseCacheSize, options.setDatabaseCacheBytes(1024));
    try options.setDatabaseCacheBytes(8 << 20);
    try testing.expectError(error.InvalidWipeOptions, options.setWipeDbs(true, false));
    try options.setWipeDbs(false, true);
    try options.setWipeDbs(true, true);
    try options.setWipeDbs(false, false);
}

test "chainstate manager in memory" {
    var dir = try TestDir.init();
    defer dir.deinit();
    const blocks = try loadRegtestBlocks(gpa);
    defer freeRegtestBlocks(gpa, blocks);

    var notifications: TestNotifications = .{};
    const ctx = try createContext(.regtest, &notifications, null);
    defer ctx.deinit();
    {
        const chainman = try createChainman(ctx, &dir, true);
        defer chainman.deinit();
        for (blocks) |raw| {
            const block = try btck.Block.init(raw);
            defer block.deinit();
            try testing.expect(try chainman.processBlock(block));
        }
        // The 206 regtest blocks build on top of the genesis block.
        try testing.expectEqual(@as(i32, 206), chainman.activeChain().height());
    }
    // Genesis plus the 206 regtest blocks.
    try testing.expectEqual(@as(usize, 207), notifications.block_tips.load(.monotonic));
    try testing.expectEqual(@as(usize, 0), notifications.fatal_errors.load(.monotonic));

    // Nothing but the block files is written to disk.
    try dir.tmp.dir.access(testing.io, "blocks", .{});
    try testing.expectError(error.FileNotFound, dir.tmp.dir.access(testing.io, "blocks/index", .{}));
    try testing.expectError(error.FileNotFound, dir.tmp.dir.access(testing.io, "chainstate", .{}));

    try ctx.interrupt();
}

test "chainstate manager regtest" {
    var dir = try TestDir.init();
    defer dir.deinit();
    const blocks = try loadRegtestBlocks(gpa);
    defer freeRegtestBlocks(gpa, blocks);

    var notifications: TestNotifications = .{};
    var validation: TestValidationInterface = .{};
    const ctx = try createContext(.regtest, &notifications, &validation);
    defer ctx.deinit();

    // Process all headers first.
    {
        const chainman = try createChainman(ctx, &dir, false);
        defer chainman.deinit();
        try testing.expect(chainman.bestEntry() != null); // genesis is always loaded
        for (blocks) |raw| {
            const block = try btck.Block.init(raw);
            defer block.deinit();
            const header = block.header();
            defer header.deinit();
            const state = try chainman.processBlockHeader(header);
            defer state.deinit();
            try testing.expectEqual(btck.ValidationMode.valid, state.validationMode());
            try testing.expectEqual(btck.BlockValidationResult.unset, state.result());

            const hash = header.hash();
            defer hash.deinit();
            const entry = chainman.blockTreeEntryByHash(hash).?;
            try testing.expect(!chainman.activeChain().contains(entry));
            const best = chainman.bestEntry().?;
            try testing.expect(best.eql(entry));
            const best_header = best.header();
            defer best_header.deinit();
            const best_hash = best_header.hash();
            defer best_hash.deinit();
            try testing.expect(entry.blockHash().eql(best_hash));
        }
        try testing.expect(notifications.header_tips.load(.monotonic) > 0);
    }

    // Validate the blocks in two sessions, restarting halfway to check that
    // validation continues from the persisted state.
    const mid = blocks.len / 2;
    {
        const chainman = try createChainman(ctx, &dir, false);
        defer chainman.deinit();
        for (blocks[0..mid]) |raw| {
            const block = try btck.Block.init(raw);
            defer block.deinit();
            try testing.expect(try chainman.processBlock(block));
        }
    }

    const chainman = try createChainman(ctx, &dir, false);
    defer chainman.deinit();
    for (blocks[mid..]) |raw| {
        const block = try btck.Block.init(raw);
        defer block.deinit();
        try testing.expect(try chainman.processBlock(block));
    }
    // Re-processing a known block succeeds but is not new.
    {
        const block = try btck.Block.init(blocks[blocks.len - 1]);
        defer block.deinit();
        try testing.expect(!try chainman.processBlock(block));
    }

    // The 206 regtest blocks build on top of the genesis block.
    const chain = chainman.activeChain();
    try testing.expectEqual(@as(i32, 206), chain.height());
    try testing.expectEqual(@as(usize, 207), chain.countEntries());
    try testing.expect(chain.entryAt(207) == null);
    try testing.expect(chain.entryAt(-1) == null);

    // Validation interface callbacks fired for every block, including genesis.
    try testing.expectEqual(@as(usize, 207), validation.connected.load(.monotonic));
    try testing.expect(validation.checked_valid.load(.monotonic) >= 206);
    try testing.expectEqual(@as(usize, 0), validation.disconnected.load(.monotonic));

    const tip = chain.tip().?;
    try testing.expectEqual(@as(i32, 206), tip.height());
    try testing.expect(chain.contains(tip));
    try testing.expect(tip.ancestor(0).eql(chain.genesis().?));
    try testing.expect(chain.genesis().?.previous() == null);

    const read_block = try chainman.readBlock(tip);
    defer read_block.deinit();
    const read_bytes = try read_block.toBytes(gpa);
    defer gpa.free(read_bytes);
    try testing.expectEqualSlices(u8, blocks[blocks.len - 1], read_bytes);

    const tip_2 = tip.previous().?;
    const read_block_2 = try chainman.readBlock(tip_2);
    defer read_block_2.deinit();
    const read_bytes_2 = try read_block_2.toBytes(gpa);
    defer gpa.free(read_bytes_2);
    try testing.expectEqualSlices(u8, blocks[blocks.len - 2], read_bytes_2);

    const txid = read_block.transactionAt(0).txid();
    const txid_2 = read_block_2.transactionAt(0).txid();
    try testing.expect(!txid.eql(txid_2));
    try testing.expect(txid.eql(txid));

    // Verify every script in the chain, looking up spent outputs by txid.
    {
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();

        var outputs_by_txid: std.AutoHashMapUnmanaged([32]u8, btck.Transaction) = .empty;
        var owned_blocks: std.ArrayList(btck.Block) = .empty;
        defer for (owned_blocks.items) |b| b.deinit();

        var verified_inputs: usize = 0;
        var entries = chain.entries();
        while (entries.next()) |entry| {
            const block = try chainman.readBlock(entry);
            try owned_blocks.append(arena, block);
            var txs = block.transactions();
            while (txs.next()) |tx| {
                try outputs_by_txid.put(arena, tx.txid().toBytes(), tx);

                var spent: std.ArrayList(btck.TransactionOutput) = .empty;
                var inputs = tx.inputs();
                while (inputs.next()) |input| {
                    const point = input.outPoint();
                    if (point.isNull()) continue;
                    try testing.expect(!point.txid().eql(tx.txid()));
                    const prev_tx = outputs_by_txid.get(point.txid().toBytes()).?;
                    try testing.expect(prev_tx.txid().eql(point.txid()));
                    try spent.append(arena, prev_tx.outputAt(point.index()));
                }
                if (spent.items.len == 0) continue;
                try testing.expectEqual(tx.countInputs(), spent.items.len);

                const precomputed = try btck.PrecomputedTransactionData.init(tx, spent.items);
                defer precomputed.deinit();
                for (spent.items, 0..) |out, i| {
                    try testing.expect(try out.scriptPubkey().verify(out.amount(), tx, precomputed, @intCast(i), .all));
                    verified_inputs += 1;
                }
            }
        }
        try testing.expect(verified_inputs > 0);
    }

    // Spent outputs (undo data).
    const spent_outputs = try chainman.readSpentOutputs(tip);
    defer spent_outputs.deinit();
    const spent_outputs_prev = try chainman.readSpentOutputs(tip_2);
    defer spent_outputs_prev.deinit();
    try testing.expectEqual(@as(usize, 1), spent_outputs.count());

    const tx_spent = spent_outputs.transactionSpentOutputsAt(spent_outputs.count() - 1);
    const owned_tx_spent = tx_spent.copy();
    defer owned_tx_spent.deinit();
    try testing.expectEqual(tx_spent.count(), owned_tx_spent.count());

    const coin = tx_spent.coinAt(tx_spent.count() - 1);
    try testing.expect(!coin.isCoinbase());
    try testing.expectEqual(@as(u32, 143), coin.confirmationHeight());
    try testing.expectEqual(@as(i64, 3949990974), coin.output().amount());
    const owned_coin = coin.copy();
    defer owned_coin.deinit();
    try testing.expectEqual(@as(u32, 143), owned_coin.confirmationHeight());

    const spk_bytes = try coin.output().scriptPubkey().toBytes(gpa);
    defer gpa.free(spk_bytes);
    try testing.expectEqual(@as(usize, 34), spk_bytes.len);

    var it = spent_outputs.iterator();
    while (it.next()) |tso| {
        var coins = tso.iterator();
        while (coins.next()) |cn| try testing.expect(cn.output().amount() > 1);
    }

    var height: i32 = 0;
    var entries = chain.entries();
    while (entries.next()) |entry| : (height += 1) {
        try testing.expectEqual(height, entry.height());
    }
    try testing.expectEqual(@as(i32, 207), height);

    // Reading fails once the underlying files are gone.
    try dir.tmp.dir.deleteFile(testing.io, "blocks/blk00000.dat");
    try testing.expectError(error.BlockReadFailed, chainman.readBlock(tip_2));
    try dir.tmp.dir.deleteFile(testing.io, "blocks/rev00000.dat");
    try testing.expectError(error.SpentOutputsReadFailed, chainman.readSpentOutputs(tip));
}

test "chainstate manager reindex" {
    var dir = try TestDir.init();
    defer dir.deinit();
    const blocks = try loadRegtestBlocks(gpa);
    defer freeRegtestBlocks(gpa, blocks);

    const ctx = try createContext(.regtest, null, null);
    defer ctx.deinit();
    {
        const chainman = try createChainman(ctx, &dir, false);
        defer chainman.deinit();
        for (blocks[0..10]) |raw| {
            const block = try btck.Block.init(raw);
            defer block.deinit();
            _ = try chainman.processBlock(block);
        }
    }
    {
        const options = try btck.ChainstateManagerOptions.init(ctx, dir.path, dir.blocks_path);
        defer options.deinit();
        try options.setWipeDbs(true, true);
        const chainman = try btck.ChainstateManager.init(options);
        defer chainman.deinit();
        try chainman.importBlocks(gpa, &.{});
        try testing.expectEqual(@as(i32, 10), chainman.activeChain().height());
    }
    {
        // Import an external block file into a fresh data directory. The
        // kernel reads external files without de-obfuscation, so write a
        // plain one: (network magic, little-endian size, block) per block.
        var dir_2 = try TestDir.init();
        defer dir_2.deinit();

        var file_data: std.ArrayList(u8) = .empty;
        defer file_data.deinit(gpa);
        const regtest_magic = [_]u8{ 0xfa, 0xbf, 0xb5, 0xda };
        for (blocks[0..10]) |raw| {
            try file_data.appendSlice(gpa, &regtest_magic);
            var size: [4]u8 = undefined;
            std.mem.writeInt(u32, &size, @intCast(raw.len), .little);
            try file_data.appendSlice(gpa, &size);
            try file_data.appendSlice(gpa, raw);
        }
        try dir_2.tmp.dir.writeFile(testing.io, .{ .sub_path = "import.dat", .data = file_data.items });
        const import_path = try std.fmt.allocPrint(gpa, "{s}/import.dat", .{dir_2.path});
        defer gpa.free(import_path);

        const chainman = try createChainman(ctx, &dir_2, false);
        defer chainman.deinit();
        try testing.expectEqual(@as(i32, 0), chainman.activeChain().height());
        try chainman.importBlocks(gpa, &.{import_path});
        try testing.expectEqual(@as(i32, 10), chainman.activeChain().height());
    }
}

test "chainstate manager mainnet genesis" {
    var dir = try TestDir.init();
    defer dir.deinit();
    const ctx = try createContext(.mainnet, null, null);
    defer ctx.deinit();
    const chainman = try createChainman(ctx, &dir, true);
    defer chainman.deinit();

    const chain = chainman.activeChain();
    try testing.expectEqual(@as(i32, 0), chain.height());
    const genesis = chain.genesis().?;
    try testing.expectEqualStrings(
        "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
        &displayHex(genesis.blockHash().toBytes()),
    );
    const genesis_block = try chainman.readBlock(genesis);
    defer genesis_block.deinit();
    try testing.expectEqual(@as(usize, 1), genesis_block.countTransactions());
}
