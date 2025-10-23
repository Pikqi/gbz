const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;

pub const LCDStat = packed struct(u8) {
    ppu_mode: PpuMode,
    coincidence: bool,
    mode0_int: bool,
    mode1_int: bool,
    mode2_int: bool,
    lyc_int: bool,
    _unused: u1 = 1,
};

pub const LCDC = packed struct(u8) {
    enable_bg_window: bool,
    enable_obj: bool,
    obj_size: bool,
    bg_tile_map: bool,
    bg_window_tiles: bool,
    window_enable: bool,
    window_tilemap_select: bool,
    enabled: bool,
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
        var tile = Tile{ .data = 0 };
        for (slice, 0..16) |byte, i| {
            tile.data |= @as(u128, @intCast(byte)) << @intCast((15 - i) * 8);
        }
        return tile;
    }
    pub fn toPixels(self: *const Tile) TilePixels {
        var pixels = std.mem.zeroes(TilePixels);
        for (pixels[0..], 0..) |*row, ri| {
            const shift_amount: u7 = @intCast(8 * (15 - ri * 2));
            const shift_amount_lower: u7 = shift_amount - 1;

            const higher: u8 = @intCast((self.data >> shift_amount) & 0xFF);
            const lower: u8 = @intCast((self.data >> shift_amount_lower) & 0xFF);

            for (row[0..], 0..) |*cell, ci| {
                const shift: u3 = @intCast(7 - ci);
                var cell_val: u2 = 0;
                cell_val = @intCast((higher >> shift) & 0b1);
                cell_val |= @intCast(((lower >> shift) & 0b1) << 1);
                cell.* = @enumFromInt(cell_val);
            }
        }
        return pixels;
    }
};

pub const Ppu = struct {
    ticks: usize = 0,

    pub fn tick(self: *Ppu, ticks: usize) void {
        const lcdc = self.getLCDC();
        if (!lcdc.enabled) {
            return;
        }
        self.ticks += ticks;
        const emu = self.getEmu();
        var stat = self.getStat();
        const ly = emu.mem.getMemoryRegister(.PPU_LY);
        const lyc = emu.mem.getMemoryRegister(.PPU_LYC);

        const stat_int: u8 = @bitCast(stat);
        _ = stat_int; // autofix

        switch (stat.ppu_mode) {
            // MODE 2
            .OAMSCAN => {
                if (self.ticks >= 80) {
                    self.ticks -= 80;
                } else {
                    return;
                }
                if (stat.mode2_int) {
                    emu.mem.setIFInterupt(.LCD, true);
                }
                stat.ppu_mode = .DRAWING;
                emu.mem.writeMemoryRegister(.PPU_STAT, @bitCast(stat));
            },
            // MODE 3
            .DRAWING => {
                if (self.ticks >= 289) {
                    self.ticks -= 289;
                } else {
                    return;
                }

                if (lyc == ly) {
                    stat.coincidence = true;
                    if (stat.lyc_int) {
                        emu.mem.setIFInterupt(.LCD, true);
                    }
                }

                stat.ppu_mode = .HBLANK;

                emu.mem.writeMemoryRegister(.PPU_STAT, @bitCast(stat));
            },
            // MODE 0
            .HBLANK => {
                if (self.ticks >= 87) {
                    self.ticks -= 87;
                } else {
                    return;
                }

                if (ly >= 143) {
                    stat.ppu_mode = .VBLANK;
                } else {
                    stat.ppu_mode = .OAMSCAN;
                }
                emu.mem.writeMemoryRegister(.PPU_LY, ly + 1);
                emu.mem.writeMemoryRegister(.PPU_STAT, @bitCast(stat));
                if (stat.mode0_int) {
                    emu.mem.setIFInterupt(.LCD, true);
                }
            },
            // MODE 1
            .VBLANK => {
                if (self.ticks >= 456) {
                    self.ticks -= 456;
                } else {
                    return;
                }
                std.debug.print("vblank ly: {d}\n", .{ly});
                if (ly == 144) {
                    emu.mem.setIFInterupt(.VBLANK, true);
                }

                if (ly == 152) {
                    emu.mem.writeMemoryRegister(.PPU_LY, 0);
                    stat.ppu_mode = .OAMSCAN;
                } else {
                    emu.mem.writeMemoryRegister(.PPU_LY, ly + 1);
                }

                if (stat.mode1_int) {
                    emu.mem.setIFInterupt(.LCD, true);
                }

                emu.mem.writeMemoryRegister(.PPU_STAT, @bitCast(stat));
            },
        }
        // std.debug.print("{any} \n\n", .{self.getStat()});
        // _ = self.debugPrintVRAMwithANSI() catch unreachable;
    }
    pub fn getVRAMPixels(self: *Ppu) [128 * 4]TilePixels {
        var pixel_tiles = std.mem.zeroes([128 * 4]TilePixels);
        var pi: usize = 0;
        const vram = self.getVRAM();
        for (0..vram.len / 16) |i| {
            const tile = Tile.fromSlice(vram[i * 16 .. (i + 1) * 16]) catch unreachable;
            pixel_tiles[pi] = tile.toPixels();
            pi += 1;
        }
        return pixel_tiles;
    }

    fn getVRAM(self: *Ppu) []u8 {
        const emu = self.getEmu();
        return emu.mem.getSlice(0x8000, 0x97FF) catch unreachable;
    }
    fn getStat(self: *Ppu) LCDStat {
        return @bitCast(self.getEmu().mem.getMemoryRegister(.PPU_STAT));
    }
    fn getLCDC(self: *Ppu) LCDC {
        return @bitCast(self.getEmu().mem.getMemoryRegister(.PPU_LCDC));
    }

    fn getEmu(self: *Ppu) *Emulator {
        return @fieldParentPtr("ppu", self);
    }

    pub fn debugPrintVRAMwithANSI(self: *Ppu) !void {
        const tiles = self.getVRAMPixels();
        const tiles_per_row = 12;
        const rows = (tiles.len / tiles_per_row) * 8;

        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;

        try stdout.print("\n\n----------\n", .{});

        for (0..rows) |i| {
            for (0..tiles_per_row * 8) |j| {
                if (j % 8 == 0 and j != 0) {
                    try stdout.print(" ", .{});
                }
                const row = i / 8;
                const col = j / 8;
                const tile = tiles[row * 8 + col];
                const px_row = i % 8;
                const px_col = j % 8;
                const pixel = tile[px_row][px_col];
                try stdout.print("{s}█", .{colorPalleteAnsiChars.get(pixel).?.?});
                // try stdout.print("{s}{d}", .{ colorPalleteAnsiChars.get(pixel).?.?, j });
            }

            try stdout.print("\n", .{});
            if (i % 8 == 7) {
                try stdout.print("\n", .{});
            }
        }
        try stdout.print("\x1b[0m", .{});
    }
};

const colorPalleteAnsiChars = blk: {
    var map = std.EnumMap(PalleteColors, ?[]const u8).initFull(null);
    map.put(.BLACK, "\x1b[30m");
    map.put(.DARK_GRAY, "\x1b[32m");
    map.put(.LIGHT_GRAY, "\x1b[33m");
    map.put(.WHITE, "\x1b[37m");
    break :blk map;
};

test "LCDStat" {
    const stat: LCDStat = @bitCast(@as(u8, 0b00010111));
    try std.testing.expect(stat.coincidence);
    try std.testing.expect(!stat.mode0_int);
    try std.testing.expect(stat.mode1_int);
    try std.testing.expect(!stat.mode2_int);
    try std.testing.expect(!stat.lyc_int);
}
