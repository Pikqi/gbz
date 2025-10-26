const std = @import("std");
const Cartridge = core.Cartridge;
const core = @import("core");
const instructions_mod = core.instructions;
const Emulator = core.emulator.Emulator;
const Cpu = core.cpu.Cpu;
const rl = @import("raylib");
const raylibMain = @import("raylib-main.zig").raylibMain;
const bootrom = @import("bootrom.zig").rom;

const rom_path = "roms/dmg-acid2.gb";

const stdow = std.io.getStdOut().writer();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.skip();
    const path = blk: {
        if (args.next()) |path| {
            break :blk path;
        }
        break :blk rom_path;
    };

    var romc = try Cartridge.loadFromFile(path, alloc);
    defer romc.deinit();
    romc.ch.print();

    try raylibMain(romc);
    // try runNoPPU(romc);
}

fn runNoPPU(cat: Cartridge) !void {
    var emu = Emulator.initWithCatridge(cat, &bootrom);
    emu.initDoctorFile("doctor_main.log") catch |err| {
        std.log.err("Failed init doctor file {t}", .{err});
    };
    try emu.runEmuWithBootRom(bootrom);
}
