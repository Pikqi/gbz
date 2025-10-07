const std = @import("std");

const Cpu = @import("cpu.zig").Cpu;
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;
const prefixed_instructions = InstructionsMod.prefixed_instructions;
const implementations = @import("instruction_implementations.zig");
const Allocator = std.mem.Allocator;

pub const DoubleU8Ptr = @import("common").DoubleU8Ptr;

pub const Emulator = struct {
    cpu: Cpu,
    alloc: Allocator,
    mem: []u8,
    cb_prefixed: bool = false,

    pub fn init(alloc: Allocator) !*Emulator {
        const emu = try alloc.create(Emulator);
        emu.cpu = Cpu.init();
        emu.mem = try alloc.alloc(u8, 0xFFF);
        emu.alloc = alloc;

        return emu;
    }
    pub fn deinit(self: *Emulator) void {
        self.alloc.free(self.mem);
        self.alloc.destroy(self);
    }

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

    pub fn cpu_step(self: *Emulator) !void {
        // var sp = &self.cpu.sp;
        if (self.cpu.is_halted) {
            std.log.info("Halted\n", .{});
            return;
        }
        const pc = &self.cpu.pc;

        const instruction_byte = self.mem[@intCast(pc.*)];
        var instruction: InstructionsMod.Instruction = undefined;
        var instruction_params = [2]u8{ 0, 0 };
        const instruction_set = if (self.cb_prefixed) prefixed_instructions else instructions;

        if (instruction_set[instruction_byte]) |instr| {
            // std.debug.print("{s}\n", .{instr.name});
            instruction = instr;
        } else {
            std.log.warn("{X:02} not defined\n", .{instruction_byte});
            pc.* += 1;
            return error.UnkownInstruction;
        }

        if (instruction.length > 1) {
            for (0..instruction.length - 1) |i| {
                pc.* += 1;
                instruction_params[i] = self.mem[pc.*];
            }
        }

        if (self.cb_prefixed) {
            self.cb_prefixed = false;
            return;
        }
        //todo handle 0xF8 edge case
        switch (instruction.type) {
            .NOP => implementations.nop(),
            .STOP => try implementations.stop(),
            .HALT => implementations.halt(self),
            .LD => try implementations.ld(self, instruction, instruction_params),
            .ADD, .ADC => try implementations.add(self, instruction, instruction_params),
            .SUB, .SBC => try implementations.sub(self, instruction, instruction_params),
            .CP => try implementations.cp(self, instruction, instruction_params),
            .CPL => try implementations.cpl(self),
            .JP => try implementations.jp(self, instruction, instruction_params),
            .JR => try implementations.jr(self, instruction, instruction_params),
            .INC => try implementations.inc(self, instruction, instruction_params),
            .DEC => try implementations.dec(self, instruction, instruction_params),
            .DAA => implementations.daa(self),
            .CCF => implementations.ccf(self),
            .PUSH => try implementations.push(self, instruction),
            .POP => try implementations.pop(self, instruction),
            .CALL => try implementations.call(self, instruction, instruction_params),
            .RET => try implementations.ret(self, instruction),
            .RST => try implementations.rst(self, instruction),
            .CB => self.cb_prefixed = true,
            .SCF => try implementations.scf(self),
            .AND => try implementations.andd(self, instruction, instruction_params),
            .XOR => try implementations.xor(self, instruction, instruction_params),
            .OR => try implementations.orr(self, instruction, instruction_params),
            .EI => implementations.ei(self),
            .DI => implementations.di(self),
            .RL, .RLC, .RR, .RRC => try implementations.rotate(self, instruction),
            else => {
                std.log.warn("not implemented {t}\n", .{instruction.type});
            },
        }

        pc.* += 1;
    }
};
