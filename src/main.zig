const std = @import("std");
const Cartridge = @import("cartridge.zig").Cartridge;
const Instruction = @import("instructions.zig");

const stdow = std.io.getStdOut().writer();

pub fn main() !void {
    try disassembler();
}

fn disassembler() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const file = try std.fs.cwd().openFile("dmg_boot.bin", .{});
    const contents = try file.readToEndAlloc(alloc, 1024);
    defer alloc.free(contents);
    var i: usize = 0;

    while (i < contents.len) : (i += 1) {
        const value = contents[i];
        if (Instruction.instructions[value]) |in| {
            try stdow.print("{s}\n", .{in.name});
            i += in.length - 1;
            if (value == 0xCB) {
                i += 1;
            }
        } else {
            try stdow.print("{X:02} not implemented\n", .{value});
        }
    }
}
