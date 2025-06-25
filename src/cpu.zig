const std = @import("std");

const DoubleU8Ptr = @import("common.zig").DoubleU8Ptr;
const InstructionOperands = @import("instructions.zig").InstructionOperands;

const FlagsRegister = packed struct(u8) {
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
    F: FlagsRegister = .{
        .zero = false,
        .carry = false,
        .half_carry = false,
        .sub = false,
        .rest = 0,
    },
    pc: u16,
    sp: u16,
    pub fn getFPtr(self: *Cpu) *u8 {
        return @ptrCast(&self.F);
    }

    pub fn init() Cpu {
        return Cpu{
            .A = 0,
            .B = 0,
            .C = 0,
            .D = 0,
            .E = 0,
            .H = 0,
            .L = 0,
            .pc = 0,
            .sp = 0,
        };
    }
    pub fn getU8Register(self: *Cpu, op: InstructionOperands) *u8 {
        return switch (op) {
            .A => &self.A,
            .B => &self.B,
            .C => &self.C,
            .D => &self.D,
            .E => &self.E,
            .H => &self.H,
            .L => &self.L,
            .F => self.getFPtr(),
            else => unreachable,
        };
    }
    pub fn getDoubleU8Register(self: *Cpu, op: InstructionOperands) DoubleU8Ptr {
        return switch (op) {
            .AF => DoubleU8Ptr{ .upper = &self.A, .lower = self.getFPtr() },
            .BC => DoubleU8Ptr{ .upper = &self.B, .lower = &self.C },
            .DE => DoubleU8Ptr{ .upper = &self.D, .lower = &self.E },
            .HL => DoubleU8Ptr{ .upper = &self.H, .lower = &self.L },

            else => unreachable,
        };
    }
    pub fn getU16Register(self: *Cpu, op: InstructionOperands) *u16 {
        return switch (op) {
            .PC => &self.pc,
            .SP => &self.sp,
            else => unreachable,
        };
    }

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
