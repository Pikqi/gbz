const std = @import("std");

const FlagsRegister = packed struct {
    rest: u4 = 0,
    carry: bool,
    half_carry: bool,
    sub: bool,
    zero: bool,
    pub fn getByte(self: FlagsRegister) u8 {
        return @bitCast(self);
    }
    pub fn setByte(self: *FlagsRegister, value: u8) void {
        self.* = @bitCast(value);
    }
};

pub const Cpu = struct {
    A: u8,
    B: u8,
    C: u8,
    D: u8,
    E: u8,
    H: u8,
    L: u8,
    F: FlagsRegister,
    pc: u16,
    sp: u16,

    pub fn getAF(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.A)) << 8 | @as(u16, @intCast(self.F.getByte()));
    }
    pub fn setAF(self: *Cpu, value: u16) void {
        self.A = (value & 0xFF00) >> 8;
        self.F.setByte(value & 0xFF);
    }
    pub fn getBC(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.B)) << 8 | @as(u16, @intCast(self.C));
    }
    pub fn setBC(self: *Cpu, value: u16) void {
        self.B = (value & 0xFF00) >> 8;
        self.C = (value & 0xFF);
    }
    pub fn getDE(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.D)) << 8 | @as(u16, @intCast(self.E));
    }
    pub fn setDE(self: *Cpu, value: u16) void {
        self.D = (value & 0xFF00) >> 8;
        self.E = (value & 0xFF);
    }
    pub fn getHL(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.H)) << 8 | @as(u16, @intCast(self.L));
    }
    pub fn setHL(self: *Cpu, value: u16) void {
        self.H = (value & 0xFF00) >> 8;
        self.L = (value & 0xFF);
    }
};

test "Flags register as byte" {
    const f = FlagsRegister{
        .zero = true,
        .sub = false,
        .half_carry = true,
        .carry = false,
    };

    try std.testing.expectEqual(0b10100000, f.getByte());
}

test "Flags register set byte" {
    var f = FlagsRegister{
        .zero = true,
        .sub = false,
        .half_carry = true,
        .carry = false,
    };
    f.setByte(0b01100000);

    try std.testing.expectEqual(false, f.zero);
    try std.testing.expectEqual(true, f.sub);
    try std.testing.expectEqual(true, f.half_carry);
    try std.testing.expectEqual(false, f.carry);
}
