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

pub const DoubleRegister = packed struct(u16) {
    lower: u8,
    upper: u8,
    pub fn getWholePtr(self: *DoubleRegister) *u16 {
        return @ptrCast(self);
    }
};

pub const Cpu = struct {
    AF: DoubleRegister,
    BC: DoubleRegister,
    DE: DoubleRegister,
    HL: DoubleRegister,

    pc: u16,
    sp: u16,

    pub fn init() Cpu {
        return Cpu{
            .AF = .{ .lower = 0, .upper = 0 },
            .BC = .{ .lower = 0, .upper = 0 },
            .DE = .{ .lower = 0, .upper = 0 },
            .HL = .{ .lower = 0, .upper = 0 },
            .pc = 0,
            .sp = 0,
        };
    }
    pub fn getU8Register(self: *Cpu, op: InstructionOperands) *u8 {
        return switch (op) {
            .A => &self.AF.upper,
            .B => &self.BC.upper,
            .C => &self.BC.lower,
            .D => &self.DE.upper,
            .E => &self.DE.lower,
            .H => &self.HL.upper,
            .L => &self.HL.lower,
            .F => &self.AF.lower,
            else => unreachable,
        };
    }
    pub fn getU16Register(self: *Cpu, op: InstructionOperands) *u16 {
        return switch (op) {
            .AF => self.AF.getWholePtr(),
            .BC => self.BC.getWholePtr(),
            .DE => self.DE.getWholePtr(),
            .HL => self.HL.getWholePtr(),
            .PC => &self.pc,
            .SP => &self.sp,
            else => unreachable,
        };
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

test "Double Register" {
    var c = Cpu.init();
    c.AF.lower = 0x43;
    c.AF.upper = 0xAB;

    try std.testing.expectEqual(0xAB43, c.AF.getWholePtr().*);
    c.AF.getWholePtr().* = 0x1234;

    try std.testing.expectEqual(0x12, c.AF.upper);
    try std.testing.expectEqual(0x34, c.AF.lower);
}
