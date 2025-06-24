const std = @import("std");
const Cartridge = @import("cartridge.zig").Cartridge;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var c = try Cartridge.loadFromFile("sample.gb", alloc);
    // c.printContentsBytes();
    try c.destroy();
}
