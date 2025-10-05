const std = @import("std");
const getOperandValue = @import("instruction_implementations.zig").getOperandValue;

pub const Instruction = struct {
    name: []const u8,
    type: InstructionType,
    length: u8,
    leftOperand: InstructionOperands = .NONE,
    leftOperandPointer: bool = false,
    rightOperand: InstructionOperands = .NONE,
    rightOperandPointer: bool = false,
    flags: InstructionFlagRegister = .{},
    condition: InstructionCondition = .NONE,
    offset_left: u16 = 0,
    offset_right: u16 = 0,
    number: ?u8 = null,
    increment: InstructionIncrement = .NONE,
    decrement: InstructionIncrement = .NONE,
    tcycle: u8,
    alt_tcycle: ?u8 = null,

    pub fn print(self: *const Instruction) void {
        std.debug.print("Instruction\n", .{});
        std.debug.print("Name {s}\n", .{self.name});
        std.debug.print("Type {s}\n", .{@tagName(self.type)});
        std.debug.print("leftOperand {s} isPtr {}\n", .{ @tagName(self.leftOperand), self.leftOperandPointer });
        std.debug.print("rightOperand {s} isPtr {}\n", .{ @tagName(self.rightOperand), self.rightOperandPointer });
        std.debug.print("number {?X:02}\nlenght {d}\n", .{ self.number, self.length });
    }
    pub fn print_short(self: *const Instruction) void {
        std.debug.print("{s} ", .{self.name});
        std.debug.print("\n\n", .{});
    }
};

pub const InstructionIncrement = enum {
    NONE,
    LEFT,
    RIGHT,
};
const NUMBER_OF_INSTRUCTIONS = 0x100;

pub const InstructionArray = [NUMBER_OF_INSTRUCTIONS]?Instruction;

pub const InstructionOperands = enum {
    NONE,
    A,
    B,
    C,
    D,
    E,
    F,
    H,
    L,
    AF,
    BC,
    DE,
    HL,
    PC,
    SP,
    U8,
    U16,
    I8,
    NUMBER,
};
pub const InstructionCondition = enum {
    NONE,
    C,
    NC,
    Z,
    NZ,
    M,
    P,
    PE,
    PO,
};

pub const InstructionType = enum {
    UNIMPLEMENTED,
    NOP,
    STOP,
    HALT,
    LD,
    INC,
    DEC,
    ADD,
    ADC,
    SUB,
    SBC,
    CP,
    AND,
    OR,
    XOR,
    CPL,
    BIT,
    RR,
    RL,
    RRC,
    RLC,
    SLA,
    SRA,
    SRL,
    SWAP,
    RES,
    SET_OP,
    JP,
    JR,
    RET,
    RETI,
    CALL,
    RST,
    PUSH,
    POP,
    CCF,
    SCF,
    CB,
    DI,
    EI,
    DAA,
};
pub const InstructionFlag = enum {
    SET,
    UNSET,
    UNMODIFED,
    DEPENDENT,
};

pub const InstructionFlagRegister = struct {
    carry: InstructionFlag = .UNMODIFED,
    half_carry: InstructionFlag = .UNMODIFED,
    sub: InstructionFlag = .UNMODIFED,
    zero: InstructionFlag = .UNMODIFED,
};

pub const instructions: InstructionArray = blk: {
    var t_instructions: InstructionArray = undefined;
    for (&t_instructions) |*i| i.* = null;

    t_instructions[0x0] = Instruction{
        .name = "NOP  - 0x0",
        .type = .NOP,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x1] = Instruction{
        .name = "LD BC,U16 - 0x1",
        .type = .LD,
        .leftOperand = .BC,
        .rightOperand = .U16,
        .length = 3,
        .tcycle = 3,
    };

    t_instructions[0x2] = Instruction{
        .name = "LD (BC),A - 0x2",
        .type = .LD,
        .leftOperand = .BC,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x3] = Instruction{
        .name = "INC BC - 0x3",
        .type = .INC,
        .leftOperand = .BC,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x4] = Instruction{
        .name = "INC B - 0x4",
        .type = .INC,
        .leftOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x5] = Instruction{
        .name = "DEC B - 0x5",
        .type = .DEC,
        .leftOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x6] = Instruction{
        .name = "LD B,U8 - 0x6",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x7] = Instruction{
        .name = "RLC A - 0x7",
        .type = .RLC,
        .leftOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .UNSET, .sub = .UNSET, .zero = .UNSET },
    };

    t_instructions[0x8] = Instruction{
        .name = "LD (U16),SP - 0x8",
        .type = .LD,
        .leftOperand = .U16,
        .leftOperandPointer = true,
        .rightOperand = .SP,
        .length = 3,
        .tcycle = 5,
    };

    t_instructions[0x9] = Instruction{
        .name = "ADD HL,BC - 0x9",
        .type = .ADD,
        .leftOperand = .HL,
        .rightOperand = .BC,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .UNMODIFED },
    };

    t_instructions[0xA] = Instruction{
        .name = "LD A,(BC) - 0xA",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .BC,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0xB] = Instruction{
        .name = "DEC BC - 0xB",
        .type = .DEC,
        .leftOperand = .BC,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0xC] = Instruction{
        .name = "INC C - 0xC",
        .type = .INC,
        .leftOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xD] = Instruction{
        .name = "DEC C - 0xD",
        .type = .DEC,
        .leftOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xE] = Instruction{
        .name = "LD C,U8 - 0xE",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0xF] = Instruction{
        .name = "RRC A - 0xF",
        .type = .RRC,
        .leftOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .UNSET, .sub = .UNSET, .zero = .UNSET },
    };

    t_instructions[0x10] = Instruction{
        .name = "STOP U8 - 0x10",
        .type = .STOP,
        .leftOperand = .U8,
        .length = 2,
        .tcycle = 1,
    };

    t_instructions[0x11] = Instruction{
        .name = "LD DE,U16 - 0x11",
        .type = .LD,
        .leftOperand = .DE,
        .rightOperand = .U16,
        .length = 3,
        .tcycle = 3,
    };

    t_instructions[0x12] = Instruction{
        .name = "LD (DE),A - 0x12",
        .type = .LD,
        .leftOperand = .DE,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x13] = Instruction{
        .name = "INC DE - 0x13",
        .type = .INC,
        .leftOperand = .DE,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x14] = Instruction{
        .name = "INC D - 0x14",
        .type = .INC,
        .leftOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x15] = Instruction{
        .name = "DEC D - 0x15",
        .type = .DEC,
        .leftOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x16] = Instruction{
        .name = "LD D,U8 - 0x16",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x17] = Instruction{
        .name = "RL A - 0x17",
        .type = .RL,
        .leftOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .UNSET, .sub = .UNSET, .zero = .UNSET },
    };

    t_instructions[0x18] = Instruction{
        .name = "JR I8 - 0x18",
        .type = .JR,
        .leftOperand = .I8,
        .length = 2,
        .tcycle = 3,
    };

    t_instructions[0x19] = Instruction{
        .name = "ADD HL,DE - 0x19",
        .type = .ADD,
        .leftOperand = .HL,
        .rightOperand = .DE,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .UNMODIFED },
    };

    t_instructions[0x1A] = Instruction{
        .name = "LD A,(DE) - 0x1A",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .DE,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x1B] = Instruction{
        .name = "DEC DE - 0x1B",
        .type = .DEC,
        .leftOperand = .DE,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x1C] = Instruction{
        .name = "INC E - 0x1C",
        .type = .INC,
        .leftOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x1D] = Instruction{
        .name = "DEC E - 0x1D",
        .type = .DEC,
        .leftOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x1E] = Instruction{
        .name = "LD E,U8 - 0x1E",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x1F] = Instruction{
        .name = "RR A - 0x1F",
        .type = .RR,
        .leftOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .UNSET, .sub = .UNSET, .zero = .UNSET },
    };

    t_instructions[0x20] = Instruction{
        .name = "JR NZ, I8 - 0x20",
        .type = .JR,
        .leftOperand = .I8,
        .condition = .NZ,
        .length = 2,
        .tcycle = 3,
        .alt_tcycle = 2,
    };

    t_instructions[0x21] = Instruction{
        .name = "LD HL,U16 - 0x21",
        .type = .LD,
        .leftOperand = .HL,
        .rightOperand = .U16,
        .length = 3,
        .tcycle = 3,
    };

    t_instructions[0x22] = Instruction{
        .name = "LD (HL),A - 0x22",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x23] = Instruction{
        .name = "INC HL - 0x23",
        .type = .INC,
        .leftOperand = .HL,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x24] = Instruction{
        .name = "INC H - 0x24",
        .type = .INC,
        .leftOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x25] = Instruction{
        .name = "DEC H - 0x25",
        .type = .DEC,
        .leftOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x26] = Instruction{
        .name = "LD H,U8 - 0x26",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x27] = Instruction{
        .name = "DAA  - 0x27",
        .type = .DAA,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .UNSET, .sub = .UNMODIFED, .zero = .DEPENDENT },
    };

    t_instructions[0x28] = Instruction{
        .name = "JR Z, I8 - 0x28",
        .type = .JR,
        .leftOperand = .I8,
        .condition = .Z,
        .length = 2,
        .tcycle = 3,
        .alt_tcycle = 2,
    };

    t_instructions[0x29] = Instruction{
        .name = "ADD HL,HL - 0x29",
        .type = .ADD,
        .leftOperand = .HL,
        .rightOperand = .HL,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .UNMODIFED },
    };

    t_instructions[0x2A] = Instruction{
        .name = "LD A,(HL) - 0x2A",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x2B] = Instruction{
        .name = "DEC HL - 0x2B",
        .type = .DEC,
        .leftOperand = .HL,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x2C] = Instruction{
        .name = "INC L - 0x2C",
        .type = .INC,
        .leftOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x2D] = Instruction{
        .name = "DEC L - 0x2D",
        .type = .DEC,
        .leftOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x2E] = Instruction{
        .name = "LD L,U8 - 0x2E",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x2F] = Instruction{
        .name = "CPL  - 0x2F",
        .type = .CPL,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .SET, .sub = .SET, .zero = .UNMODIFED },
    };

    t_instructions[0x30] = Instruction{
        .name = "JR NC, I8 - 0x30",
        .type = .JR,
        .leftOperand = .I8,
        .condition = .NC,
        .length = 2,
        .tcycle = 3,
        .alt_tcycle = 2,
    };

    t_instructions[0x31] = Instruction{
        .name = "LD SP,U16 - 0x31",
        .type = .LD,
        .leftOperand = .SP,
        .rightOperand = .U16,
        .length = 3,
        .tcycle = 3,
    };

    t_instructions[0x32] = Instruction{
        .name = "LD (HL),A - 0x32",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x33] = Instruction{
        .name = "INC SP - 0x33",
        .type = .INC,
        .leftOperand = .SP,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x34] = Instruction{
        .name = "INC (HL) - 0x34",
        .type = .INC,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .length = 1,
        .tcycle = 3,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x35] = Instruction{
        .name = "DEC (HL) - 0x35",
        .type = .DEC,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .length = 1,
        .tcycle = 3,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x36] = Instruction{
        .name = "LD (HL),U8 - 0x36",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 3,
    };

    t_instructions[0x37] = Instruction{
        .name = "SCF  - 0x37",
        .type = .SCF,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .SET, .half_carry = .UNSET, .sub = .UNSET, .zero = .UNMODIFED },
    };

    t_instructions[0x38] = Instruction{
        .name = "JR C, I8 - 0x38",
        .type = .JR,
        .leftOperand = .I8,
        .condition = .C,
        .length = 2,
        .tcycle = 3,
        .alt_tcycle = 2,
    };

    t_instructions[0x39] = Instruction{
        .name = "ADD HL,SP - 0x39",
        .type = .ADD,
        .leftOperand = .HL,
        .rightOperand = .SP,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .UNMODIFED },
    };

    t_instructions[0x3A] = Instruction{
        .name = "LD A,(HL) - 0x3A",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x3B] = Instruction{
        .name = "DEC SP - 0x3B",
        .type = .DEC,
        .leftOperand = .SP,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x3C] = Instruction{
        .name = "INC A - 0x3C",
        .type = .INC,
        .leftOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x3D] = Instruction{
        .name = "DEC A - 0x3D",
        .type = .DEC,
        .leftOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x3E] = Instruction{
        .name = "LD A,U8 - 0x3E",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x3F] = Instruction{
        .name = "CCF  - 0x3F",
        .type = .CCF,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .UNSET, .sub = .UNSET, .zero = .UNMODIFED },
    };

    t_instructions[0x40] = Instruction{
        .name = "LD B,B - 0x40",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x41] = Instruction{
        .name = "LD B,C - 0x41",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x42] = Instruction{
        .name = "LD B,D - 0x42",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x43] = Instruction{
        .name = "LD B,E - 0x43",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x44] = Instruction{
        .name = "LD B,H - 0x44",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x45] = Instruction{
        .name = "LD B,L - 0x45",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x46] = Instruction{
        .name = "LD B,(HL) - 0x46",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x47] = Instruction{
        .name = "LD B,A - 0x47",
        .type = .LD,
        .leftOperand = .B,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x48] = Instruction{
        .name = "LD C,B - 0x48",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x49] = Instruction{
        .name = "LD C,C - 0x49",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x4A] = Instruction{
        .name = "LD C,D - 0x4A",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x4B] = Instruction{
        .name = "LD C,E - 0x4B",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x4C] = Instruction{
        .name = "LD C,H - 0x4C",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x4D] = Instruction{
        .name = "LD C,L - 0x4D",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x4E] = Instruction{
        .name = "LD C,(HL) - 0x4E",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x4F] = Instruction{
        .name = "LD C,A - 0x4F",
        .type = .LD,
        .leftOperand = .C,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x50] = Instruction{
        .name = "LD D,B - 0x50",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x51] = Instruction{
        .name = "LD D,C - 0x51",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x52] = Instruction{
        .name = "LD D,D - 0x52",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x53] = Instruction{
        .name = "LD D,E - 0x53",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x54] = Instruction{
        .name = "LD D,H - 0x54",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x55] = Instruction{
        .name = "LD D,L - 0x55",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x56] = Instruction{
        .name = "LD D,(HL) - 0x56",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x57] = Instruction{
        .name = "LD D,A - 0x57",
        .type = .LD,
        .leftOperand = .D,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x58] = Instruction{
        .name = "LD E,B - 0x58",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x59] = Instruction{
        .name = "LD E,C - 0x59",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x5A] = Instruction{
        .name = "LD E,D - 0x5A",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x5B] = Instruction{
        .name = "LD E,E - 0x5B",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x5C] = Instruction{
        .name = "LD E,H - 0x5C",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x5D] = Instruction{
        .name = "LD E,L - 0x5D",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x5E] = Instruction{
        .name = "LD E,(HL) - 0x5E",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x5F] = Instruction{
        .name = "LD E,A - 0x5F",
        .type = .LD,
        .leftOperand = .E,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x60] = Instruction{
        .name = "LD H,B - 0x60",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x61] = Instruction{
        .name = "LD H,C - 0x61",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x62] = Instruction{
        .name = "LD H,D - 0x62",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x63] = Instruction{
        .name = "LD H,E - 0x63",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x64] = Instruction{
        .name = "LD H,H - 0x64",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x65] = Instruction{
        .name = "LD H,L - 0x65",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x66] = Instruction{
        .name = "LD H,(HL) - 0x66",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x67] = Instruction{
        .name = "LD H,A - 0x67",
        .type = .LD,
        .leftOperand = .H,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x68] = Instruction{
        .name = "LD L,B - 0x68",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x69] = Instruction{
        .name = "LD L,C - 0x69",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x6A] = Instruction{
        .name = "LD L,D - 0x6A",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x6B] = Instruction{
        .name = "LD L,E - 0x6B",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x6C] = Instruction{
        .name = "LD L,H - 0x6C",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x6D] = Instruction{
        .name = "LD L,L - 0x6D",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x6E] = Instruction{
        .name = "LD L,(HL) - 0x6E",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x6F] = Instruction{
        .name = "LD L,A - 0x6F",
        .type = .LD,
        .leftOperand = .L,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x70] = Instruction{
        .name = "LD (HL),B - 0x70",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x71] = Instruction{
        .name = "LD (HL),C - 0x71",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x72] = Instruction{
        .name = "LD (HL),D - 0x72",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x73] = Instruction{
        .name = "LD (HL),E - 0x73",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x74] = Instruction{
        .name = "LD (HL),H - 0x74",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x75] = Instruction{
        .name = "LD (HL),L - 0x75",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x76] = Instruction{
        .name = "HALT  - 0x76",
        .type = .HALT,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x77] = Instruction{
        .name = "LD (HL),A - 0x77",
        .type = .LD,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x78] = Instruction{
        .name = "LD A,B - 0x78",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x79] = Instruction{
        .name = "LD A,C - 0x79",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x7A] = Instruction{
        .name = "LD A,D - 0x7A",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x7B] = Instruction{
        .name = "LD A,E - 0x7B",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x7C] = Instruction{
        .name = "LD A,H - 0x7C",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x7D] = Instruction{
        .name = "LD A,L - 0x7D",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x7E] = Instruction{
        .name = "LD A,(HL) - 0x7E",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0x7F] = Instruction{
        .name = "LD A,A - 0x7F",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x80] = Instruction{
        .name = "ADD A,B - 0x80",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x81] = Instruction{
        .name = "ADD A,C - 0x81",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x82] = Instruction{
        .name = "ADD A,D - 0x82",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x83] = Instruction{
        .name = "ADD A,E - 0x83",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x84] = Instruction{
        .name = "ADD A,H - 0x84",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x85] = Instruction{
        .name = "ADD A,L - 0x85",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x86] = Instruction{
        .name = "ADD A,(HL) - 0x86",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x87] = Instruction{
        .name = "ADD A,A - 0x87",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x88] = Instruction{
        .name = "ADC A,B - 0x88",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x89] = Instruction{
        .name = "ADC A,C - 0x89",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x8A] = Instruction{
        .name = "ADC A,D - 0x8A",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x8B] = Instruction{
        .name = "ADC A,E - 0x8B",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x8C] = Instruction{
        .name = "ADC A,H - 0x8C",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x8D] = Instruction{
        .name = "ADC A,L - 0x8D",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x8E] = Instruction{
        .name = "ADC A,(HL) - 0x8E",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x8F] = Instruction{
        .name = "ADC A,A - 0x8F",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0x90] = Instruction{
        .name = "SUB A,B - 0x90",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x91] = Instruction{
        .name = "SUB A,C - 0x91",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x92] = Instruction{
        .name = "SUB A,D - 0x92",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x93] = Instruction{
        .name = "SUB A,E - 0x93",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x94] = Instruction{
        .name = "SUB A,H - 0x94",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x95] = Instruction{
        .name = "SUB A,L - 0x95",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x96] = Instruction{
        .name = "SUB A,(HL) - 0x96",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x97] = Instruction{
        .name = "SUB A,A - 0x97",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .SET, .zero = .SET },
    };

    t_instructions[0x98] = Instruction{
        .name = "SBC A,B - 0x98",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x99] = Instruction{
        .name = "SBC A,C - 0x99",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x9A] = Instruction{
        .name = "SBC A,D - 0x9A",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x9B] = Instruction{
        .name = "SBC A,E - 0x9B",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x9C] = Instruction{
        .name = "SBC A,H - 0x9C",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x9D] = Instruction{
        .name = "SBC A,L - 0x9D",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x9E] = Instruction{
        .name = "SBC A,(HL) - 0x9E",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0x9F] = Instruction{
        .name = "SBC A,A - 0x9F",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNMODIFED, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xA0] = Instruction{
        .name = "AND A,B - 0xA0",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA1] = Instruction{
        .name = "AND A,C - 0xA1",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA2] = Instruction{
        .name = "AND A,D - 0xA2",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA3] = Instruction{
        .name = "AND A,E - 0xA3",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA4] = Instruction{
        .name = "AND A,H - 0xA4",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA5] = Instruction{
        .name = "AND A,L - 0xA5",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA6] = Instruction{
        .name = "AND A,(HL) - 0xA6",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA7] = Instruction{
        .name = "AND A,A - 0xA7",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA8] = Instruction{
        .name = "XOR A,B - 0xA8",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xA9] = Instruction{
        .name = "XOR A,C - 0xA9",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xAA] = Instruction{
        .name = "XOR A,D - 0xAA",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xAB] = Instruction{
        .name = "XOR A,E - 0xAB",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xAC] = Instruction{
        .name = "XOR A,H - 0xAC",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xAD] = Instruction{
        .name = "XOR A,L - 0xAD",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xAE] = Instruction{
        .name = "XOR A,(HL) - 0xAE",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xAF] = Instruction{
        .name = "XOR A,A - 0xAF",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .SET },
    };

    t_instructions[0xB0] = Instruction{
        .name = "OR A,B - 0xB0",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB1] = Instruction{
        .name = "OR A,C - 0xB1",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB2] = Instruction{
        .name = "OR A,D - 0xB2",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB3] = Instruction{
        .name = "OR A,E - 0xB3",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB4] = Instruction{
        .name = "OR A,H - 0xB4",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB5] = Instruction{
        .name = "OR A,L - 0xB5",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB6] = Instruction{
        .name = "OR A,(HL) - 0xB6",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB7] = Instruction{
        .name = "OR A,A - 0xB7",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xB8] = Instruction{
        .name = "CP A,B - 0xB8",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .B,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xB9] = Instruction{
        .name = "CP A,C - 0xB9",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .C,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xBA] = Instruction{
        .name = "CP A,D - 0xBA",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .D,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xBB] = Instruction{
        .name = "CP A,E - 0xBB",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .E,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xBC] = Instruction{
        .name = "CP A,H - 0xBC",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .H,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xBD] = Instruction{
        .name = "CP A,L - 0xBD",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .L,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xBE] = Instruction{
        .name = "CP A,(HL) - 0xBE",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .length = 1,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xBF] = Instruction{
        .name = "CP A,A - 0xBF",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .A,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .SET, .zero = .SET },
    };

    t_instructions[0xC0] = Instruction{
        .name = "RET  - 0xC0",
        .type = .RET,
        .length = 1,
        .tcycle = 5,
        .alt_tcycle = 2,
    };

    t_instructions[0xC1] = Instruction{
        .name = "POP BC - 0xC1",
        .type = .POP,
        .leftOperand = .BC,
        .length = 1,
        .tcycle = 3,
    };

    t_instructions[0xC2] = Instruction{
        .name = "JP NZ, U16 - 0xC2",
        .type = .JP,
        .leftOperand = .U16,
        .condition = .NZ,
        .length = 3,
        .tcycle = 4,
        .alt_tcycle = 3,
    };

    t_instructions[0xC3] = Instruction{
        .name = "JP U16 - 0xC3",
        .type = .JP,
        .leftOperand = .U16,
        .length = 3,
        .tcycle = 4,
    };

    t_instructions[0xC4] = Instruction{
        .name = "CALL NZ, U16 - 0xC4",
        .type = .CALL,
        .leftOperand = .U16,
        .condition = .NZ,
        .length = 3,
        .tcycle = 6,
        .alt_tcycle = 3,
    };

    t_instructions[0xC5] = Instruction{
        .name = "PUSH BC - 0xC5",
        .type = .PUSH,
        .leftOperand = .BC,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xC6] = Instruction{
        .name = "ADD A,U8 - 0xC6",
        .type = .ADD,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xC7] = Instruction{
        .name = "RST 0 - 0xC7",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x0,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xC8] = Instruction{
        .name = "RET  - 0xC8",
        .type = .RET,
        .length = 1,
        .tcycle = 5,
        .alt_tcycle = 2,
    };

    t_instructions[0xC9] = Instruction{
        .name = "RET  - 0xC9",
        .type = .RET,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xCA] = Instruction{
        .name = "JP Z, U16 - 0xCA",
        .type = .JP,
        .leftOperand = .U16,
        .condition = .Z,
        .length = 3,
        .tcycle = 4,
        .alt_tcycle = 3,
    };

    t_instructions[0xCB] = Instruction{
        .name = "CB  - 0xCB",
        .type = .CB,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0xCC] = Instruction{
        .name = "CALL Z, U16 - 0xCC",
        .type = .CALL,
        .leftOperand = .U16,
        .condition = .Z,
        .length = 3,
        .tcycle = 6,
        .alt_tcycle = 3,
    };

    t_instructions[0xCD] = Instruction{
        .name = "CALL U16 - 0xCD",
        .type = .CALL,
        .leftOperand = .U16,
        .length = 3,
        .tcycle = 6,
    };

    t_instructions[0xCE] = Instruction{
        .name = "ADC A,U8 - 0xCE",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xCF] = Instruction{
        .name = "RST 8 - 0xCF",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x8,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xD0] = Instruction{
        .name = "RET  - 0xD0",
        .type = .RET,
        .length = 1,
        .tcycle = 5,
        .alt_tcycle = 2,
    };

    t_instructions[0xD1] = Instruction{
        .name = "POP DE - 0xD1",
        .type = .POP,
        .leftOperand = .DE,
        .length = 1,
        .tcycle = 3,
    };

    t_instructions[0xD2] = Instruction{
        .name = "JP NC, U16 - 0xD2",
        .type = .JP,
        .leftOperand = .U16,
        .condition = .NC,
        .length = 3,
        .tcycle = 4,
        .alt_tcycle = 3,
    };

    t_instructions[0xD4] = Instruction{
        .name = "CALL NC, U16 - 0xD4",
        .type = .CALL,
        .leftOperand = .U16,
        .condition = .NC,
        .length = 3,
        .tcycle = 6,
        .alt_tcycle = 3,
    };

    t_instructions[0xD5] = Instruction{
        .name = "PUSH DE - 0xD5",
        .type = .PUSH,
        .leftOperand = .DE,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xD6] = Instruction{
        .name = "SUB A,U8 - 0xD6",
        .type = .SUB,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xD7] = Instruction{
        .name = "RST 16 - 0xD7",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x10,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xD8] = Instruction{
        .name = "RET C - 0xD8",
        .type = .RET,
        .leftOperand = .C,
        .length = 1,
        .tcycle = 5,
        .alt_tcycle = 2,
    };

    t_instructions[0xD9] = Instruction{
        .name = "RETI  - 0xD9",
        .type = .RETI,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xDA] = Instruction{
        .name = "JP C, U16 - 0xDA",
        .type = .JP,
        .leftOperand = .U16,
        .condition = .C,
        .length = 3,
        .tcycle = 4,
        .alt_tcycle = 3,
    };

    t_instructions[0xDC] = Instruction{
        .name = "CALL C, U16 - 0xDC",
        .type = .CALL,
        .leftOperand = .U16,
        .condition = .C,
        .length = 3,
        .tcycle = 6,
        .alt_tcycle = 3,
    };

    t_instructions[0xDE] = Instruction{
        .name = "SBC A,U8 - 0xDE",
        .type = .SBC,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xDF] = Instruction{
        .name = "RST 24 - 0xDF",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x18,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xE0] = Instruction{
        .name = "LD (FF00+U8),A - 0xE0",
        .type = .LD,
        .leftOperand = .U8,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .offset_left = 0xFF00,
        .length = 2,
        .tcycle = 3,
    };

    t_instructions[0xE1] = Instruction{
        .name = "POP HL - 0xE1",
        .type = .POP,
        .leftOperand = .HL,
        .length = 1,
        .tcycle = 3,
    };

    t_instructions[0xE2] = Instruction{
        .name = "LD (FF00+C),A - 0xE2",
        .type = .LD,
        .leftOperand = .C,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .offset_left = 0xFF00,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0xE5] = Instruction{
        .name = "PUSH HL - 0xE5",
        .type = .PUSH,
        .leftOperand = .HL,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xE6] = Instruction{
        .name = "AND A,U8 - 0xE6",
        .type = .AND,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .UNSET, .half_carry = .SET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xE7] = Instruction{
        .name = "RST 32 - 0xE7",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x20,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xE8] = Instruction{
        .name = "ADD SP,I8 - 0xE8",
        .type = .ADD,
        .leftOperand = .SP,
        .rightOperand = .I8,
        .length = 2,
        .tcycle = 4,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .UNSET },
    };

    t_instructions[0xE9] = Instruction{
        .name = "JP HL - 0xE9",
        .type = .JP,
        .leftOperand = .HL,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0xEA] = Instruction{
        .name = "LD (U16),A - 0xEA",
        .type = .LD,
        .leftOperand = .U16,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .length = 3,
        .tcycle = 4,
    };

    t_instructions[0xEE] = Instruction{
        .name = "XOR A,U8 - 0xEE",
        .type = .XOR,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xEF] = Instruction{
        .name = "RST 40 - 0xEF",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x28,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xF0] = Instruction{
        .name = "LD A,(FF00+U8) - 0xF0",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .U8,
        .rightOperandPointer = true,
        .offset_right = 0xFF00,
        .length = 2,
        .tcycle = 3,
    };

    t_instructions[0xF1] = Instruction{
        .name = "POP AF - 0xF1",
        .type = .POP,
        .leftOperand = .AF,
        .length = 1,
        .tcycle = 3,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .DEPENDENT, .zero = .DEPENDENT },
    };

    t_instructions[0xF2] = Instruction{
        .name = "LD A,(FF00+C) - 0xF2",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .C,
        .rightOperandPointer = true,
        .offset_right = 0xFF00,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0xF3] = Instruction{
        .name = "DI  - 0xF3",
        .type = .DI,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0xF5] = Instruction{
        .name = "PUSH AF - 0xF5",
        .type = .PUSH,
        .leftOperand = .AF,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xF6] = Instruction{
        .name = "OR A,U8 - 0xF6",
        .type = .OR,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .UNSET, .half_carry = .UNSET, .sub = .UNSET, .zero = .DEPENDENT },
    };

    t_instructions[0xF7] = Instruction{
        .name = "RST 48 - 0xF7",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x30,
        .length = 1,
        .tcycle = 4,
    };

    t_instructions[0xF8] = Instruction{
        .name = "LD  - 0xF8",
        .type = .LD,
        .length = 2,
        .tcycle = 3,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .UNSET, .zero = .UNSET },
    };

    t_instructions[0xF9] = Instruction{
        .name = "LD SP,HL - 0xF9",
        .type = .LD,
        .leftOperand = .SP,
        .rightOperand = .HL,
        .length = 1,
        .tcycle = 2,
    };

    t_instructions[0xFA] = Instruction{
        .name = "LD A,(U16) - 0xFA",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .U16,
        .rightOperandPointer = true,
        .length = 3,
        .tcycle = 4,
    };

    t_instructions[0xFB] = Instruction{
        .name = "EI  - 0xFB",
        .type = .EI,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0xFE] = Instruction{
        .name = "CP A,U8 - 0xFE",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{ .carry = .DEPENDENT, .half_carry = .DEPENDENT, .sub = .SET, .zero = .DEPENDENT },
    };

    t_instructions[0xFF] = Instruction{
        .name = "RST 56 - 0xFF",
        .type = .RST,
        .leftOperand = .NUMBER,
        .number = 0x38,
        .length = 1,
        .tcycle = 4,
    };

    break :blk t_instructions;
};
test "1" {
    var i: usize = 0;
    for (instructions) |in| {
        if (in != null) {
            i += 1;
        }
    }
    std.debug.print("number of instructions: {d}", .{i});
}
