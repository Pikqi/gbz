const std = @import("std");

const Cpu = @import("cpu.zig").Cpu;
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;

pub const DoubleU8Ptr = @import("common.zig").DoubleU8Ptr;

const OperandPtrTag = enum {
    U8, //8bit cpu register or byte ptr in memory
    U8X2, //16bit combined cpu register
    I8, // byte ptr in memory
    U16, // 16bit cpu register PC or SP
    VU8, // 8bit value, needed for RST
    VU16, // 16bit value, needed for CALL
};
const OperandPtr = union(OperandPtrTag) {
    U8: *u8,
    U8X2: DoubleU8Ptr,
    I8: i8,
    U16: *u16,
    VU8: u8,
    VU16: u16,
};

const GetOperandPtrErrors = error{
    OperatorIsNotAPointer,
    U8PtrNoOffset,
};

pub const Emulator = struct {
    cpu: Cpu,
    alloc: std.mem.Allocator,
    mem: []u8,
    pub fn step(self: *Emulator) !void {
        // var sp = &self.cpu.sp;
        const pc = &self.cpu.pc;

        const instruction_byte = self.mem[@intCast(pc.*)];
        var instruction: InstructionsMod.Instruction = undefined;
        var instruction_params = [2]u8{ 0, 0 };

        if (instructions[instruction_byte]) |instr| {
            std.debug.print("{s}\n", .{instr.name});
            instruction = instr;
        } else {
            std.debug.print("{X:02} not defined\n", .{instruction_byte});
            pc.* += 1;
            return;
        }

        if (instruction.length > 1) {
            for (0..instruction.length - 1) |i| {
                pc.* += 1;
                instruction_params[i] = self.mem[pc.*];
            }
        }

        const leftOp = try self.getOperandPtr(true, instruction, instruction_params);
        std.debug.print("left {?}\n", .{leftOp});
        const rightOp = try self.getOperandPtr(false, instruction, instruction_params);
        _ = rightOp; // autofix

        // switch (instruction.type) {
        //     .ADD => {},
        // }

        pc.* += 1;
    }
    fn getOperandPtr(
        self: *Emulator,
        isLeft: bool,
        instruction: InstructionsMod.Instruction,
        instruction_params: [2]u8,
    ) GetOperandPtrErrors!?OperandPtr {
        errdefer instruction.print();
        const operandType = if (isLeft) instruction.leftOperand else instruction.rightOperand;
        if (operandType == .NONE) {
            return null;
        }

        const isPtrToMemory = if (isLeft) instruction.leftOperandPointer else instruction.rightOperandPointer;

        const offset = if (isLeft) instruction.offset_left else instruction.offset_right;
        const has_offset = offset > 0;

        if (operandType == .U8) {
            if (isPtrToMemory and has_offset) {
                return OperandPtr{ .U8 = &self.mem[offset + instruction_params[0]] };
            }
            if (!isPtrToMemory) {
                return OperandPtr{ .VU8 = instruction_params[0] };
            }
            return error.U8PtrNoOffset;
        }

        var op = switch (operandType) {
            .A, .B, .C, .D, .E, .H, .L, .F => OperandPtr{ .U8 = self.cpu.getU8Register(operandType) },

            .PC, .SP => OperandPtr{ .U16 = self.cpu.getU16Register(operandType) },

            .AF, .BC, .DE, .HL => OperandPtr{ .U8X2 = self.cpu.getDoubleU8Register(operandType) },
            .NUMBER => OperandPtr{ .VU8 = instruction.number.? },
            .U16 => {
                // todo: check order
                const value: u16 = @as(u16, @intCast(instruction_params[1])) << 8 & instruction_params[0];
                if (isPtrToMemory) {
                    return OperandPtr{ .U8 = &self.mem[value] };
                }
                return OperandPtr{ .VU16 = value };
            },
            .I8 => {
                return OperandPtr{ .I8 = @bitCast(instruction_params[0]) };
            },

            else => {
                std.log.debug("not handled: operandType {}\n", .{operandType});
                unreachable;
            },
        };
        if (isPtrToMemory) {
            try switch (op) {
                .U16 => {
                    op = OperandPtr{ .U8 = &self.mem[op.U16.*] };
                },
                .VU16 => {
                    op = OperandPtr{ .U8 = &self.mem[op.VU16] };
                },
                .U8X2 => {
                    const value: u16 = @as(u16, @intCast(op.U8X2.upper.*)) << 8 & op.U8X2.upper.*;
                    op = OperandPtr{ .U8 = &self.mem[value] };
                },
                .U8 => {
                    if (has_offset) {
                        op = OperandPtr{ .U8 = &self.mem[op.U8.* + offset] };
                    } else {
                        return error.U8PtrNoOffset;
                    }
                },

                else => error.OperatorIsNotAPointer,
            };
        }

        return op;
    }
};
