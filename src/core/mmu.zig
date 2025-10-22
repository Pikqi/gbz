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

pub const Interupts = enum {
    VBLANK,
    LCD,
    TIMER,
    SERIAL,
    JOYPAD,
};

pub const InteruptFlag = packed struct(u8) {
    vblank: bool,
    lcd: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    rest: u3 = 0,
    pub fn byteCast(self: InteruptFlag) u8 {
        return @bitCast(self);
    }
};

pub const Memory = struct {
    mem: [MEM_SIZE]u8 = undefined,
    rom_bank_selected: u8 = 0,
    logs_enabled: bool = true,
    // FF0F
    pub fn getIF(self: *Memory) InteruptFlag {
        return @bitCast(self.getMemoryRegister(.IF));
    }
    pub fn setIFInterupt(self: *Memory, bit: Interupts, value: bool) void {
        const IF: *InteruptFlag = @ptrCast(&self.mem[@intFromEnum(MemoryRegisters.IF)]);
        if (self.logs_enabled) {
            std.debug.print("IF bit {t} set to {}\n", .{ bit, value });
        }

        switch (bit) {
            .VBLANK => IF.vblank = value,
            .LCD => IF.lcd = value,
            .TIMER => IF.timer = value,
            .SERIAL => IF.serial = value,
            .JOYPAD => IF.joypad = value,
        }
    }

    pub fn read(self: *const Memory, addrs: usize) !u8 {
        if (addrs >= self.mem.len) {
            return error.MemWriteOutOfBounds;
        }
        return self.mem[addrs];
    }

    pub fn write(self: *Memory, addrs: usize, value: u8) !void {
        if (addrs >= self.mem.len) {
            return error.MemWriteOutOfBounds;
        }

        self.mem[addrs] = value;
        self.writeLog(addrs, value);
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
        self.write(@intFromEnum(reg), value) catch unreachable;
    }

    pub fn zero(self: *Memory) void {
        self.mem = std.mem.zeroes([0x10000]u8);
    }
    fn writeLog(self: *Memory, addrs: usize, value: u8) void {
        if (self.logs_enabled) {
            const mem_reg_opt = std.enums.fromInt(MemoryRegisters, addrs);
            if (mem_reg_opt) |mem_reg| {
                if (!ignored_mem_regs.contains(mem_reg)) {
                    std.debug.print("{X:02} written to {X:04} ({t})\n", .{ value, addrs, mem_reg });
                }
            } else {
                std.debug.print("{X:02} written to {X:04}\n", .{ value, addrs });
            }
        }
    }
};

const ignored_mem_regs = blk: {
    var set = std.EnumSet(MemoryRegisters).initEmpty();
    set.insert(.PPU_LY);
    set.insert(.PPU_STAT);
    set.insert(.TIMER_DIV);
    break :blk set;
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

test "setIFInterupt" {
    var m: Memory = .{ .logs_enabled = false };
    m.writeMemoryRegister(.IF, 0);
    try std.testing.expectEqual(0, m.getIF().byteCast());

    m.setIFInterupt(.LCD, true);

    const IF = m.getIF();
    try std.testing.expectEqual(IF.timer, false);
    try std.testing.expectEqual(IF.joypad, false);
    try std.testing.expectEqual(IF.serial, false);
    try std.testing.expectEqual(IF.vblank, false);
    try std.testing.expectEqual(IF.lcd, true);
}
