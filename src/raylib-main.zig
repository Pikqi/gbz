const std = @import("std");

const core = @import("core");
const Emulator = core.emulator.Emulator;
const Cartridge = core.Cartridge;
const PalleteColors = core.ppu.PalleteColors;
const rl = @import("raylib");

const boot_rom = @import("bootrom.zig").rom;

const SCALE = 4;

const GB_WIDTH = 160;
const GB_HEIGHT = 144;

const VRAM_TILES = 128 * 3;
const TILE_SIZE = 8 * SCALE;

const WIDTH = GB_WIDTH * SCALE + 32 * TILE_SIZE;
const TILES_PER_ROW = (GB_WIDTH * SCALE) / TILE_SIZE;

const HEIGHT = GB_HEIGHT * SCALE + (VRAM_TILES / TILES_PER_ROW) * TILE_SIZE;
const DRAW_VRAM = true;

const DRAW_TILEMAPS = true;
var draw_lower_tilemap = true;

pub fn raylibMain(cat: Cartridge) !void {
    var emu = Emulator.initWithCatridge(cat, null);
    emu.run_until_draw = true;
    emu.mem.logs_enabled = false;

    rl.initWindow(WIDTH, HEIGHT, "ZGB");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        try emu.run_emu();

        std.log.info("{X}", .{emu.mem.getMemoryRegister(.IO_JOY)});

        if (rl.isKeyPressed(.tab)) {
            draw_lower_tilemap = !draw_lower_tilemap;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);
        rl.drawFPS(20, 20);

        if (DRAW_VRAM) {
            const vram_tiles = emu.ppu.getVRAMPixels();
            drawTiles(&vram_tiles, TILES_PER_ROW, 0, GB_HEIGHT * SCALE);
        }

        if (DRAW_TILEMAPS) {
            var tilemap = emu.ppu.getTileMapPixels(draw_lower_tilemap);
            drawTiles(&tilemap, 32, GB_WIDTH * SCALE + TILE_SIZE, 0);
            tilemap = emu.ppu.getTileMapPixels(false);
        }

        const tilemap_tiles = emu.ppu.getTileMapPixels(true);
        var start: usize = 0;
        _ = &start;
        const tilemap_tiles_slice = tilemap_tiles[start..];
        _ = tilemap_tiles_slice; // autofix
        //drawTiles(tilemap_tiles_slice, 32, GB_WIDTH * scale, 0);
    }
}

fn drawTiles(tiles: []const [8][8]PalleteColors, per_row: usize, startx: usize, starty: usize) void {
    for (tiles, 0..) |tile, tileI| {
        const base_y = (tileI / per_row) * TILE_SIZE + starty;
        for (tile, 0..) |row, rowI| {
            const base_x = (tileI % per_row) * TILE_SIZE + startx;
            for (row, 0..) |pix, pixI| {
                const color = pxColorToColor(pix);
                const x: i32 = @intCast(base_x + pixI * SCALE);
                const y: i32 = @intCast(base_y + rowI * SCALE);
                rl.drawRectangle(x, y, SCALE, SCALE, color);
            }
        }
    }
}
fn pxColorToColor(pc: PalleteColors) rl.Color {
    return switch (pc) {
        .BLACK => rl.Color.black,
        .LIGHT_GRAY => rl.Color.gray,
        .DARK_GRAY => rl.Color.dark_gray,
        .WHITE => rl.Color.green,
    };
}
