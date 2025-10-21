const std = @import("std");

pub const cpu = @import("cpu.zig");
pub const emulator = @import("emulator.zig");
pub const instructions = @import("instructions.zig");
pub const mmu = @import("mmu.zig");

test "import" {
    _ = @import("cpu.zig");
    _ = @import("emulator.zig");
    _ = @import("instructions.zig");
    _ = @import("doctor.zig");
    _ = @import("mmu.zig");
    _ = @import("ppu.zig");
}
