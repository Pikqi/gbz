const std = @import("std");

pub const DoubleU8Ptr = @import("common").DoubleU8Ptr;

const Cpu = @import("cpu.zig").Cpu;
const DoctorLogger = @import("doctor.zig").DoctorLogger;
const implementations = @import("instruction_implementations.zig");
const InstructionsMod = @import("instructions.zig");
const instructions = InstructionsMod.instructions;
const prefixed_instructions = InstructionsMod.prefixed_instructions;
const mmu = @import("mmu.zig");
const Memory = mmu.Memory;
const InteruptFlag = mmu.InteruptFlag;
const ppu = @import("ppu.zig");
const Ppu = ppu.Ppu;
const Timer = @import("timer.zig").Timer;

const LastInstruction = struct {
    id: u8,
    prefixed: bool = false,
    params: [2]u8,
};

pub const Emulator = struct {
    cpu: Cpu,
    mem: Memory = Memory{},
    ppu: Ppu = Ppu{},
    cb_prefixed: bool = false,
    doctor: ?DoctorLogger = null,
    is_stopped: bool = false,
    jump_to: ?u16 = null,
    steps: usize = 0,
    last_instructinon: ?LastInstruction = null,
    interupts_enabled: bool = false,
    timer: Timer = Timer{},
    cpu_cycles: u64 = 0,
    cpu_cycles_total: u64 = 0,
    interupt_handled: bool = false,

    pub fn initZero() Emulator {
        return Emulator{
            .cpu = Cpu.initZero(),
        };
    }

    pub fn initBootRom() Emulator {
        var emu = Emulator{
            .cpu = Cpu.initBootRom(),
        };
        emu.mem.zero();
        emu.mem.write(0xFF44, 0x00) catch unreachable;

        // for (0x8000..0x9800) |i| {
        //     emu.mem.write(i, @intCast(0x44 + i % 0x44)) catch unreachable;
        // }
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

    // todo implement stack overflow
    pub fn stackPush(self: *Emulator, upper: u8, lower: u8) !void {
        const sp = &self.cpu.sp;
        sp.* -= 1;
        try self.mem.write(sp.*, upper);
        sp.* -= 1;
        try self.mem.write(sp.*, lower);
    }

    pub fn stackPop(self: *Emulator, upper: *u8, lower: *u8) !void {
        const sp = &self.cpu.sp;
        lower.* = try self.mem.read(sp.*);
        sp.* += 1;
        upper.* = try self.mem.read(sp.*);
        sp.* += 1;
    }

    pub fn stackPushPC(self: *Emulator) !void {
        std.debug.print("stackpush pc\n", .{});
        const upper: u8 = @intCast((self.cpu.pc) >> 8);
        const lower: u8 = @intCast(self.cpu.pc & 0xFF);
        try self.stackPush(upper, lower);
    }

    pub fn load_rom(self: *Emulator, rom: []const u8) !void {
        if (rom.len > self.mem.mem.len - 0x100) {
            return error.ROMTooBig;
        }
        const mem = try self.mem.getSlice(0, @intCast(rom.len));
        @memcpy(mem, rom);
    }

    pub fn run_emu(self: *Emulator) !void {
        errdefer {
            if (self.last_instructinon) |last| {
                std.debug.print("Last Instruction before error:\n", .{});
                const instruction_set = if (last.prefixed) prefixed_instructions else instructions;
                instruction_set[last.id].?.print();
                std.debug.print("params: {X}\n", .{last.params});
            }
        }
        if (self.doctor) |*doc| {
            doc.log() catch |e| {
                std.debug.print("Logging with doctor failed {t}", .{e});
            };
        }
        while (!self.is_stopped) {
            self.cpu_cycles = 0;

            try self.cpu_step();
            try self.timer.tick();
            try self.handle_interupts();
            self.cpu_cycles_total += self.cpu_cycles;
            self.ppu.tick(self.cpu_cycles);
        }
    }

    pub fn cpu_step(self: *Emulator) !void {
        // var sp = &self.cpu.sp;
        if (self.cpu.is_halted) {
            self.cpu_cycles += 1;
            return;
        }
        const pc = &self.cpu.pc;
        if (pc.* >= self.mem.mem.len) {
            std.debug.print("pc overflow", .{});
            return;
        }
        if (self.interupt_handled) {
            self.interupt_handled = false;
            self.cpu_cycles += 5;
        }

        const instruction_byte = try self.mem.read(pc.*);
        var instruction: InstructionsMod.Instruction = undefined;
        var instruction_params = [2]u8{ 0, 0 };
        const instruction_set = if (self.cb_prefixed) prefixed_instructions else instructions;

        if (instruction_set[instruction_byte]) |instr| {
            // std.debug.print("{s}\n", .{instr.name});
            instruction = instr;
        } else {
            return error.UnkownInstruction;
        }

        if (instruction.length > 1) {
            for (0..instruction.length - 1) |i| {
                instruction_params[i] = try self.mem.read(pc.* + i + 1);
            }
        }

        self.last_instructinon = .{ .id = instruction_byte, .prefixed = self.cb_prefixed, .params = instruction_params };
        if (self.cb_prefixed) {
            self.cb_prefixed = false;
        }

        //todo handle 0xF8 edge case
        // std.debug.print("s: {d} ", .{self.steps});
        // instruction.printWithParams(instruction_params);
        try invokeInstruction(self, instruction, instruction_params);
        self.cpu.getFlagsRegister().setFlags(instruction.flags);

        if (self.jump_to) |new_pc| {
            pc.* = new_pc;
            self.jump_to = null;
        } else {
            pc.* += instruction.length;
        }
        if (self.doctor) |*doc| {
            if (instruction.type != .CB) {
                doc.log() catch |e| {
                    std.debug.print("Logging with doctor failed {t}", .{e});
                };
            }
        }
        self.cpu_cycles += instruction.tcycle;

        self.steps += 1;
        // if (self.steps == 31459) {
        //     self.is_stopped = true;
        // }
    }

    pub fn handle_interupts(self: *Emulator) !void {
        if (!self.interupts_enabled) {
            return;
        }
        const IF = self.mem.getIF();
        const IE: InteruptFlag = @bitCast(self.mem.getMemoryRegister(.IE));

        if (IF.vblank and IE.vblank) {
            @panic("vblank interupt not implemented!\n");
        }
        if (IF.lcd and IE.lcd) {
            std.debug.print("lcd itnerupt\n", .{});
            self.mem.setIFInterupt(.LCD, false);
            try self.gotoInterupt(0x0048);

            return;
        }
        if (IF.timer and IE.timer) {
            std.debug.print("timer itnerupt\n", .{});
            self.mem.setIFInterupt(.TIMER, false);
            try self.gotoInterupt(0x0050);

            return;
        }
        if (IF.serial and IE.serial) {
            @panic("serial interupt not implemented!\n");
        }

        if (IF.joypad and IE.joypad) {
            @panic("joypad interupt not implemented!\n");
        }
    }

    fn gotoInterupt(self: *Emulator, vector: u16) !void {
        self.cpu.is_halted = false;
        std.debug.print("unhalted\n", .{});
        try self.stackPushPC();

        self.cpu.pc = vector;
        self.interupts_enabled = false;
        self.cpu_cycles_total += 5;
        self.interupt_handled = true;
    }

    fn invokeInstruction(self: *Emulator, i: InstructionsMod.Instruction, instruction_params: [2]u8) !void {
        return switch (i.type) {
            .NOP => implementations.nop(),
            .STOP => implementations.stop(self),
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
            .RETI => try implementations.reti(self),
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
        emu.mem.logs_enabled = false;
        emu.cpu.sp = 1000;
        emu.invokeInstruction(instr.?, .{ 0, 0 }) catch |err| {
            if (err == error.NotImplemented) {
                std.debug.print("Instruction {t} not implemented\n", .{instr.?.type});
            }
        };
    }
}
