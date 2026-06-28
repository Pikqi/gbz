const std = @import("std");
const InstructionMod = @import("./src/core/instructions.zig");
const Instruction = InstructionMod.Instruction;

const OperandO = struct {
    name: ?[]u8 = null,
    immediate: ?bool = null,
    bytes: ?f32 = null,
    increment: ?bool = null,
    decrement: ?bool = null,
};
const FlagsO = struct {
    Z: []u8,
    N: []u8,
    H: []u8,
    C: []u8,
};
const InstructionO = struct {
    opcode: []u8,
    mnemonic: []u8,
    bytes: f32,
    operands: ?[]OperandO = null,
    cycles: []f32,
    immediate: ?bool = null,
    flags: ?FlagsO = null,
};

const JsonStruct = struct {
    unprefixed: []InstructionO,
    cbprefixed: []InstructionO,
};

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    const out = std.Io.File.stdout().writer(io, &stdout_buffer);

    try generateSet(alloc, out, false, io);
    try out.print("\n", .{});
    try generateSet(alloc, out, true, io);
    out.flush() catch {};
}

fn generateSet(alloc: std.mem.Allocator, out: *std.Io.Writer, cb: bool, io: std.Io) !void {
    const json_file = try std.Io.Dir.cwd().openFile(io, "normal.json", .{});
    var json_reader = json_file.reader(io, &.{});
    const contents = try json_reader.interface.allocRemaining(alloc, .limited(100_000_000));
    defer alloc.free(contents);

    const r = try std.json.parseFromSlice(JsonStruct, alloc, contents, .{ .ignore_unknown_fields = true, .parse_numbers = true, .allocate = .alloc_always });
    defer r.deinit();

    try out.print("\n// === {s} ===\n", .{if (cb) "CB-prefixed" else "unprefixed"});

    var map = std.array_hash_map.Auto(usize, Instruction).init(alloc);
    defer map.deinit();

    const instruction_set = if (cb) r.value.cbprefixed else r.value.unprefixed;

    for (instruction_set) |instr| {
        var i = Instruction{
            .name = instr.mnemonic,
            .length = @intFromFloat(instr.bytes),
            .type = .UNIMPLEMENTED,
            .tcycle = @intFromFloat(instr.cycles[0]),
        };
        // Cb prefixed instructions are tagged as 2 bytes long, and 0xCB is tagged as 1 byte long
        // which makes cb prefixed instuctions look like 3 bytes long
        if (cb) {
            i.length -= 1;
        }
        if (instr.cycles.len == 2) {
            // JSON format: cycles[0] = taken cost, cycles[1] = not-taken cost.
            // We store tcycle as the base (not-taken) and alt_tcycle as the
            // extra t-cycles added when the branch is taken.
            i.tcycle = @intFromFloat(instr.cycles[1]);
            i.alt_tcycle = @as(u8, @intFromFloat(instr.cycles[0])) - i.tcycle;
        }

        const inst_type = std.meta.stringToEnum(InstructionMod.InstructionType, instr.mnemonic);
        if (inst_type) |typeEnum| {
            i.type = typeEnum;
        } else {
            if (std.mem.eql(u8, instr.mnemonic, "PREFIX")) {
                i.type = .CB;
            } else if (std.mem.eql(u8, instr.mnemonic, "RLCA")) {
                i.type = .RLC;
                i.leftOperand = .A;
            } else if (std.mem.eql(u8, instr.mnemonic, "RRCA")) {
                i.type = .RRC;
                i.leftOperand = .A;
            } else if (std.mem.eql(u8, instr.mnemonic, "RRA")) {
                i.type = .RR;
                i.leftOperand = .A;
            } else if (std.mem.eql(u8, instr.mnemonic, "RLA")) {
                i.type = .RL;
                i.leftOperand = .A;
            } else if (std.mem.eql(u8, instr.mnemonic, "LDH")) {
                i.type = .LD;
                if (std.mem.eql(u8, instr.opcode, "0xE0") or std.mem.eql(u8, instr.opcode, "0xE2")) {
                    i.offset_left = 0xFF00;
                } else if (std.mem.eql(u8, instr.opcode, "0xF0") or std.mem.eql(u8, instr.opcode, "0xF2")) {
                    i.offset_right = 0xFF00;
                } else {}
            } else {
                std.debug.print("fail: {s}, {s}\n", .{ instr.mnemonic, instr.opcode });
                continue;
            }
        }
        switch (i.type) {
            .RST => {
                i.number = try std.fmt.parseInt(u8, instr.operands.?[0].name.?[1..], 16);
                i.leftOperand = .NUMBER;
            },
            // ret has only a condition
            .RET,
            => {
                if (instr.operands.?.len == 1) {
                    i.condition = std.meta.stringToEnum(
                        InstructionMod.InstructionCondition,
                        instr.operands.?[0].name.?,
                    ) orelse .NONE;
                }
            },
            .JR, .JP, .CALL => {
                if (instr.operands.?.len == 1) {
                    i.leftOperand = std.meta.stringToEnum(
                        InstructionMod.InstructionOperands,
                        instr.operands.?[0].name.?,
                    ) orelse .NONE;
                } else if (instr.operands.?.len == 2) {
                    i.condition = std.meta.stringToEnum(
                        InstructionMod.InstructionCondition,
                        instr.operands.?[0].name.?,
                    ) orelse .NONE;

                    i.leftOperand = std.meta.stringToEnum(
                        InstructionMod.InstructionOperands,
                        instr.operands.?[1].name.?,
                    ) orelse .NONE;
                }
            },

            else => {
                switch (instr.operands.?.len) {
                    0 => {},
                    1 => {
                        if (instr.operands.?[0].increment) |incLeft| {
                            if (incLeft) {
                                i.increment = .LEFT;
                            }
                        }

                        if (instr.operands.?[0].decrement) |decLeft| {
                            if (decLeft) {
                                i.decrement = .LEFT;
                            }
                        }

                        i.leftOperand = std.meta.stringToEnum(
                            InstructionMod.InstructionOperands,
                            instr.operands.?[0].name.?,
                        ) orelse .NONE;
                        if (i.leftOperand == .NONE) {
                            if (std.mem.eql(u8, instr.operands.?[0].name.?, "a8")) {
                                i.rightOperand = .U8;
                            } else {
                                std.debug.print("1fail: {s}, {s}\n", .{ instr.mnemonic, instr.opcode });
                                std.debug.print("1fail: {s}\n", .{instr.operands.?[0].name.?});
                            }
                        }
                        i.leftOperandPointer = !instr.operands.?[0].immediate.?;
                    },
                    2 => {
                        if (instr.operands.?[0].increment) |incLeft| {
                            if (incLeft) {
                                i.increment = .LEFT;
                            }
                        }
                        if (instr.operands.?[1].increment) |incRight| {
                            if (incRight) {
                                i.increment = .RIGHT;
                            }
                        }

                        if (instr.operands.?[0].decrement) |decLeft| {
                            if (decLeft) {
                                i.decrement = .LEFT;
                            }
                        }

                        if (instr.operands.?[1].decrement) |decRight| {
                            if (decRight) {
                                i.decrement = .RIGHT;
                            }
                        }
                        i.leftOperand = std.meta.stringToEnum(
                            InstructionMod.InstructionOperands,
                            instr.operands.?[0].name.?,
                        ) orelse .NONE;
                        if (i.leftOperand == .NONE) {
                            const parsed_nullable = std.fmt.parseInt(u8, instr.operands.?[0].name.?, 10) catch null;
                            if (parsed_nullable) |parsed| {
                                i.leftOperand = .NUMBER;
                                i.number = parsed;
                            } else if (std.mem.eql(u8, instr.operands.?[0].name.?, "a8")) {
                                i.leftOperand = .U8;
                            } else {
                                std.debug.print("2fail: {s}, {s}\n", .{ instr.mnemonic, instr.opcode });
                                std.debug.print("2fail: {s}\n", .{instr.operands.?[0].name.?});
                            }
                        }
                        i.leftOperandPointer = !instr.operands.?[0].immediate.?;

                        i.rightOperand = std.meta.stringToEnum(
                            InstructionMod.InstructionOperands,
                            instr.operands.?[1].name.?,
                        ) orelse .NONE;

                        if (i.rightOperand == .NONE) {
                            std.debug.print("3fail: {s}\n", .{instr.operands.?[1].name.?});
                            if (std.mem.eql(u8, instr.operands.?[1].name.?, "a8")) {
                                i.rightOperand = .U8;
                            } else {
                                std.debug.print("3fail: {s}, {s}\n", .{ instr.mnemonic, instr.opcode });
                                std.debug.print("3fail: {s}\n", .{instr.operands.?[1].name.?});
                            }
                        }
                        i.rightOperandPointer = !instr.operands.?[1].immediate.?;
                    },
                    3 => {
                        //0xF8
                        if (!std.mem.eql(u8, instr.opcode, "0xF8")) {
                            std.debug.print("Unexpected 3 operand operation that is not 0xF8 op: {s}\n", .{instr.opcode});
                            return error.Unexpected3Operands;
                        }

                        i.leftOperand = .HL;
                        i.rightOperandPointer = true;
                        i.rightOperand = .SP;
                    },
                    else => {
                        std.debug.print("\n\n more than 3 operands\n", .{});

                        std.debug.print("{s} {s}", .{ instr.mnemonic, instr.opcode });
                    },
                }
            },
        }

        var flags: ?InstructionMod.InstructionFlagRegister = null;
        if (instr.flags) |flagso| {
            flags = parseFlags(flagso);
            if (flags.?.carry == .UNMODIFED and flags.?.half_carry == .UNMODIFED and flags.?.zero == .UNMODIFED and flags.?.sub == .UNMODIFED) {
                flags = null;
            }
        }
        if (flags != null) {
            i.flags = flags.?;
        }
        const op_code_num = try std.fmt.parseInt(usize, instr.opcode[2..], 16);

        try map.put(op_code_num, i);
    }

    var map_iter = map.iterator();
    while (map_iter.next()) |entry| {
        try dumpDefinition(entry.value_ptr.*, entry.key_ptr.*, cb, out);
    }
    try out.flush();
}

fn parseFlags(f: FlagsO) InstructionMod.InstructionFlagRegister {
    return InstructionMod.InstructionFlagRegister{
        .zero = parseFlag(f.Z),
        .sub = parseFlag(f.N),
        .half_carry = parseFlag(f.H),
        .carry = parseFlag(f.C),
    };
}

fn parseFlag(str: []u8) InstructionMod.InstructionFlag {
    if (std.mem.eql(u8, str, "-")) {
        return InstructionMod.InstructionFlag.UNMODIFED;
    } else if (std.mem.eql(u8, str, "0")) {
        return InstructionMod.InstructionFlag.UNSET;
    } else if (std.mem.eql(u8, str, "1")) {
        return InstructionMod.InstructionFlag.SET;
    } else {
        return InstructionMod.InstructionFlag.DEPENDENT;
    }
}

pub fn dumpDefinition(inst: Instruction, key: usize, cb: bool, out: *std.Io.Writer) !void {
    try out.print("\n\n", .{});
    try out.print("t_instructions[0x{X}] = Instruction{{", .{key});
    // out.print(".name = \"{s}\",", .{inst.name});
    try genereateMnemonic(inst, key, cb, out);
    try out.print(".type = .{t},", .{inst.type});
    if (inst.leftOperand != .NONE) {
        try out.print(".leftOperand = .{t},", .{inst.leftOperand});
    }
    if (inst.leftOperandPointer) {
        try out.print(".leftOperandPointer = true,", .{});
    }

    if (inst.rightOperand != .NONE) {
        try out.print(".rightOperand = .{t},", .{inst.rightOperand});
    }
    if (inst.rightOperandPointer) {
        try out.print(".rightOperandPointer = true,", .{});
    }

    if (inst.condition != .NONE) {
        try out.print(".condition = .{t},", .{inst.condition});
    }

    if (inst.offset_left != 0) {
        try out.print(".offset_left = 0x{X},", .{inst.offset_left});
    }
    if (inst.offset_right != 0) {
        try out.print(".offset_right = 0x{X},", .{inst.offset_right});
    }
    if (inst.number) |n| {
        try out.print(".number = 0x{X},", .{n});
    }
    if (inst.increment != .NONE) {
        try out.print(".increment = .{t},", .{inst.increment});
    }
    if (inst.decrement != .NONE) {
        try out.print(".decrement = .{t},", .{inst.decrement});
    }

    try out.print(".length = {d},", .{inst.length});
    try out.print(".tcycle = {d},", .{inst.tcycle});
    if (inst.alt_tcycle) |t| {
        try out.print(".alt_tcycle = {d},", .{t});
    }
    if (!checkFlagsUnmodified(inst.flags)) {
        try out.print(".flags = {any},", .{inst.flags});
    }
    try out.print("}};", .{});

    try out.print("\n", .{});
    // t_instructions[0xFE] = Instruction{
    //     .name = "CP A,u8 - 0xFE",
    //     .type = .CP,
    //     .leftOperand = .A,
    //     .rightOperand = .U8,
    //     .length = 2,
    //     .tcycle = 2,
    //     .flags = .{
    //         .zero = .DEPENDENT,
    //         .sub = .SET,
    //         .carry = .DEPENDENT,
    //         .half_carry = .DEPENDENT,
    //     },
    // };

}
fn genereateMnemonic(i: Instruction, key: usize, cb: bool, out: *std.Io.Writer) !void {
    try out.print(".name = \"{t} ", .{i.type});
    if (key == 0xF8 and !cb) {
        try out.print("HL,(SP)+i8 - 0x{X}\",", .{key});
        return;
    }

    if (i.condition != .NONE) {
        try out.print("{t}, ", .{i.condition});
    }

    if (i.leftOperand != .NONE) {
        if (i.leftOperandPointer) {
            try out.print("(", .{});
        }
        if (i.offset_left != 0) {
            try out.print("{X}+", .{i.offset_left});
        }
        if (i.leftOperand == .NUMBER) {
            try out.print("{d}", .{i.number.?});
        } else {
            try out.print("{t}", .{i.leftOperand});
        }
        if (i.increment == .LEFT) {
            try out.print("+", .{});
        }
        if (i.decrement == .LEFT) {
            try out.print("-", .{});
        }

        if (i.leftOperandPointer) {
            try out.print(")", .{});
        }

        if (i.rightOperand != .NONE) {
            try out.print(",", .{});
            if (i.rightOperandPointer) {
                try out.print("(", .{});
            }

            if (i.offset_right != 0) {
                try out.print("{X}+", .{i.offset_right});
            }
            try out.print("{t}", .{i.rightOperand});

            if (i.increment == .RIGHT) {
                try out.print("+", .{});
            }
            if (i.decrement == .RIGHT) {
                try out.print("-", .{});
            }
            if (i.rightOperandPointer) {
                try out.print(")", .{});
            }
        }
    }

    try out.print(" - 0x{X}", .{key});

    try out.print("\",", .{});
}

fn checkFlagsUnmodified(f: InstructionMod.InstructionFlagRegister) bool {
    if (f.carry == .UNMODIFED and f.half_carry == .UNMODIFED and f.zero == .UNMODIFED and f.sub == .UNMODIFED) {
        return true;
    }
    return false;
}
