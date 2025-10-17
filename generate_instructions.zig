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

const cb = false;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const json_file = try std.fs.cwd().openFile("normal.json", .{});

    const contents = try json_file.readToEndAlloc(alloc, 100000000);
    defer alloc.free(contents);

    const r = try std.json.parseFromSlice(JsonStruct, alloc, contents, .{ .ignore_unknown_fields = true, .parse_numbers = true, .allocate = .alloc_always });
    defer r.deinit();

    var map = std.AutoArrayHashMap(usize, Instruction).init(alloc);
    defer map.deinit();

    const instruction_set = if (cb) r.value.cbprefixed else r.value.unprefixed;

    for (instruction_set) |instr| {
        var i = Instruction{
            .name = instr.mnemonic,
            .length = @intFromFloat(instr.bytes),
            .type = .UNIMPLEMENTED,
            .tcycle = @intFromFloat(instr.cycles[0] / 4),
        };
        // Cb prefixed instructions are tagged as 2 bytes long, and 0xCB is tagged as 1 byte long
        // which makes cb prefixed instuctions look like 3 bytes long
        if (cb) {
            i.length -= 1;
        }
        if (instr.cycles.len == 2) {
            i.alt_tcycle = @intFromFloat(instr.cycles[1] / 4);
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
        dumpDefinition(entry.value_ptr.*, entry.key_ptr.*);
    }
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

pub fn dumpDefinition(inst: Instruction, key: usize) void {
    std.debug.print("\n\n", .{});
    std.debug.print("t_instructions[0x{X}] = Instruction{{", .{key});
    // std.debug.print(".name = \"{s}\",", .{inst.name});
    genereateMnemonic(inst, key);
    std.debug.print(".type = .{t},", .{inst.type});
    if (inst.leftOperand != .NONE) {
        std.debug.print(".leftOperand = .{t},", .{inst.leftOperand});
    }
    if (inst.leftOperandPointer) {
        std.debug.print(".leftOperandPointer = true,", .{});
    }

    if (inst.rightOperand != .NONE) {
        std.debug.print(".rightOperand = .{t},", .{inst.rightOperand});
    }
    if (inst.rightOperandPointer) {
        std.debug.print(".rightOperandPointer = true,", .{});
    }

    if (inst.condition != .NONE) {
        std.debug.print(".condition = .{t},", .{inst.condition});
    }

    if (inst.offset_left != 0) {
        std.debug.print(".offset_left = 0x{X},", .{inst.offset_left});
    }
    if (inst.offset_right != 0) {
        std.debug.print(".offset_right = 0x{X},", .{inst.offset_right});
    }
    if (inst.number) |n| {
        std.debug.print(".number = 0x{X},", .{n});
    }
    if (inst.increment != .NONE) {
        std.debug.print(".increment = .{t},", .{inst.increment});
    }
    if (inst.decrement != .NONE) {
        std.debug.print(".decrement = .{t},", .{inst.decrement});
    }

    std.debug.print(".length = {d},", .{inst.length});
    std.debug.print(".tcycle = {d},", .{inst.tcycle});
    if (inst.alt_tcycle) |t| {
        std.debug.print(".alt_tcycle = {d},", .{t});
    }
    if (!checkFlagsUnmodified(inst.flags)) {
        std.debug.print(".flags = {any},", .{inst.flags});
    }
    std.debug.print("}};", .{});

    std.debug.print("\n", .{});
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
fn genereateMnemonic(i: Instruction, key: usize) void {
    std.debug.print(".name = \"{t} ", .{i.type});
    if (key == 0xF8 and !cb) {
        std.debug.print("HL,(SP)+i8 - 0x{X}\",", .{key});
        return;
    }

    if (i.condition != .NONE) {
        std.debug.print("{t}, ", .{i.condition});
    }

    if (i.leftOperand != .NONE) {
        if (i.leftOperandPointer) {
            std.debug.print("(", .{});
        }
        if (i.offset_left != 0) {
            std.debug.print("{X}+", .{i.offset_left});
        }
        if (i.leftOperand == .NUMBER) {
            std.debug.print("{d}", .{i.number.?});
        } else {
            std.debug.print("{t}", .{i.leftOperand});
        }
        if (i.increment == .LEFT) {
            std.debug.print("+", .{});
        }
        if (i.decrement == .LEFT) {
            std.debug.print("-", .{});
        }

        if (i.leftOperandPointer) {
            std.debug.print(")", .{});
        }

        if (i.rightOperand != .NONE) {
            std.debug.print(",", .{});
            if (i.rightOperandPointer) {
                std.debug.print("(", .{});
            }

            if (i.offset_right != 0) {
                std.debug.print("{X}+", .{i.offset_right});
            }
            std.debug.print("{t}", .{i.rightOperand});

            if (i.increment == .RIGHT) {
                std.debug.print("+", .{});
            }
            if (i.decrement == .RIGHT) {
                std.debug.print("-", .{});
            }
            if (i.rightOperandPointer) {
                std.debug.print(")", .{});
            }
        }
    }

    std.debug.print(" - 0x{X}", .{key});

    std.debug.print("\",", .{});
}

fn checkFlagsUnmodified(f: InstructionMod.InstructionFlagRegister) bool {
    if (f.carry == .UNMODIFED and f.half_carry == .UNMODIFED and f.zero == .UNMODIFED and f.sub == .UNMODIFED) {
        return true;
    }
    return false;
}
