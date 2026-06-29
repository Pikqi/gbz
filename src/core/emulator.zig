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
const Cartridge = @import("cartridge.zig").Cartridge;

const LastInstruction = struct {
    id: u8,
    prefixed: bool = false,
    params: [2]u8,
};

const EventType = enum {
    TIMER_DIV,
    TIMER_TIM,
};

pub const Emulator = struct {
    cpu: Cpu,
    mem: Memory = Memory{},
    ppu: Ppu = Ppu{},
    cartridge: ?Cartridge = null,
    cb_prefixed: bool = false,
    doctor: ?DoctorLogger = null,
    is_stopped: bool = false,
    jump_to: ?u16 = null,
    steps: usize = 0,
    last_instructinon: ?LastInstruction = null,
    interupts_enabled: bool = false,
    timer: Timer = Timer{},
    now: u64 = 0, // absolute tcycles
    cpu_cycles: u64 = 0,
    interupt_handled: bool = false,
    disable_ppu: bool = false,
    run_until_draw: bool = false,

    // Absolute tcycles for scheduled events
    // 0 means the event is not scheduled
    next_div_event: u64 = 256,
    next_tim_event: u64 = 0,

    pub fn initZero() Emulator {
        return Emulator{
            .cpu = Cpu.initZero(),
        };
    }

    pub fn initWithCatridge(c: Cartridge, bootrom: ?[]const u8) Emulator {
        var emu = Emulator{
            .cpu = undefined,
            .cartridge = c,
        };
        if (bootrom) |br| {
            emu.cpu = .initZero();

            emu.mem.boot_rom_mapped = true;
            @memcpy(&emu.mem.boot_rom, br);
            emu.mem.writeMemoryRegister(.PPU_LY, 0);
        } else {
            // Init state after boot rom
            emu.cpu = .initBootRom();
            // zero out memory more accuratly
            emu.mem.zeroNonBanks();
            emu.mem.write(0xFF44, 0x00) catch unreachable;
        }
        emu.mem.rom_banks = c.banks;
        emu.mem.writeMemoryRegister(.IO_JOY, 0b00001111);

        return emu;
    }

    pub fn initDoctorStdOut(self: *Emulator, io: std.Io) !void {
        if (self.doctor != null) {
            return error.DoctorAlreadyExists;
        }
        self.doctor = DoctorLogger.initStdOut(self, io);
    }

    pub fn initDoctorFile(self: *Emulator, file_path: []const u8, io: std.Io) !void {
        if (self.doctor != null) {
            return error.DoctorAlreadyExists;
        }
        self.doctor = try DoctorLogger.initWithFile(self, file_path, io);
    }

    // ===== STACK =====

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

    pub fn runEmuWithBootRom(self: *Emulator, boot_rom: [256]u8) !void {
        self.mem.mountBootRom(boot_rom);
        try self.run_emu();
    }

    // ===== EVENT SCHEDULING =====

    pub fn scheduleEvent(self: *Emulator, event: EventType, tcycles: u64) void {
        self.eventTypeToCycleCounter(event).* = self.now + tcycles;
    }

    pub fn cancelEvent(self: *Emulator, event: EventType) void {
        self.eventTypeToCycleCounter(event).* = 0;
    }

    pub fn printEvents(self: *Emulator) void {
        std.debug.print("now: {d}\n", .{self.now});
        inline for (std.meta.fields(EventType)) |field| {
            const event = @field(EventType, field.name);
            const when = self.eventTypeToCycleCounter(event).*;
            std.debug.print("  {s}: ", .{field.name});
            if (when == 0) {
                std.debug.print("not scheduled\n", .{});
            } else {
                std.debug.print("{d} (in {d})\n", .{ when, when -% self.now });
            }
        }
    }

    fn eventTypeToCycleCounter(self: *Emulator, event: EventType) *u64 {
        return switch (event) {
            .TIMER_DIV => &self.next_div_event,
            .TIMER_TIM => &self.next_tim_event,
        };
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
        defer if (self.doctor) |*doc| doc.flush();
        if (self.doctor) |*doc| {
            doc.log() catch |e| {
                std.debug.print("Logging with doctor failed {t}", .{e});
            };
        }
        while (!self.is_stopped) {
            try self.cpuStep();
            try self.handleInterupts();
            self.handleDMA();
            self.now += self.cpu_cycles;
            if (!self.disable_ppu) {
                self.ppu.tick(self.cpu_cycles);
            }

            if (self.doctor) |doc| {
                if (doc.limit_reached) {
                    return;
                }
            }
            if (self.run_until_draw and self.ppu.ready_to_draw) {
                self.ppu.ready_to_draw = false;
                return;
            }
        }
    }

    pub fn runEmuForOneFrame(self: *Emulator) !void {
        errdefer {
            if (self.last_instructinon) |last| {
                std.debug.print("Last Instruction before error:\n", .{});
                const instruction_set = if (last.prefixed) prefixed_instructions else instructions;
                instruction_set[last.id].?.print();
                std.debug.print("params: {X}\n", .{last.params});
            }
        }

        while (!self.ppu.ready_to_draw) {
            self.cpu_cycles = 0;

            // self.printEvents();

            const next_when = self.nextEventTime();
            if (next_when == 0) {
                try self.cpuStep();
                self.now += self.cpu_cycles;
                try self.handleInterupts();
                continue;
            }

            if (next_when > self.now) {
                try self.cpuStepFor(next_when - self.now);
            }

            if (!self.disable_ppu) {
                self.ppu.tick(self.cpu_cycles);
                try self.handleInterupts();
            }
            try self.fireDueEvents(next_when);
        }
        self.ppu.ready_to_draw = false;
    }

    const Handler = *const fn (self: *Emulator) anyerror!void;

    fn handleTIM(self: *Emulator) !void {
        return self.timer.handleTIM();
    }
    fn handleDIV(self: *Emulator) !void {
        return self.timer.handleDIV();
    }

    fn eventHandler(event: EventType) Handler {
        return switch (event) {
            .TIMER_DIV => handleDIV,
            .TIMER_TIM => handleTIM,
        };
    }

    /// Returns the absolute tcycle of the next scheduled event, or 0 if none.
    fn nextEventTime(self: *Emulator) u64 {
        var earliest: u64 = std.math.maxInt(u64);
        inline for (std.meta.fields(EventType)) |field| {
            const event = @field(EventType, field.name);
            const when = self.eventTypeToCycleCounter(event).*;
            if (when != 0 and when < earliest) {
                earliest = when;
            }
        }
        return if (earliest == std.math.maxInt(u64)) 0 else earliest;
    }

    /// Fires every event whose scheduled time has been reached.
    /// `at_time` is captured so events rescheduled by a handler to a later
    /// tick are not re-fired in this pass.
    fn fireDueEvents(self: *Emulator, at_time: u64) !void {
        inline for (std.meta.fields(EventType)) |field| {
            const event = @field(EventType, field.name);
            const counter = self.eventTypeToCycleCounter(event);
            if (counter.* != 0 and counter.* <= at_time) {
                try eventHandler(event)(self);
            }
        }
    }

    fn cpuStepFor(self: *Emulator, budget: u64) !void {
        const end = self.now + budget;
        while (self.now <= end) {
            try self.cpuStep();
            self.now += self.cpu_cycles;
            try self.handleInterupts();
        }
    }

    pub fn cpuStep(self: *Emulator) !void {
        self.cpu_cycles = 0;
        // var sp = &self.cpu.sp;
        if (self.cpu.is_halted) {
            self.cpu_cycles += 1;
            try self.handleInterupts();
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
        if (self.cpu.pc >= 0x100 and self.mem.boot_rom_mapped) {
            self.mem.boot_rom_mapped = false;
            std.debug.print("boot rom unmapped\n", .{});
        }
    }

    pub fn handleInterupts(self: *Emulator) !void {
        if (!self.interupts_enabled) {
            return;
        }
        const IF = self.mem.getIF();
        const IE: InteruptFlag = @bitCast(self.mem.getMemoryRegister(.IE));

        if (IF.vblank and IE.vblank) {
            self.mem.setIFInterupt(.VBLANK, false);
            try self.gotoInterupt(0x0040);
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
    fn handleDMA(self: *Emulator) void {
        const dma_reg = self.mem.getMemoryRegister(.OAM_DMA);
        if (dma_reg != 0) {
            // todo simulates slower dma
            const source = self.mem.getSlice(dma_reg << 4, (dma_reg << 4) + 0x9F) catch unreachable;
            const destination = self.mem.getSlice(0xFE00, 0xFEA0) catch unreachable;
            for (0..destination.len, 0..) |i, s| {
                destination[i] = source[s];
            }
            std.log.info("-----DMA SUCCESS-----\n", .{});

            self.mem.writeMemoryRegister(.OAM_DMA, 0);
        }
    }
};

// This test should catch any invalid combination of instruction operands
test "Try all instructions" {
    for (0..512) |i| {
        const instr = if (i <= 255) instructions[i] else prefixed_instructions[i - 256];
        // ilegal instr
        if (instr == null) continue;
        var emu = Emulator.initZero();
        emu.cpu = Cpu.initBootRom();
        emu.mem.logs_enabled = false;
        emu.cpu.sp = 1000;
        emu.mem.rom_banks[0] = try std.testing.allocator.alloc(u8, 16 * 1024);
        emu.mem.rom_banks[1] = try std.testing.allocator.alloc(u8, 16 * 1024);
        defer std.testing.allocator.free(emu.mem.rom_banks[0]);
        defer std.testing.allocator.free(emu.mem.rom_banks[1]);
        try emu.invokeInstruction(instr.?, .{ 0, 0 });
    }
}
