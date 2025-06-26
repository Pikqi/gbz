const std = @import("std");

const Cpu = @import("cpu.zig").Cpu;
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;

pub const DoubleU8Ptr = @import("common.zig").DoubleU8Ptr;

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
            // std.debug.print("{s}\n", .{instr.name});
            instruction = instr;
        } else {
            // std.debug.print("{X:02} not defined\n", .{instruction_byte});
            pc.* += 1;
            return;
        }

        if (instruction.length > 1) {
            for (0..instruction.length - 1) |i| {
                pc.* += 1;
                instruction_params[i] = self.mem[pc.*];
            }
        }

        // const leftOp = try self.getLeftOperandPtr(instruction, instruction_params);
        // std.debug.print("left {?}\n", .{leftOp});
        // const rightOp = try self.getOperandValue(false, instruction, instruction_params);
        // std.debug.print("right {d}\n", .{rightOp});

        switch (instruction.type) {
            .ADD => try self.add(instruction, instruction_params),
            .LD => try self.ld(instruction, instruction_params),
            else => {
                std.debug.print("not implemented {s}\n", .{@tagName(instruction.type)});
            },
        }

        pc.* += 1;
    }

    fn ld(self: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
        instruction.print();
        const leftPtr = try self.getLeftOperandPtr(instruction, instruction_params);
        const rightValue = try self.getOperandValue(false, instruction, instruction_params);

        // 0x08
        if (instruction.type == .LD and instruction.leftOperand == .U16 and instruction.leftOperandPointer and instruction.rightOperand == .SP) {
            const sp_lower: u8 = @intCast(self.cpu.sp & 0xFF);
            const sp_upper: u8 = @intCast((self.cpu.sp & 0xFF00) >> 8);
            const param_address: u16 = @as(u16, @intCast(instruction_params[1])) << 8 | instruction_params[0];

            self.mem[param_address] = sp_lower;
            self.mem[param_address + 1] = sp_upper;
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
                self.cpu.getU16Register(instruction.leftOperand).* += 1;
            },
            .RIGHT => {
                self.cpu.getU16Register(instruction.rightOperand).* += 1;
            },
            else => {},
        }
        switch (instruction.decrement) {
            .LEFT => {
                self.cpu.getU16Register(instruction.leftOperand).* -= 1;
            },
            .RIGHT => {
                self.cpu.getU16Register(instruction.rightOperand).* -= 1;
            },
            else => {},
        }
    }
    fn add(self: *Emulator, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
        const leftPtr = try self.getLeftOperandPtr(instruction, instruction_params);

        const rightValue = try self.getOperandValue(false, instruction, instruction_params);
        const flags = self.cpu.getFlagsRegister();

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

    fn getOperandValue(self: *Emulator, left: bool, instruction: InstructionsMod.Instruction, instruction_params: [2]u8) GetOperandValueError!OperandValue {
        var err: ?GetOperandValueError = null;

        const operandType = if (left) instruction.leftOperand else instruction.rightOperand;
        const offset = if (left) instruction.offset_left else instruction.offset_right;
        const isPtrToMemory = if (left) instruction.leftOperandPointer else instruction.rightOperandPointer;

        var operandValue: OperandValue = switch (operandType) {
            .NONE => {
                err = GetOperandValueError.NoOperand;
                return OperandValue{ .U8 = 0 };
            },
            .A, .B, .C, .D, .E, .F, .H, .L => OperandValue{ .U8 = self.cpu.getU8Register(operandType).* },

            .AF, .BC, .DE, .HL, .PC, .SP => OperandValue{ .U16 = self.cpu.getU16Register(operandType).* },

            .U8, .I8 => OperandValue{ .U8 = @intCast(instruction_params[0]) },

            .U16 => OperandValue{ .U16 = @as(u16, @intCast(instruction_params[1])) << 8 | instruction_params[0] },

            .NUMBER => OperandValue{ .U8 = @intCast(instruction.number.?) },
        };

        if (isPtrToMemory) {
            if (operandType == .U8 and offset == 0) unreachable;

            switch (operandValue) {
                .U8 => {
                    operandValue = OperandValue{ .U8 = self.mem[offset + @as(u16, @intCast(operandValue.U8))] };
                },
                .U16 => {
                    operandValue = OperandValue{ .U8 = self.mem[operandValue.U16] };
                },
                .I8 => unreachable,
            }
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
