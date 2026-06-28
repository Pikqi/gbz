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

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var arg_iter = init.minimal.args.iterate();
    _ = arg_iter.next();

    const path = blk: {
        if (arg_iter.next()) |path| {
            break :blk path;
        }
        break :blk rom_path;
    };

    var romc = try Cartridge.loadFromFile(path, alloc, io);
    defer romc.deinit();
    romc.ch.print();

    try raylibMain(romc, io);
    // try runNoPPU(romc);
}

fn runNoPPU(cat: Cartridge, io: std.Io) !void {
    var emu = Emulator.initWithCatridge(cat, &bootrom);
    emu.initDoctorFile("doctor_main.log", io) catch |err| {
        std.log.err("Failed init doctor file {t}", .{err});
    };
    try emu.runEmuWithBootRom(bootrom);
}
