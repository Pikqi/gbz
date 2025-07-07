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
    cb_prefixed: bool = false,

    pub fn stackPush(self: *Emulator, upper: u8, lower: u8) void {
        const sp = &self.cpu.sp;
        sp.* -= 1;
        self.mem[sp.*] = upper;
        sp.* -= 1;
        self.mem[sp.*] = lower;
    }

    pub fn stackPop(self: *Emulator, upper: *u8, lower: *u8) void {
        const sp = &self.cpu.sp;
        lower.* = self.mem[sp.*];
        sp.* += 1;
        upper.* = self.mem[sp.*];
        sp.* += 1;
    }

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

        // std.debug.print("\n\n", .{});
        // instruction.print();
        // std.debug.print("\n\n", .{});

        if (self.cb_prefixed) {
            std.debug.print("Please implement CB :)\n", .{});
            self.cb_prefixed = false;
            pc.* += 2;
            return;
        }
        instruction.print_short();

        switch (instruction.type) {
            .LD => try implementations.ld(self, instruction, instruction_params),
            .ADD, .ADC => try implementations.add(self, instruction, instruction_params),
            .SUB, .SBC => try implementations.sub(self, instruction, instruction_params),
            .CP => try implementations.cp(self, instruction, instruction_params),
            .CPL => try implementations.cpl(self),
            .JP => try implementations.jp(self, instruction, instruction_params),
            .JR => try implementations.jr(self, instruction, instruction_params),
            .INC => try implementations.inc(self, instruction, instruction_params),
            .DEC => try implementations.dec(self, instruction, instruction_params),
            .CALL => try implementations.call(self, instruction, instruction_params),
            .RET => try implementations.ret(self, instruction),
            .CB => self.cb_prefixed = true,
            .SCF => try implementations.scf(self),
            .AND => try implementations.andd(self, instruction, instruction_params),
            .XOR => try implementations.xor(self, instruction, instruction_params),
            .OR => try implementations.orr(self, instruction, instruction_params),
            else => {
                std.debug.print("not implemented {s}\n", .{@tagName(instruction.type)});
            },
        }

        pc.* += 1;
    }
};
