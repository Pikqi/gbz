const std = @import("std");

const core = @import("core");
const Emulator = core.emulator.Emulator;
const Cartridge = core.Cartridge;
const PalleteColors = core.ppu.PalleteColors;
const rl = @import("raylib");

const boot_rom = @import("bootrom.zig").rom;

const scale = 4;

const GB_WIDTH = 160;
const GB_HEIGHT = 144;

const VRAM_TILES = 128 * 3;
const TILE_SIZE = 8 * scale;

const WIDTH = GB_WIDTH * scale;
const TILES_PER_ROW = WIDTH / TILE_SIZE;

const HEIGHT = GB_HEIGHT * scale + (VRAM_TILES / TILES_PER_ROW) * TILE_SIZE;

pub fn raylibMain(cat: Cartridge) !void {
    var emu = Emulator.initWithCatridge(cat, &boot_rom);
    emu.run_until_draw = true;
    emu.initDoctorFile("doctor_main.log") catch |err| {
        std.log.err("Failed init doctor file {t}", .{err});
    };
    emu.mem.logs_enabled = false;

    rl.initWindow(WIDTH, HEIGHT, "ZGB");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        try emu.run_emu();
        const vram_tiles = emu.ppu.getVRAMPixels();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        for (vram_tiles, 0..) |tile, tileI| {
            const base_y = (tileI / TILES_PER_ROW) * TILE_SIZE + GB_HEIGHT * scale;
            for (tile, 0..) |row, rowI| {
                const base_x = (tileI % TILES_PER_ROW) * TILE_SIZE;
                for (row, 0..) |pix, pixI| {
                    const color = pxColorToColor(pix);
                    const x: i32 = @intCast(base_x + pixI * scale);
                    const y: i32 = @intCast(base_y + rowI * scale);
                    rl.drawRectangle(x, y, scale, scale, color);
                }
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
