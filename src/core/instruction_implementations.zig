const std = @import("std");

const Emulator = @import("emulator.zig").Emulator;
const InstructionsMod = @import("instructions.zig");

const OperandPtrTag = enum {
    U8, //8bit cpu register or byte ptr in memory
    U16, // 16bit cpu register PC or SP
};

const OperandValueTag = enum {
    U8,
    I8,
    U16,
};

const OperandValue = union(OperandValueTag) {
    U8: u8,
    I8: i8,
    U16: u16,
};

const OperandPtr = union(OperandPtrTag) {
    U8: *u8,
    U16: *u16,
};

const GetOperandPtrErrors = error{
    OperatorIsNotAPointer,
    U8PtrNoOffset,
    NoOperandForInstruction,
};
const GetOperandValueError = error{
    NoOperand,
};

const InstructionError = error{
    OperandProhibited,
};

pub fn getOperandValue(emu: *Emulator, left: bool, instruction: InstructionsMod.Instruction, instruction_params: ?[2]u8) !OperandValue {
    var err: ?GetOperandValueError = null;

    const operandType = if (left) instruction.leftOperand else instruction.rightOperand;
    const offset = if (left) instruction.offset_left else instruction.offset_right;
    const isPtrToMemory = if (left) instruction.leftOperandPointer else instruction.rightOperandPointer;

    var operandValue: OperandValue = switch (operandType) {
        .NONE => {
            err = GetOperandValueError.NoOperand;
            return OperandValue{ .U8 = 0 };
        },
        .A, .B, .C, .D, .E, .F, .H, .L => OperandValue{ .U8 = emu.cpu.getU8Register(operandType).* },

        .AF, .BC, .DE, .HL, .PC, .SP => OperandValue{ .U16 = emu.cpu.getU16Register(operandType).* },

        .U8 => OperandValue{ .U8 = instruction_params.?[0] },
        .I8 => OperandValue{ .I8 = @bitCast(instruction_params.?[0]) },

        .U16 => OperandValue{ .U16 = @as(u16, @intCast(instruction_params.?[1])) << 8 | instruction_params.?[0] },

        .NUMBER => OperandValue{ .U8 = @intCast(instruction.number.?) },
    };

    if (isPtrToMemory) {
        if (operandType == .U8 and offset == 0) unreachable;

        switch (operandValue) {
            .U8 => {
                operandValue = OperandValue{ .U8 = try emu.mem.read(offset + @as(u16, @intCast(operandValue.U8))) };
            },
            .U16 => {
                operandValue = OperandValue{ .U8 = try emu.mem.read(operandValue.U16) };
            },
            .I8 => unreachable,
        }
    }

    if (err) |e| {
        return e;
    }
    return operandValue;
}

pub fn getLeftOperandPtr(
    emu: *Emulator,
    instruction: InstructionsMod.Instruction,
    instruction_params: [2]u8,
) !OperandPtr {
    errdefer instruction.print();
    const operandType = instruction.leftOperand;
    if (operandType == .NONE) {
        return GetOperandPtrErrors.NoOperandForInstruction;
    }

    const isPtrToMemory = instruction.leftOperandPointer;

    const offset = instruction.offset_left;
    const has_offset = offset > 0;

    var op = switch (operandType) {
        .A, .B, .C, .D, .E, .H, .L, .F => OperandPtr{ .U8 = emu.cpu.getU8Register(operandType) },

        .PC, .SP, .AF, .BC, .DE, .HL => OperandPtr{ .U16 = emu.cpu.getU16Register(operandType) },

        .NUMBER => unreachable,
        .U16 => {
            // todo: check order
            const high: u16 = instruction_params[1];
            const low: u16 = instruction_params[0];
            const value: u16 = (high << 8) | low;

            if (isPtrToMemory) {
                return OperandPtr{ .U8 = try emu.mem.readPtr(value) };
            }
            unreachable;
        },
        .U8 => {
            const value: u16 = @intCast(instruction_params[0]);
            if (isPtrToMemory and has_offset) {
                return OperandPtr{ .U8 = try emu.mem.readPtr(offset + value) };
            }
            unreachable;
        },

        else => {
            std.log.debug("not handled: operandType {}\n", .{operandType});
            unreachable;
        },
    };
    if (isPtrToMemory) {
        switch (op) {
            .U16 => {
                op = OperandPtr{ .U8 = try emu.mem.readPtr(op.U16.*) };
            },
            .U8 => {
                if (has_offset) {
                    op = OperandPtr{ .U8 = try emu.mem.readPtr(op.U8.* + offset) };
                } else {
                    return error.U8PtrNoOffset;
                }
            },
        }
    }

    return op;
}

pub fn add(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftPtr = try getLeftOperandPtr(emu, instruction, instruction_params);

    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    const adc = instruction.type == .ADC;
    var carry_set = false;
    switch (leftPtr) {
        .U8 => {
            const right: u8 = rightValue.U8;
            const left = leftPtr.U8;
            var of: u1 = 0;

            if (adc and flags.carry) {
                left.*, of = @addWithOverflow(left.*, 1);
                if (of > 0) {
                    flags.carry = true;
                    carry_set = true;
                }
            }

            flags.half_carry = ((left.* & 0xF) + (right & 0xF)) > 0xF;

            left.*, of = @addWithOverflow(left.*, right);
            flags.zero = left.* == 0;
            flags.sub = false;
            if (!carry_set) {
                flags.carry = of > 0;
            }
        },
        .U16 => {
            // 0xE8
            if (rightValue == .I8) {
                if (rightValue.I8 >= 0) {
                    leftPtr.U16.* +%= @intCast(rightValue.I8);
                } else {
                    var l: i17 = @intCast(leftPtr.U16.*);
                    const r: i17 = @intCast(rightValue.I8);
                    l +%= r;
                    if (l < 0) {
                        l += std.math.maxInt(i17);
                    }
                    leftPtr.U16.* = @intCast(l);
                }
                return;
            }
            const left = leftPtr.U16;
            const right = rightValue.U16;
            var of: u1 = 0;

            if (adc and flags.carry) {
                left.*, of = @addWithOverflow(left.*, 1);
                if (of > 0) {
                    flags.carry = true;
                    carry_set = true;
                }
            }
            if (adc) {
                left.* += if (flags.carry) 1 else 0;
            }

            flags.half_carry = ((left.* & 0xF00) +% (right & 0xF00)) > 0xF00;
            left.*, of = @addWithOverflow(left.*, right);
            flags.sub = false;
            if (!carry_set) {
                flags.carry = of > 0;
            }
        },
    }
}

pub fn sub(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftPtr = try getLeftOperandPtr(emu, instruction, instruction_params);

    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();
    const sbc = instruction.type == .SBC;

    if (instruction.leftOperand != .A) {
        std.debug.print("SUB: left operand is not A", .{});
        return error.OperandProhibited;
    }

    switch (rightValue) {
        .U8 => {},
        else => {
            return error.OperandProhibited;
        },
    }

    switch (leftPtr) {
        .U8 => {
            var carry_set = false;
            var of: u1 = 0;
            if (sbc and flags.carry) {
                leftPtr.U8.*, of = @subWithOverflow(leftPtr.U8.*, 1);
                if (of > 0) {
                    flags.carry = true;
                    carry_set = true;
                }
            }

            const half_carry = ((leftPtr.U8.* & 0xF) -% (rightValue.U8 & 0xF)) > leftPtr.U8.*;

            leftPtr.U8.*, of = @subWithOverflow(leftPtr.U8.*, rightValue.U8);

            flags.half_carry = half_carry;
            flags.zero = leftPtr.U8.* == 0;
            if (!carry_set) {
                flags.carry = of > 0;
            }
            flags.sub = true;
        },

        .U16 => {
            return error.OperandProhibited;
        },
    }
}

pub fn ld(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftPtr = try getLeftOperandPtr(emu, instruction, instruction_params);
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);

    // 0x08
    if (instruction.type == .LD and instruction.leftOperand == .U16 and instruction.leftOperandPointer and instruction.rightOperand == .SP) {
        const sp_lower: u8 = @intCast(emu.cpu.sp & 0xFF);
        const sp_upper: u8 = @intCast((emu.cpu.sp & 0xFF00) >> 8);
        const param_address: u16 = @as(u16, @intCast(instruction_params[1])) << 8 | instruction_params[0];

        try emu.mem.write(param_address, sp_lower);
        try emu.mem.write(param_address + 1, sp_upper);
        return;
    }
    // 0xF8
    if (instruction.leftOperand == .HL and instruction.rightOperand == .SP and instruction.rightOperandPointer == true) {
        std.debug.print("0xF8 btw\n", .{});
        //todo
        const arg: u16 = @intCast(instruction_params[0]);
        emu.cpu.sp += arg;
        return;
    }

    switch (leftPtr) {
        .U8 => {
            const left = leftPtr.U8;
            switch (rightValue) {
                .U8 => {
                    left.* = rightValue.U8;
                },
                else => unreachable,
            }
        },
        .U16 => {
            leftPtr.U16.* = rightValue.U16;
        },
    }

    switch (instruction.increment) {
        .LEFT => {
            emu.cpu.getU16Register(instruction.leftOperand).* += 1;
        },
        .RIGHT => {
            emu.cpu.getU16Register(instruction.rightOperand).* += 1;
        },
        else => {},
    }
    switch (instruction.decrement) {
        .LEFT => {
            emu.cpu.getU16Register(instruction.leftOperand).* -= 1;
        },
        .RIGHT => {
            emu.cpu.getU16Register(instruction.rightOperand).* -= 1;
        },
        else => {},
    }
}

// todo conditionally add ticks
pub fn jp(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const operand = try getOperandValue(emu, true, instruction, instruction_params);
    const condition = instruction.condition;

    const flags = emu.cpu.getFlagsRegister();

    const should_jump = switch (condition) {
        .C => flags.carry,
        .NC => !flags.carry,
        .Z => flags.zero,
        .NZ => !flags.zero,
        .NONE => true,
        else => unreachable,
    };

    if (should_jump) {
        // emu.cpu.pc = operand.U16;
        emu.jump_to = operand.U16;
        // TODO: Increase tcycle
        // std.debug.print("Jumped to {X}", .{emu.cpu.pc});
    } else {
        // std.debug.print("Did not jump ", .{});
    }
}

// todo conditionally add ticks
pub fn jr(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const operand = try getOperandValue(emu, true, instruction, instruction_params);
    const condition = instruction.condition;

    const flags = emu.cpu.getFlagsRegister();

    const should_jump = switch (condition) {
        .C => flags.carry,
        .NC => !flags.carry,
        .Z => flags.zero,
        .NZ => !flags.zero,
        .NONE => true,
        else => unreachable,
    };
    switch (operand) {
        .I8 => {
            if (should_jump) {
                const pc: i64 = @intCast(emu.cpu.pc);
                emu.jump_to = @intCast(pc + instruction.length + @as(i64, @intCast(operand.I8)));
                // TODO: Increase tcycle
                // std.debug.print("Jumped to {X}\n", .{emu.cpu.pc});
            } else {
                // std.debug.print("Did not jump \n", .{});
            }
        },
        else => {
            std.debug.print("{s}\n", .{@tagName(operand)});
            return error.InvalidOperantType;
        },
    }
}

pub fn inc(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const operand = try getLeftOperandPtr(emu, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    switch (operand) {
        .U8 => {
            const value = operand.U8.*;
            var of: u1 = 0;
            const half_carry = ((value & 0xF) +% 1) > 0xF;

            operand.U8.*, of = @addWithOverflow(operand.U8.*, 1);

            if (instruction.flags.half_carry == .DEPENDENT) {
                flags.half_carry = half_carry;
            }
            if (instruction.flags.zero == .DEPENDENT) {
                flags.zero = operand.U8.* == 0;
            }
        },

        .U16 => {
            operand.U16.*, _ = @addWithOverflow(operand.U16.*, 1);
        },
    }
}
pub fn dec(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const operand = try getLeftOperandPtr(emu, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    switch (operand) {
        .U8 => {
            var of: u1 = 0;

            const half_carry = ((operand.U8.* & 0xF) -% 1) == 0xFF;

            operand.U8.*, of = @subWithOverflow(operand.U8.*, 1);

            if (instruction.flags.half_carry == .DEPENDENT) {
                flags.half_carry = half_carry;
            }
            if (instruction.flags.zero == .DEPENDENT) {
                flags.zero = operand.U8.* == 0;
            }
        },

        .U16 => {
            operand.U16.*, _ = @subWithOverflow(operand.U16.*, 1);
        },
    }
}

// todo conditionally add ticks
pub fn call(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const operand = try getOperandValue(emu, true, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    const pc = emu.cpu.pc;

    const should_jump = switch (instruction.condition) {
        .C => flags.carry,
        .NC => !flags.carry,
        .Z => flags.zero,
        .NZ => !flags.zero,
        .NONE => true,
        else => unreachable,
    };

    if (!should_jump) {
        return;
    }

    switch (operand) {
        .U16 => {
            // TODO make emu.pushPCToStack()
            const new_pc = pc + instruction.length;
            const upper: u8 = @intCast((new_pc & 0xFF00) >> 8);
            const lower: u8 = @intCast(new_pc & 0xFF);
            try emu.stackPush(upper, lower);
            emu.jump_to = operand.U16;
        },
        else => return error.InvalidOperantType,
    }
}

// todo conditionally add ticks
pub fn ret(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const flags = emu.cpu.getFlagsRegister();

    const should_ret = switch (instruction.condition) {
        .C => flags.carry,
        .NC => !flags.carry,
        .Z => flags.zero,
        .NZ => !flags.zero,
        .NONE => true,
        else => unreachable,
    };

    if (!should_ret) {
        return;
    }

    var upper: u8 = undefined;
    var lower: u8 = undefined;
    try emu.stackPop(&upper, &lower);

    emu.jump_to = @as(u16, @intCast(upper)) << 8 | lower;
    // std.debug.print("Returned\n", .{});
}

pub fn andd(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftValue = try getOperandValue(emu, true, instruction, instruction_params);
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    const A = emu.cpu.getU8Register(.A);

    if (leftValue != .U8 or rightValue != .U8) {
        std.debug.print("AND: left or right op are not u8", .{});
        return error.OperandProhibited;
    }

    A.* = leftValue.U8 & rightValue.U8;
    flags.zero = A.* == 0;
}

pub fn orr(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    const A = emu.cpu.getU8Register(.A);

    if (rightValue != .U8) {
        std.debug.print("OR: left or right op are not u8", .{});
        return error.OperandProhibited;
    }

    A.* |= rightValue.U8;

    flags.zero = A.* == 0;
}

pub fn xor(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftValue = try getOperandValue(emu, true, instruction, instruction_params);
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    const A = emu.cpu.getU8Register(.A);

    if (leftValue != .U8 or rightValue != .U8) {
        std.debug.print("XOR: left or right op are not u8", .{});
        return error.OperandProhibited;
    }

    A.* = leftValue.U8 ^ rightValue.U8;
    flags.zero = A.* == 0;
}

pub fn scf(emu: *Emulator) !void {
    const flags = emu.cpu.getFlagsRegister();

    flags.sub = false;
    flags.half_carry = false;
    flags.carry = true;
}

pub fn cp(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftValue = try getOperandValue(emu, true, instruction, instruction_params);
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    if (instruction.leftOperand != .A) {
        std.debug.print("CP: left operand is not A", .{});
        return error.OperandProhibited;
    }

    switch (rightValue) {
        .U8 => {},
        else => {
            return error.OperandProhibited;
        },
    }

    switch (leftValue) {
        .U8 => {
            var of: u1 = 0;
            var new_value: u8 = 0;

            new_value, of = @subWithOverflow(leftValue.U8, rightValue.U8);

            const half_carry = ((leftValue.U8 & 0xF) -% (rightValue.U8 & 0xF)) > leftValue.U8;

            flags.carry = new_value > leftValue.U8;
            flags.zero = leftValue.U8 == rightValue.U8;
            flags.half_carry = half_carry;
        },

        else => {
            return error.OperandProhibited;
        },
    }
}
pub fn cpl(emu: *Emulator) !void {
    const A = emu.cpu.getU8Register(.A);
    const flags = emu.cpu.getFlagsRegister();

    A.* = ~A.*;

    flags.half_carry = true;
    flags.sub = true;
}

pub fn nop() void {
    // nop
}

//todo check
pub fn stop(emu: *Emulator) void {
    std.debug.print("stop instruction", .{});
    emu.is_stopped = true;
}

pub fn halt(emu: *Emulator) void {
    emu.cpu.is_halted = true;
    std.debug.print("Halted", .{});
}

pub fn daa(emu: *Emulator) void {
    const a = emu.cpu.getU8Register(.A);
    const flags = emu.cpu.getFlagsRegister();

    var offset: u8 = 0;
    if ((!flags.sub and a.* & 0xF > 0x9) or flags.half_carry) {
        offset |= 0x06;
    }

    if ((!flags.sub and a.* > 0x99) or flags.carry) {
        offset |= 0x60;
        flags.carry = true;
    }

    var of: u1 = 0;
    if (flags.sub) {
        a.*, of = @subWithOverflow(a.*, offset);
    } else {
        a.*, of = @addWithOverflow(a.*, offset);
    }
    flags.zero = a.* == 0;
}

pub fn ccf(emu: *Emulator) void {
    emu.cpu.getFlagsRegister().carry = !emu.cpu.getFlagsRegister().carry;
}

pub fn push(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    // hack to not push
    emu.cpu.getFlagsRegister().rest = 0;
    const operand = try getOperandValue(emu, true, instruction, null);

    switch (operand) {
        .U16 => {
            const upper: u8 = @intCast((operand.U16 & 0xFF00) >> 8);
            const lower: u8 = @intCast(operand.U16 & 0xFF);
            try emu.stackPush(upper, lower);
        },
        else => return error.InvalidOperantType,
    }
}
pub fn pop(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const operand = try getLeftOperandPtr(emu, instruction, .{ 0, 0 });

    switch (operand) {
        .U16 => {
            var upper: u8 = undefined;
            var lower: u8 = undefined;
            try emu.stackPop(&upper, &lower);
            const whole: u16 = @as(u16, @intCast(upper)) << 8 | lower;
            operand.U16.* = whole;
        },
        else => return error.InvalidOperantType,
    }
}
pub fn rst(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const operand = try getOperandValue(emu, true, instruction, .{ 0, 0 });

    const pc = &emu.cpu.pc;

    switch (operand) {
        .U8 => {
            const upper: u8 = @intCast((pc.* & 0xFF00) >> 8);
            const lower: u8 = @intCast(pc.* & 0xFF);
            try emu.stackPush(upper, lower);
            // TODO not sure about this
            emu.jump_to = operand.U8;
        },
        else => return error.InvalidOperantType,
    }
}
pub fn ei(emu: *Emulator) void {
    _ = emu; // autofix
    std.debug.print("stop because ei\n", .{});
    // stop(emu);
    //todo interupts
}
pub fn di(emu: *Emulator) void {
    _ = emu; // autofix
    std.debug.print("stop because di\n", .{});
    // stop(emu);
    //todo interupts
}

pub fn rotate(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const flags = emu.cpu.getFlagsRegister();

    const leftPtr = try getLeftOperandPtr(emu, instruction, .{ 0, 0 });
    if (leftPtr != .U8) {
        return;
    }
    const prev_carry = @intFromBool(flags.carry);
    const operand = leftPtr.U8;
    const b0: u1 = @intCast(operand.* & 0b1);
    const b7: u1 = @intCast(operand.* >> 7);

    switch (instruction.type) {
        .RL => {
            operand.*, _ = @shlWithOverflow(operand.*, 1);
            operand.* |= b7;
        },
        .RLC => {
            operand.*, _ = @shlWithOverflow(operand.*, 1);
            operand.* |= b7;
            flags.carry = b7 > 0;
        },
        .RR => {
            operand.* >>= 1;
            operand.* |= (@as(u8, @intCast(prev_carry)) << 7);
            flags.carry = b0 > 0;
        },
        .RRC => {
            operand.* >>= 1;
            flags.carry = b0 > 0;
            flags.carry = b0 > 0;
        },
        else => {
            return error.OperandProhibited;
        },
    }
    flags.zero = operand.* == 0;
}

pub fn sla(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const flags = emu.cpu.getFlagsRegister();

    const leftPtr = try getLeftOperandPtr(emu, instruction, .{ 0, 0 });
    if (leftPtr != .U8) {
        return error.OperatorIsNotAPointer;
    }
    const operand = leftPtr.U8;

    operand.*, const of = @shlWithOverflow(operand.*, 1);
    flags.carry = of == 1;
    flags.zero = operand.* == 0;
}

pub fn sra(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const flags = emu.cpu.getFlagsRegister();

    const leftPtr = try getLeftOperandPtr(emu, instruction, .{ 0, 0 });
    if (leftPtr != .U8) {
        return error.OperatorIsNotAPointer;
    }
    const operand = leftPtr.U8;
    const highest_bit = operand.* | (1 << 7);
    const lowest_bit = operand.* | 1;

    operand.* >>= 1;
    operand.* &= highest_bit;

    flags.carry = lowest_bit > 0;
    flags.zero = operand.* == 0;
}

pub fn srl(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const flags = emu.cpu.getFlagsRegister();

    const leftPtr = try getLeftOperandPtr(emu, instruction, .{ 0, 0 });
    if (leftPtr != .U8) {
        return error.OperatorIsNotAPointer;
    }
    const operand = leftPtr.U8;
    const lowest_bit = operand.* & 1;

    operand.* >>= 1;

    flags.carry = lowest_bit > 0;
    flags.zero = operand.* == 0;
}

pub fn bit(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftValue = try getOperandValue(emu, true, instruction, instruction_params);
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);
    const flags = emu.cpu.getFlagsRegister();

    if (leftValue != .U8 or rightValue != .U8) {
        std.log.err("BIT Operand not u8", .{});
        return error.OperandProhibited;
    }

    if (leftValue.U8 > 7) {
        std.log.err("BIT Operand > 7", .{});
        return error.OperandProhibited;
    }
    const selection_bit: u8 = @as(u8, 1) << @intCast(leftValue.U8);
    const b: u8 = rightValue.U8 & selection_bit;
    flags.zero = b == 0;
}

pub fn swap(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const operand_ptr = try getLeftOperandPtr(emu, instruction, .{ 0, 0 });
    const flags = emu.cpu.getFlagsRegister();

    if (operand_ptr != .U8) {
        std.log.err("SWAP Operand not u8", .{});
        return error.OperandProhibited;
    }
    const value = operand_ptr.U8;
    const lower: u8 = value.* & 0b1111;
    const higher: u8 = value.* & (0b1111 << 4);
    const new = (lower << 4) | higher >> 4;

    value.* = new;
    flags.*.zero = operand_ptr.U8.* == 0;
}

pub fn res(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftValue = try getOperandValue(emu, true, instruction, instruction_params);

    var right_value_ptr: *u8 = undefined;
    // if its a ptr to memory then it must be (HL)
    if (instruction.rightOperandPointer) {
        right_value_ptr = try emu.mem.readPtr(emu.cpu.getU16Register(.HL).*);
    } else {
        right_value_ptr = emu.cpu.getU8Register(instruction.rightOperand);
    }

    if (leftValue != .U8) {
        std.log.err("RES Operand not u8", .{});
        return error.OperandProhibited;
    }

    if (leftValue.U8 > 7) {
        std.log.err("RES Operand > 7", .{});
        return error.OperandProhibited;
    }
    const selection_bit: u8 = @as(u8, 1) << @intCast(leftValue.U8);

    var mask: u8 = 0xFF;
    mask ^= selection_bit;
    right_value_ptr.* &= mask;
}

pub fn set(emu: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
    const leftValue = try getOperandValue(emu, true, instruction, instruction_params);
    const rightValue = try getOperandValue(emu, false, instruction, instruction_params);

    var right_value_ptr: *u8 = undefined;
    if (instruction.rightOperandPointer) {
        right_value_ptr = try emu.mem.readPtr(emu.cpu.getU16Register(.HL).*);
    } else {
        right_value_ptr = emu.cpu.getU8Register(instruction.rightOperand);
    }

    if (leftValue != .U8 or rightValue != .U8) {
        std.log.err("SET Operand not u8", .{});
        return error.OperandProhibited;
    }

    if (leftValue.U8 > 7) {
        std.log.err("SET Operand > 7", .{});
        return error.OperandProhibited;
    }
    const selection_bit: u8 = @as(u8, 1) << @intCast(leftValue.U8);

    right_value_ptr.* |= selection_bit;
}
