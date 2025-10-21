const std = @import("std");
const Cartridge = @import("cartridge.zig").Cartridge;
const core = @import("core");
const instructions_mod = core.instructions;
const Emulator = core.emulator.Emulator;
const Cpu = core.cpu.Cpu;

const stdow = std.io.getStdOut().writer();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    // try disassembler(alloc);
    try simpleExecuteLoop(alloc);
}

fn disassembler(alloc: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("dmg_boot.bin", .{});
    const contents = try file.readToEndAlloc(alloc, 1024);
    defer alloc.free(contents);
    var i: usize = 0;

    while (i < contents.len) : (i += 1) {
        const value = contents[i];
        if (instructions_mod.instructions[value]) |in| {
            try stdow.print("{s}\n", .{in.name});
            i += in.length - 1;
            if (value == 0xCB) {
                i += 1;
            }
        } else {
            // try stdow.print("{X:02} not implemented\n", .{value});
        }
    }
}

fn simpleExecuteLoop(alloc: std.mem.Allocator) !void {
    // const file = try std.fs.cwd().openFile("roms/dmg_boot.bin", .{});
    const file_name = "roms/cpu_instrs/individual/02-interrupts.gb";
    const file = try std.fs.cwd().openFile(file_name, .{});
    const contents = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);

    var emu = Emulator.initBootRom();
    emu.initDoctorFile("doctor_main.log") catch |err| {
        std.log.err("Failed init doctor file {t}", .{err});
    };
    var c = try Cartridge.loadFromFile(file_name, alloc);
    defer c.destroy();
    c.ch.print();
    // emu.initDoctorStdOut() catch |err| {
    //     std.log.err("Failed init doctor file {t}", .{err});
    // };
    try emu.load_rom(contents);

    try emu.run_emu();
}
