const std = @import("std");
const Allocator = std.mem.Allocator;

const core = @import("core");
const Emulator = core.emulator.Emulator;
const PalleteColors = core.ppu.PalleteColors;
const rl = @import("raylib");

const Catridge = @import("cartridge.zig").Cartridge;

const boot_rom = @embedFile("dmg_boot.bin");

const scale = 4;

const GB_WIDTH = 160;
const GB_HEIGHT = 144;

const VRAM_TILES = 128 * 3;
const TILE_SIZE = 8 * scale;

const WIDTH = GB_WIDTH * scale;
const TILES_PER_ROW = WIDTH / TILE_SIZE;

const HEIGHT = GB_HEIGHT * scale + (VRAM_TILES / TILES_PER_ROW) * TILE_SIZE;

pub fn raylibMain(alloc: Allocator) !void {
    const file_name = "roms/dmg-acid2.gb";
    // const file_name = "roms/Tetris (World) (Rev 1).gb";

    const file = try std.fs.cwd().openFile(file_name, .{});
    const contents = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);

    var emu = Emulator.initBootRom();
    emu.run_until_draw = true;
    emu.initDoctorFile("doctor_main.log") catch |err| {
        std.log.err("Failed init doctor file {t}", .{err});
    };
    var c = try Catridge.loadFromFile(file_name, alloc);
    defer c.destroy();
    c.ch.print();
    emu.mem.logs_enabled = false;
    try emu.load_rom(contents);

    var boot_rom_arr: [256]u8 = undefined;
    @memcpy(&boot_rom_arr, boot_rom);
    try emu.runEmuWithBootRom(boot_rom_arr);

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
