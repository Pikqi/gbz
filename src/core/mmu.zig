const std = @import("std");

const ROM_BANK_SIZE = 0x4000;
const VRAM_SIZE = 0x2000;
const ERAM_SIZE = 0x1000;
const WRAM_SIZE = 0x1000;
const ECHO_SIZE = 0x1DFF;
const SAT_SIZE = 0xFE9F - 0xFE00;
const HRAM_SIZE = 0xFFFE - 0xFF80;
const MEM_SIZE = 0x10000;

const MemoryRegisters = enum(u16) {
    TIMER_DIV = 0xFF04,
    TIMER_TIMA = 0xFF05,
    TIMER_TMA = 0xFF06,
    TIMER_TAC = 0xFF07,
};

const InteruptFlag = packed struct(u8) {
    vblank: bool,
    lcd: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    rest: u3 = 0,
};

pub const Memory = struct {
    mem: [MEM_SIZE]u8 = undefined,
    rom_bank_selected: u8 = 0,
    logs_enabled: bool = false,
    // FFFF
    IE: InteruptFlag = std.mem.zeroes(InteruptFlag),
    // FF0F
    IF: InteruptFlag = std.mem.zeroes(InteruptFlag),

    pub fn read(self: *const Memory, addrs: usize) !u8 {
        if (addrs >= self.mem.len) {
            return error.MemWriteOutOfBounds;
        }
        return self.mem[addrs];
    }
    pub fn readPtr(self: *Memory, addrs: usize) !*u8 {
        if (addrs >= self.mem.len) {
            return error.MemWriteOutOfBounds;
        }
        return &self.mem[addrs];
    }

    pub fn write(self: *Memory, addrs: usize, value: u8) !void {
        if (addrs >= self.mem.len) {
            return error.MemWriteOutOfBounds;
        }

        self.mem[addrs] = value;
        if (self.logs_enabled) {
            std.debug.print("{X:02} written to {X:04}\n", .{ value, addrs });
        }
    }
    pub fn getSlice(self: *Memory, start: usize, end: usize) ![]u8 {
        if (start > end) {
            return error.MemWriteStartBiggerThanEnd;
        }
        if (end >= self.mem.len) {
            return error.MemWriteOutOfBounds;
        }

        return self.mem[start..end];
    }
    pub fn getMemoryRegister(self: *const Memory, reg: MemoryRegisters) u8 {
        return self.mem[@intFromEnum(reg)];
    }
    pub fn writeMemoryRegister(self: *Memory, reg: MemoryRegisters, value: u8) void {
        self.mem[@intFromEnum(reg)] = value;

        if (self.logs_enabled) {
            std.debug.print("{X:02} written to {t}\n", .{ value, reg });
        }
    }

    pub fn zero(self: *Memory) void {
        self.mem = std.mem.zeroes([0x10000]u8);
    }
};
