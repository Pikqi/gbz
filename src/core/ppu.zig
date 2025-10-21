const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;

pub const LCDStat = packed struct(u8) {
    _unused: u1 = 1,
    lyc_int: bool,
    mode2_int: bool,
    mode1_int: bool,
    mode3_int: bool,
    coincidence: bool,
    ppu_mode: PpuMode,
};

pub const PalleteColors = enum(u2) {
    WHITE,
    LIGHT_GRAY,
    DARK_GRAY,
    BLACK,
};

pub const PpuMode = enum(u2) {
    HBLANK,
    VBLANK,
    OAMSCAN,
    DRAWING,
};

pub const TilePixels = [8][8]PalleteColors;

pub const Tile = packed struct(u128) {
    data: u128,

    pub fn fromSlice(slice: []u8) !Tile {
        if (slice.len != 16) {
            return error.TileMustBe16B;
        }
        return Tile{ .data = @bitCast(slice.ptr.*) };
    }
    pub fn toPixels(self: *const Tile) TilePixels {
        const pixels = std.mem.zeroes(TilePixels);
        for (pixels, 0..) |row, ri| {
            const shift_amount = 8 * (15 - ri * 2);
            const shift_amount_lower = shift_amount - 1;

            const higher: u8 = @intCast((self.data >> shift_amount) & 0xFF);
            const lower: u8 = @intCast((self.data >> shift_amount_lower) & 0xFF);
            _ = lower; // autofix
            _ = higher; // autofix

            for (row, 0..) |cell, ci| {
                _ = cell; // autofix
                _ = ci; // autofix
            }
        }
    }
};

pub const Ppu = struct {
    ticks: usize = 0,

    pub fn tick(self: *Ppu, ticks: usize) void {
        self.ticks += ticks;
        const stat = self.getStat();

        switch (stat.ppu_mode) {
            .HBLANK => {},
            .VBLANK => {},
            .OAMSCAN => {},
            .DRAWING => {},
        }
        // std.debug.print("{any} \n\n", .{self.getStat()});
        _ = self.printVRAMPixels();
    }
    pub fn printVRAMPixels(self: *Ppu) [384]TilePixels {
        const pixel_tiles = std.mem.zeroes([384]TilePixels);
        var pi = 0;
        const vram = self.getVRAM();
        for (vram.len - 16) |i| {
            const tile = Tile.fromSlice(vram[i * 16 .. (i + 1) * 16]) catch unreachable;
            pixel_tiles[pi] = tile.toPixels();
            pi += 1;
        }
        return pixel_tiles;
    }

    fn getVRAM(self: *Ppu) []u8 {
        const emu = self.getEmu();
        return emu.mem.getSlice(0x8000, 0x87FF);
    }
    fn getStat(self: *Ppu) LCDStat {
        return @bitCast(self.getEmu().mem.getMemoryRegister(.PPU_STAT));
    }

    fn getEmu(self: *Ppu) *Emulator {
        return @fieldParentPtr("ppu", self);
    }
};
