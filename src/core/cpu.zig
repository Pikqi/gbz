const std = @import("std");

const DoubleU8Ptr = @import("common").DoubleU8Ptr;
const InstructionMod = @import("instructions.zig");
const InstructionOperands = InstructionMod.InstructionOperands;
const InstructionFlagRegister = InstructionMod.InstructionFlagRegister;
const InstructionFlag = InstructionMod.InstructionFlag;

pub const FlagsRegister = packed struct(u8) {
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
    pub fn setFlags(self: *FlagsRegister, f: InstructionFlagRegister) void {
        self.carry = setUnsetFlag(self.carry, f.carry);
        self.zero = setUnsetFlag(self.zero, f.zero);
        self.half_carry = setUnsetFlag(self.half_carry, f.half_carry);
        self.sub = setUnsetFlag(self.sub, f.sub);
        self.rest = 0;
    }
    fn setUnsetFlag(f: bool, flag: InstructionFlag) bool {
        return switch (flag) {
            .SET => true,
            .UNSET => false,
            else => f,
        };
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
    is_halted: bool = false,
    pub fn getFlagsRegister(self: *Cpu) *FlagsRegister {
        return @ptrCast(&self.AF.lower);
    }

    pub fn initZero() Cpu {
        return Cpu{
            .AF = .{ .lower = 0, .upper = 0 },
            .BC = .{ .lower = 0, .upper = 0 },
            .DE = .{ .lower = 0, .upper = 0 },
            .HL = .{ .lower = 0, .upper = 0 },
            .pc = 0,
            .sp = 0,
        };
    }
    pub fn initBootRom() Cpu {
        return Cpu{
            .AF = .{ .upper = 0x01, .lower = 0xB0 },
            .BC = .{ .upper = 0x00, .lower = 0x13 },
            .DE = .{ .upper = 0x00, .lower = 0xD8 },
            .HL = .{ .upper = 0x01, .lower = 0x4D },
            .pc = 0x0100,
            .sp = 0xFFFE,
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
    var c = Cpu.initZero();
    c.AF.lower = 0x43;
    c.AF.upper = 0xAB;

    try std.testing.expectEqual(0xAB43, c.AF.getWholePtr().*);
    c.AF.getWholePtr().* = 0x1234;

    try std.testing.expectEqual(0x12, c.AF.upper);
    try std.testing.expectEqual(0x34, c.AF.lower);
}
