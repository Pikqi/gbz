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
    IF = 0xFF0F,
    IE = 0xFFFF,
    TIMER_DIV = 0xFF04,
    TIMER_TIMA = 0xFF05,
    TIMER_TMA = 0xFF06,
    TIMER_TAC = 0xFF07,
    PPU_LCDC = 0xFF40,
    PPU_STAT = 0xFF41,
    PPU_LY = 0xFF44,
    PPU_LYC = 0xFF45,
    OAM_DMA = 0xFF46,
    PPU_BGP = 0xFF47,
    PPU_WY = 0xFF4A,
    PPU_WX = 0xFF4B,
};

const InteruptFlag = packed struct(u8) {
    vblank: bool,
    lcd: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    rest: u3 = 0,
    pub fn byteCast(self: *InteruptFlag) *u8 {
        return @ptrCast(self);
    }
};

pub const Memory = struct {
    mem: [MEM_SIZE]u8 = undefined,
    rom_bank_selected: u8 = 0,
    logs_enabled: bool = true,
    // FFFF
    pub fn getIE(self: *Memory) *InteruptFlag {
        return @ptrCast(&self.mem[0xFFFF]);
    }
    // FF0F
    pub fn getIF(self: *Memory) *InteruptFlag {
        return @ptrCast(&self.mem[0xFF0F]);
    }

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

        if (self.logs_enabled) {
            if (std.enums.fromInt(MemoryRegisters, addrs)) |mem_reg| {
                std.debug.print("{X:02} written to {X:04} ({t})\n", .{ value, addrs, mem_reg });
            } else {
                std.debug.print("{X:02} written to {X:04}\n", .{ value, addrs });
            }
        }
        self.mem[addrs] = value;
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

        if (self.logs_enabled and reg != .TIMER_DIV) {
            std.debug.print("{X:02} written to {t}\n", .{ value, reg });
        }
    }

    pub fn zero(self: *Memory) void {
        self.mem = std.mem.zeroes([0x10000]u8);
    }
};
test "InteruptFlag" {
    var IF: InteruptFlag = @bitCast(@as(u8, 0));
    try std.testing.expectEqual(IF.timer, false);
    try std.testing.expectEqual(IF.joypad, false);
    try std.testing.expectEqual(IF.serial, false);
    try std.testing.expectEqual(IF.vblank, false);
    try std.testing.expectEqual(IF.lcd, false);
    IF = @bitCast(@as(u8, 0x04));
    try std.testing.expectEqual(IF.timer, true);
    try std.testing.expectEqual(IF.joypad, false);
    try std.testing.expectEqual(IF.serial, false);
    try std.testing.expectEqual(IF.vblank, false);
    try std.testing.expectEqual(IF.lcd, false);
}
