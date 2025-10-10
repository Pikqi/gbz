const std = @import("std");

const Cpu = @import("cpu.zig").Cpu;
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;
const prefixed_instructions = InstructionsMod.prefixed_instructions;
const implementations = @import("instruction_implementations.zig");
const DoctorLogger = @import("doctor.zig").DoctorLogger;

pub const DoubleU8Ptr = @import("common").DoubleU8Ptr;

pub const Emulator = struct {
    cpu: Cpu,
    mem: [0xFFFF]u8 = undefined,
    cb_prefixed: bool = false,
    doctor: ?DoctorLogger = null,
    is_stopped: bool = false,
    has_jumped: bool = false,

    pub fn initZero() Emulator {
        return Emulator{
            .cpu = Cpu.initZero(),
        };
    }

    pub fn initBootRom() Emulator {
        var emu = Emulator{
            .cpu = Cpu.initBootRom(),
        };
        emu.mem[0xFF44] = 0x90;
        return emu;
    }
    pub fn initDoctorStdOut(self: *Emulator) !void {
        if (self.doctor != null) {
            return error.DoctorAlreadyExists;
        }
        self.doctor = DoctorLogger.initStdOut(self);
    }

    pub fn initDoctorFile(self: *Emulator, file_path: []const u8) !void {
        if (self.doctor != null) {
            return error.DoctorAlreadyExists;
        }
        self.doctor = try DoctorLogger.initWithFile(self, file_path);
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

    pub fn load_rom(self: *Emulator, rom: []const u8) !void {
        if (rom.len > self.mem.len - 0x100) {
            return error.ROMTooBig;
        }
        @memcpy(self.mem[0..rom.len], rom);
    }

    pub fn run_emu(self: *Emulator) !void {
        while (!self.is_stopped) {
            try self.cpu_step();
        }
    }

    pub fn cpu_step(self: *Emulator) !void {
        // var sp = &self.cpu.sp;
        if (self.cpu.is_halted) {
            std.log.info("Halted\n", .{});
            return;
        }
        const pc = &self.cpu.pc;
        if (pc.* >= self.mem.len) {
            std.debug.print("pc overflow", .{});
            return;
        }

        const instruction_byte = self.mem[@intCast(pc.*)];
        var instruction: InstructionsMod.Instruction = undefined;
        var instruction_params = [2]u8{ 0, 0 };
        const instruction_set = if (self.cb_prefixed) prefixed_instructions else instructions;

        if (instruction_set[instruction_byte]) |instr| {
            std.debug.print("{s}\n", .{instr.name});
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
        self.has_jumped = false;
        //todo handle 0xF8 edge case
        try invokeInstruction(self, instruction, instruction_params);

        if (self.doctor) |*doc| {
            if (instruction.type != .CB) {
                doc.log() catch |e| {
                    std.debug.print("Logging with doctor failed {t}", .{e});
                };
            }
        }
        if (!self.has_jumped) {
            pc.* += 1;
        }
    }
    fn invokeInstruction(self: *Emulator, i: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
        return switch (i.type) {
            .NOP => implementations.nop(),
            .STOP => try implementations.stop(self),
            .HALT => implementations.halt(self),
            .LD => try implementations.ld(self, i, instruction_params),
            .ADD, .ADC => try implementations.add(self, i, instruction_params),
            .SUB, .SBC => try implementations.sub(self, i, instruction_params),
            .CP => try implementations.cp(self, i, instruction_params),
            .CPL => try implementations.cpl(self),
            .JP => try implementations.jp(self, i, instruction_params),
            .JR => try implementations.jr(self, i, instruction_params),
            .INC => try implementations.inc(self, i, instruction_params),
            .DEC => try implementations.dec(self, i, instruction_params),
            .DAA => implementations.daa(self),
            .CCF => implementations.ccf(self),
            .PUSH => try implementations.push(self, i),
            .POP => try implementations.pop(self, i),
            .CALL => try implementations.call(self, i, instruction_params),
            .RET => try implementations.ret(self, i),
            .RST => try implementations.rst(self, i),
            .CB => self.cb_prefixed = true,
            .SCF => try implementations.scf(self),
            .AND => try implementations.andd(self, i, instruction_params),
            .XOR => try implementations.xor(self, i, instruction_params),
            .OR => try implementations.orr(self, i, instruction_params),
            .EI => implementations.ei(self),
            .DI => implementations.di(self),
            .RL, .RLC, .RR, .RRC => try implementations.rotate(self, i),
            .SLA => try implementations.sla(self, i),
            .SRA => try implementations.sra(self, i),
            .BIT => try implementations.bit(self, i, instruction_params),
            .SRL => try implementations.srl(self, i),
            .SWAP => try implementations.swap(self, i),
            .RES => try implementations.res(self, i, instruction_params),
            .SET => try implementations.set(self, i, instruction_params),
            else => {
                return error.NotImplemented;
            },
        };
    }
};
test "List non implemented instructions" {
    for (0..512) |i| {
        const instr = if (i <= 255) instructions[i] else prefixed_instructions[i - 256];
        // ilegal instr
        if (instr == null) continue;
        var emu = Emulator.initBootRom();
        emu.cpu.sp = 1000;
        emu.invokeInstruction(instr.?, .{ 0, 0 }) catch |err| {
            if (err == error.NotImplemented) {
                std.debug.print("Instruction {t} not implemented\n", .{instr.?.type});
            }
        };
    }
}
