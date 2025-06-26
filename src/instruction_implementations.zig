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

pub fn getOperandValue(emu: *Emulator, left: bool, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) GetOperandValueError!OperandValue {
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

        .U8 => OperandValue{ .U8 = instruction_params[0] },
        .I8 => OperandValue{ .I8 = @bitCast(instruction_params[0]) },

        .U16 => OperandValue{ .U16 = @as(u16, @intCast(instruction_params[1])) << 8 | instruction_params[0] },

        .NUMBER => OperandValue{ .U8 = @intCast(instruction.number.?) },
    };

    if (isPtrToMemory) {
        if (operandType == .U8 and offset == 0) unreachable;

        switch (operandValue) {
            .U8 => {
                operandValue = OperandValue{ .U8 = emu.mem[offset + @as(u16, @intCast(operandValue.U8))] };
            },
            .U16 => {
                operandValue = OperandValue{ .U8 = emu.mem[operandValue.U16] };
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
) GetOperandPtrErrors!OperandPtr {
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
            const value: u16 = @as(u16, @intCast(instruction_params[1])) << 8 & instruction_params[0];
            if (isPtrToMemory) {
                return OperandPtr{ .U8 = &emu.mem[value] };
            }
            unreachable;
        },
        .U8 => {
            const value: u16 = @intCast(instruction_params[1]);
            if (isPtrToMemory and has_offset) {
                return OperandPtr{ .U8 = &emu.mem[offset + value] };
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
                op = OperandPtr{ .U8 = &emu.mem[op.U16.*] };
            },
            .U8 => {
                if (has_offset) {
                    op = OperandPtr{ .U8 = &emu.mem[op.U8.* + offset] };
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

    switch (leftPtr) {
        .U8 => {
            const right: u8 = rightValue.U8;
            const left = leftPtr.U8;
            const leftOld = left.*;

            flags.half_carry = (left.* & 0xF + right & 0xF) > 0xF;

            var of: u1 = 0;
            left.*, of = @addWithOverflow(left.*, right);
            flags.zero = left.* == 0;
            flags.sub = false;
            flags.carry = of > 0;
            std.log.info("Added {X} + {X} = {X}", .{ leftOld, right, left.* });
        },
        .U16 => {
            const left = leftPtr.U16;
            const leftOld = left.*;
            const right = rightValue.U16;

            flags.half_carry = (left.* & 0xF00 + right & 0xF00) > 0xF00;
            var of: u1 = 0;
            left.*, of = @addWithOverflow(left.*, right);
            flags.sub = false;
            flags.carry = of > 0;
            std.log.info("Added {X} + {X} = {X}", .{ leftOld, right, left.* });
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

        emu.mem[param_address] = sp_lower;
        emu.mem[param_address + 1] = sp_upper;
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
            std.log.info("Loaded {X} into {s}", .{ rightValue.U8, @tagName(instruction.leftOperand) });
        },
        .U16 => {
            leftPtr.U16.* = rightValue.U16;
            std.log.info("Loaded {X} into {s}", .{ rightValue.U16, @tagName(instruction.leftOperand) });
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
        emu.cpu.pc = operand.U16;
        // TODO: Increase tcycle
        std.debug.print("Jumped to {X}", .{emu.cpu.pc});
    } else {
        std.debug.print("Did not jump ", .{});
    }
}

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
                var pc: i64 = @intCast(emu.cpu.pc);
                pc += @intCast(operand.I8);
                emu.cpu.pc = @intCast(pc);
                // TODO: Increase tcycle
                std.debug.print("Jumped to {X}\n", .{emu.cpu.pc});
            } else {
                std.debug.print("Did not jump \n", .{});
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
            const half_carry = (value & 0xF + 1) > 0xF;

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
            const new_pc = pc + 1;
            const upper: u8 = @intCast((new_pc & 0xFF00) >> 8);
            const lower: u8 = @intCast(new_pc & 0xFF);
            emu.stackPush(upper, lower);
        },
        else => return error.InvalidOperantType,
    }
    std.debug.print("Called\n", .{});
}
pub fn ret(emu: *Emulator, instruction: InstructionsMod.Instruction) !void {
    const flags = emu.cpu.getFlagsRegister();

    const pc = &emu.cpu.pc;

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
    emu.stackPop(&upper, &lower);

    pc.* = @as(u16, @intCast(upper)) << 8 | lower;
    std.debug.print("Returned\n", .{});
}
