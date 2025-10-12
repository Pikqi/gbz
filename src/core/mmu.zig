const std = @import("std");

const ROM_BANK_SIZE = 0x4000;
const VRAM_SIZE = 0x2000;
const ERAM_SIZE = 0x1000;
const WRAM_SIZE = 0x1000;
const ECHO_SIZE = 0x1DFF;
const SAT_SIZE = 0xFE9F - 0xFE00;
const HRAM_SIZE = 0xFFFE - 0xFF80;

pub const Memory = struct {
    mem: [0xFFFF]u8 = undefined,
    rom_bank: [ROM_BANK_SIZE]u8 = undefined,
    rom_bank_switchable: [ROM_BANK_SIZE]u8 = undefined,
    vram: [VRAM_SIZE]u8 = undefined,
    eram: [ERAM_SIZE]u8 = undefined,
    wram0: [WRAM_SIZE]u8 = undefined,
    wramN: [WRAM_SIZE]u8 = undefined,
    echo_ram: [WRAM_SIZE]u8 = undefined,
    sat: [SAT_SIZE]u8 = undefined,
    hram: [HRAM_SIZE]u8 = undefined,
    ie: u8 = 0,

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
        std.debug.print("{X:02} written to {X:04}\n", .{ value, addrs });
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
};
