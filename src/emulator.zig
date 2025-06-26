const std = @import("std");

const Cpu = @import("cpu.zig").Cpu;
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;

pub const DoubleU8Ptr = @import("common.zig").DoubleU8Ptr;

const OperandPtrTag = enum {
    U8, //8bit cpu register or byte ptr in memory
    U16, // 16bit cpu register PC or SP
};
const OperandPtr = union(OperandPtrTag) {
    U8: *u8,
    U16: *u16,
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

        const leftOp = try self.getLeftOperandPtr(instruction, instruction_params);
        std.debug.print("left {?}\n", .{leftOp});
        const rightOp = try self.getOperandValue(false, instruction, instruction_params);
        std.debug.print("right {d}\n", .{rightOp});

        pc.* += 1;
    }

    const GetOperandValueEror = error{
        NoOperand,
    };

    fn getOperandValue(self: *Emulator, left: bool, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) GetOperandValueEror!u16 {
        var err: ?GetOperandValueEror = null;

        const operandType = if (left) instruction.leftOperand else instruction.rightOperand;
        const offset = if (left) instruction.offset_left else instruction.offset_right;
        const isPtrToMemory = if (left) instruction.leftOperandPointer else instruction.rightOperandPointer;

        var operandValue: u16 = switch (operandType) {
            .NONE => {
                err = GetOperandValueEror.NoOperand;
                return 0;
            },
            .A, .B, .C, .D, .E, .F, .H, .L => @intCast(self.cpu.getU8Register(operandType).*),

            .AF, .BC, .DE, .HL, .PC, .SP => self.cpu.getU16Register(operandType).*,

            .U8, .I8 => @intCast(instruction_params[0]),

            .U16 => @as(u16, @intCast(instruction_params[1])) << 8 | instruction_params[0],

            .NUMBER => @intCast(instruction.number.?),
        };

        if (isPtrToMemory) {
            if (operandType == .U8 and offset == 0) unreachable;
            operandValue = self.mem[offset + operandValue];
        }

        if (err) |e| {
            return e;
        }
        return operandValue;
    }

    fn getLeftOperandPtr(
        self: *Emulator,
        instruction: InstructionsMod.Instruction,
        instruction_params: [2]u8,
    ) GetOperandPtrErrors!?OperandPtr {
        errdefer instruction.print();
        const operandType = instruction.leftOperand;
        if (operandType == .NONE) {
            return null;
        }

        const isPtrToMemory = instruction.leftOperandPointer;

        const offset = instruction.offset_left;
        const has_offset = offset > 0;

        var op = switch (operandType) {
            .A, .B, .C, .D, .E, .H, .L, .F => OperandPtr{ .U8 = self.cpu.getU8Register(operandType) },

            .PC, .SP, .AF, .BC, .DE, .HL => OperandPtr{ .U16 = self.cpu.getU16Register(operandType) },

            .NUMBER => unreachable,
            .U16 => {
                // todo: check order
                const value: u16 = @as(u16, @intCast(instruction_params[1])) << 8 & instruction_params[0];
                if (isPtrToMemory) {
                    return OperandPtr{ .U8 = &self.mem[value] };
                }
                unreachable;
            },
            .U8 => {
                const value: u16 = @intCast(instruction_params[1]);
                if (isPtrToMemory and has_offset) {
                    return OperandPtr{ .U8 = &self.mem[offset + value] };
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
                    op = OperandPtr{ .U8 = &self.mem[op.U16.*] };
                },
                .U8 => {
                    if (has_offset) {
                        op = OperandPtr{ .U8 = &self.mem[op.U8.* + offset] };
                    } else {
                        return error.U8PtrNoOffset;
                    }
                },
            }
        }

        return op;
    }
};
