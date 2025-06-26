const std = @import("std");

const Cpu = @import("cpu.zig").Cpu;
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;
const implementations = @import("instruction_implementations.zig");

pub const DoubleU8Ptr = @import("common.zig").DoubleU8Ptr;

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

        instruction.print();
        switch (instruction.type) {
            .ADD => try implementations.add(self, instruction, instruction_params),
            .LD => try implementations.ld(self, instruction, instruction_params),
            .JP => try implementations.jp(self, instruction, instruction_params),
            .INC => try implementations.inc(self, instruction, instruction_params),
            else => {
                std.debug.print("not implemented {s}\n", .{@tagName(instruction.type)});
            },
        }

        pc.* += 1;
    }
};
