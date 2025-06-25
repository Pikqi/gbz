const std = @import("std");
const Cartridge = @import("cartridge.zig").Cartridge;

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
    increment: bool = false,
    decrement: bool = false,
    tcycle: u8,

    pub fn print(self: *const Instruction) void {
        std.debug.print("Instruction\n", .{});
        std.debug.print("Name {s}\n", .{self.name});
        std.debug.print("Type {s}\n", .{@tagName(self.type)});
        std.debug.print("leftOperand {s} isPtr {}\n", .{ @tagName(self.leftOperand), self.leftOperandPointer });
        std.debug.print("rightOperand {s} isPtr {}\n", .{ @tagName(self.rightOperand), self.rightOperandPointer });
        std.debug.print("number {?X:02}\nlenght {d}\n", .{ self.number, self.length });
    }
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
const InstructionCondition = enum {
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

const InstructionType = enum {
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
    RLA,
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
const InstructionFlag = enum {
    SET,
    UNSET,
    UNMODIFED,
    DEPENDENT,
};

const InstructionFlagRegister = struct {
    carry: InstructionFlag = .UNMODIFED,
    half_carry: InstructionFlag = .UNMODIFED,
    sub: InstructionFlag = .UNMODIFED,
    zero: InstructionFlag = .UNMODIFED,
};

pub const instructions: InstructionArray = blk: {
    var t_instructions: InstructionArray = undefined;
    for (&t_instructions) |*i| i.* = null;

    t_instructions[0x00] = Instruction{
        .name = "nop",
        .type = .NOP,
        .length = 1,
        .tcycle = 1,
    };
    t_instructions[0x01] = Instruction{
        .name = "LD BC, u16",
        .type = .LD,
        .length = 3,
        .leftOperand = .BC,
        .rightOperand = .U16,
        .tcycle = 3,
    };
    t_instructions[0x02] = Instruction{
        .name = "LD (BC), A",
        .type = .LD,
        .length = 1,
        .leftOperand = .BC,
        .leftOperandPointer = true,
        .rightOperand = .U16,
        .tcycle = 2,
    };
    t_instructions[0x03] = Instruction{
        .name = "INC BC",
        .type = .INC,
        .length = 1,
        .leftOperand = .BC,
        .tcycle = 2,
    };
    t_instructions[0x04] = Instruction{
        .name = "INC B",
        .type = .INC,
        .length = 1,
        .leftOperand = .B,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0x05] = Instruction{
        .name = "DEC B",
        .type = .DEC,
        .length = 1,
        .leftOperand = .B,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0x06] = Instruction{
        .name = "LD B,u8 - 0x06",
        .type = .LD,
        .length = 2,
        .leftOperand = .B,
        .rightOperand = .U8,
        .tcycle = 2,
    };

    t_instructions[0x07] = Instruction{
        .name = "RLCA - 0x07",
        .type = .RLC,
        .length = 1,
        .leftOperand = .A,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT },
    };
    t_instructions[0x08] = Instruction{
        .name = "LD (u16),SP - 0x08",
        .type = .LD,
        .length = 3,
        .leftOperand = .U16,
        .leftOperandPointer = true,
        .rightOperand = .SP,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT },
    };
    t_instructions[0x09] = Instruction{
        .name = "ADD HL,BC - 0x09",
        .type = .ADD,
        .length = 1,
        .leftOperand = .HL,
        .rightOperand = .BC,
        .tcycle = 2,
        .flags = .{
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x0A] = Instruction{
        .name = "LD A,(BC) - 0x0A",
        .type = .LD,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .BC,
        .rightOperandPointer = true,
        .tcycle = 2,
    };
    t_instructions[0x0B] = Instruction{
        .name = "DEC BC - 0x0B",
        .type = .DEC,
        .length = 1,
        .leftOperand = .BC,
        .tcycle = 2,
    };
    t_instructions[0x0C] = Instruction{
        .name = "INC C - 0x0C",
        .type = .INC,
        .length = 1,
        .leftOperand = .C,
        .tcycle = 1,
    };

    t_instructions[0x0D] = Instruction{
        .name = "DEC C - 0x0D",
        .type = .DEC,
        .length = 1,
        .leftOperand = .C,
        .tcycle = 1,
    };
    t_instructions[0x0E] = Instruction{
        .name = "LD C,u8 - 0x0E",
        .type = .LD,
        .length = 2,
        .leftOperand = .C,
        .rightOperand = .U8,
        .tcycle = 2,
    };
    t_instructions[0x0F] = Instruction{
        .name = "RRCA - 0x0F",
        .type = .RRC,
        .length = 1,
        .leftOperand = .A,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT },
    };

    //0x1X
    t_instructions[0x10] = Instruction{
        .name = "STOP - 0x10",
        .type = .STOP,
        .length = 1,
        .tcycle = 1,
    };
    t_instructions[0x11] = Instruction{
        .name = "LD DE,u16 - 0x11",
        .type = .LD,
        .leftOperand = .DE,
        .rightOperand = .U16,
        .length = 3,
        .tcycle = 1,
    };
    t_instructions[0x13] = Instruction{
        .name = "INC DE - 0x13",
        .type = .INC,
        .length = 1,
        .leftOperand = .DE,
        .tcycle = 2,
    };
    t_instructions[0x14] = Instruction{
        .name = "INC D - 0x14",
        .type = .INC,
        .length = 1,
        .leftOperand = .D,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
        },
    };

    t_instructions[0x15] = Instruction{
        .name = "DEC D - 0x15",
        .type = .DEC,
        .length = 1,
        .leftOperand = .C,
        .tcycle = 1,
        .flags = .{
            .sub = .SET,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0x16] = Instruction{
        .name = "LD D,u8 - 0x16",
        .type = .LD,
        .length = 2,
        .leftOperand = .D,
        .rightOperand = .U8,
        .tcycle = 2,
    };
    t_instructions[0x17] = Instruction{
        .name = "RLA - 0x17",
        .type = .RLA,
        .length = 1,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT },
    };
    t_instructions[0x18] = Instruction{
        .name = "JR i8 - 0x18",
        .type = .JR,
        .leftOperand = .I8,
        .length = 2,
        .tcycle = 3,
    };
    t_instructions[0x19] = Instruction{
        .name = "ADD HL,DE - 0x19",
        .type = .ADD,
        .length = 1,
        .leftOperand = .HL,
        .rightOperand = .DE,
        .tcycle = 2,
        .flags = .{
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x1A] = Instruction{
        .name = "LD A,(DE) - 0x1A",
        .type = .LD,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .DE,
        .rightOperandPointer = true,
        .tcycle = 2,
    };
    t_instructions[0x1B] = Instruction{
        .name = "DEC DE - 0x1B",
        .type = .DEC,
        .length = 1,
        .leftOperand = .DE,
        .tcycle = 2,
    };
    t_instructions[0x1C] = Instruction{
        .name = "INC E - 0x1C",
        .type = .INC,
        .length = 1,
        .leftOperand = .E,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0x1D] = Instruction{
        .name = "DEC E - 0x1D",
        .type = .DEC,
        .length = 1,
        .leftOperand = .E,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0x1E] = Instruction{
        .name = "LD E,u8 - 0x1E",
        .type = .LD,
        .length = 2,
        .leftOperand = .E,
        .rightOperand = .U8,
        .tcycle = 2,
    };

    t_instructions[0x1F] = Instruction{
        .name = "RRA - 0x1F",
        .type = .RR,
        .length = 1,
        .leftOperand = .A,
        .tcycle = 1,
        .flags = .{ .carry = .DEPENDENT },
    };

    // 0x2x

    t_instructions[0x20] = Instruction{
        .name = "JR NZ,i8 - 0x20",
        .type = .JR,
        .leftOperand = .I8,
        .condition = .NZ,
        .length = 2,
        .tcycle = 2,
    };

    t_instructions[0x21] = Instruction{
        .name = "LD HL,u16 - 0x21",
        .type = .LD,
        .length = 3,
        .leftOperand = .HL,
        .rightOperand = .U16,
        .tcycle = 3,
    };

    t_instructions[0x22] = Instruction{
        .name = "LD (HL+),A - 0x22",
        .type = .LD,
        .length = 1,
        .leftOperand = .HL,
        .rightOperand = .A,
        .increment = true,
        .tcycle = 2,
    };

    t_instructions[0x23] = Instruction{
        .name = "INC HL - 0x23",
        .type = .INC,
        .length = 1,
        .leftOperand = .HL,
        .tcycle = 2,
    };
    t_instructions[0x24] = Instruction{
        .name = "INC H - 0x24",
        .type = .INC,
        .length = 1,
        .leftOperand = .H,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x25] = Instruction{
        .name = "DEC H - 0x25",
        .type = .DEC,
        .length = 1,
        .leftOperand = .H,
        .tcycle = 1,
    };
    t_instructions[0x26] = Instruction{
        .name = "LD H,u8 - 0x26",
        .type = .LD,
        .length = 2,
        .leftOperand = .H,
        .rightOperand = .U8,
        .tcycle = 2,
    };
    t_instructions[0x27] = Instruction{
        .name = "DAA - 0x27",
        .type = .DAA,
        .length = 1,
        .tcycle = 1,
    };

    t_instructions[0x28] = Instruction{
        .name = "JR Z,i8 - 0x28",
        .type = .JR,
        .leftOperand = .I8,
        .condition = .Z,
        .length = 2,
        .tcycle = 3,
    };

    t_instructions[0x2E] = Instruction{
        .name = "LD L,u8 - 0x2E",
        .type = .LD,
        .length = 2,
        .leftOperand = .L,
        .rightOperand = .U8,
        .tcycle = 2,
    };
    t_instructions[0x2F] = Instruction{
        .name = "CPL - 0x2F",
        .type = .CPL,
        .length = 1,
        .leftOperand = .H,
        .tcycle = 1,
        .flags = .{
            .sub = .SET,
            .half_carry = .SET,
        },
    };
    //0x3x
    t_instructions[0x31] = Instruction{
        .name = "LD SP,u16 - 0x31",
        .type = .LD,
        .length = 3,
        .leftOperand = .SP,
        .rightOperand = .U16,
        .tcycle = 3,
    };

    t_instructions[0x32] = Instruction{
        .name = "LD (HL-),A - 0x32",
        .type = .LD,
        .length = 1,
        .decrement = true,
        .leftOperand = .HL,
        .rightOperand = .A,
        .tcycle = 2,
    };
    t_instructions[0x33] = Instruction{
        .name = "INC SP - 0x33",
        .type = .INC,
        .length = 1,
        .leftOperand = .SP,
        .tcycle = 2,
    };

    t_instructions[0x34] = Instruction{
        .name = "INC (HL) - 0x34",
        .type = .INC,
        .length = 1,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .tcycle = 3,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
        },
    };

    t_instructions[0x3C] = Instruction{
        .name = "INC A - 0x3C",
        .type = .INC,
        .length = 1,
        .leftOperand = .A,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x3D] = Instruction{
        .name = "DEC A - 0x3D",
        .type = .DEC,
        .length = 1,
        .leftOperand = .A,
        .tcycle = 1,
        .flags = .{ .zero = .DEPENDENT, .sub = .SET, .half_carry = .DEPENDENT },
    };
    t_instructions[0x3E] = Instruction{
        .name = "LD A,u8 - 0x3E",
        .type = .LD,
        .length = 2,
        .leftOperand = .A,
        .rightOperand = .U8,
        .tcycle = 2,
    };
    t_instructions[0x3D] = Instruction{
        .name = "DEC A - 0x3D",
        .type = .DEC,
        .length = 1,
        .leftOperand = .A,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0x3E] = Instruction{
        .name = "LD A,u8 - 0x3E",
        .type = .LD,
        .length = 2,
        .leftOperand = .A,
        .rightOperand = .U8,
        .tcycle = 2,
    };
    t_instructions[0x3F] = Instruction{
        .name = "CCF - 0x3F",
        .type = .CCF,
        .length = 2,
        .tcycle = 2,
        .flags = .{
            .sub = .UNSET,
            .half_carry = .UNSET,
            .carry = .DEPENDENT,
        },
    };
    // 0x4x

    t_instructions[0x40] = Instruction{
        .name = "LD B,B - 0x40",
        .type = .LD,
        .length = 1,
        .leftOperand = .B,
        .rightOperand = .B,
        .tcycle = 1,
    };
    t_instructions[0x42] = Instruction{
        .name = "LD B,D - 0x42",
        .type = .LD,
        .length = 1,
        .leftOperand = .B,
        .rightOperand = .D,
        .tcycle = 1,
    };

    t_instructions[0x44] = Instruction{
        .name = "LD B,H - 0x44",
        .type = .LD,
        .length = 1,
        .leftOperand = .B,
        .rightOperand = .H,
        .tcycle = 1,
    };
    t_instructions[0x47] = Instruction{
        .name = "LD B,A - 0x47",
        .type = .LD,
        .length = 1,
        .leftOperand = .B,
        .rightOperand = .A,
        .tcycle = 1,
    };

    t_instructions[0x4F] = Instruction{
        .name = "LD C,A - 0x4F",
        .type = .LD,
        .length = 1,
        .leftOperand = .C,
        .rightOperand = .A,
        .tcycle = 1,
    };
    t_instructions[0x57] = Instruction{
        .name = "LD D,A - 0x57",
        .type = .LD,
        .length = 1,
        .leftOperand = .D,
        .rightOperand = .A,
        .tcycle = 1,
    };

    t_instructions[0x62] = Instruction{
        .name = "LD H,D - 0x62",
        .type = .LD,
        .length = 1,
        .leftOperand = .H,
        .rightOperand = .D,
        .tcycle = 1,
    };

    t_instructions[0x63] = Instruction{
        .name = "LD H,E - 0x63",
        .type = .LD,
        .length = 1,
        .leftOperand = .H,
        .rightOperand = .E,
        .tcycle = 1,
    };
    t_instructions[0x64] = Instruction{
        .name = "LD H,H - 0x64",
        .type = .LD,
        .length = 1,
        .leftOperand = .H,
        .rightOperand = .H,
        .tcycle = 1,
    };
    t_instructions[0x66] = Instruction{
        .name = "LD H,(HL) - 0x66",
        .type = .LD,
        .length = 1,
        .leftOperand = .H,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .tcycle = 2,
    };
    t_instructions[0x67] = Instruction{
        .name = "LD H,A - 0x67",
        .type = .LD,
        .length = 1,
        .leftOperand = .H,
        .rightOperand = .A,
        .tcycle = 1,
    };
    t_instructions[0x6E] = Instruction{
        .name = "LD L,(HL) - 0x6E",
        .type = .LD,
        .length = 1,
        .leftOperand = .L,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .tcycle = 2,
    };
    t_instructions[0x73] = Instruction{
        .name = "LD (HL),E - 0x73",
        .type = .LD,
        .length = 1,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .E,
        .tcycle = 1,
    };
    t_instructions[0x77] = Instruction{
        .name = "LD (HL),A - 0x77",
        .type = .LD,
        .length = 1,
        .leftOperand = .HL,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .tcycle = 2,
    };
    t_instructions[0x78] = Instruction{
        .name = "LD A,B - 0x78",
        .type = .LD,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .B,
        .tcycle = 1,
    };
    t_instructions[0x7B] = Instruction{
        .name = "LD A,E - 0x7B",
        .type = .LD,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .E,
        .tcycle = 1,
    };
    t_instructions[0x7C] = Instruction{
        .name = "LD A,H - 0x7C",
        .type = .LD,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .H,
        .tcycle = 1,
    };
    t_instructions[0x7D] = Instruction{
        .name = "LD A,L - 0x7D",
        .type = .LD,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .L,
        .tcycle = 1,
    };
    //0x8x
    t_instructions[0x80] = Instruction{
        .name = "ADD A,B - 0x80",
        .type = .ADC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .B,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x83] = Instruction{
        .name = "ADD A,E - 0x83",
        .type = .ADC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .E,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x86] = Instruction{
        .name = "ADD A,(HL) - 0x86",
        .type = .ADC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x87] = Instruction{
        .name = "ADD A,A - 0x87",
        .type = .ADC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .A,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };

    t_instructions[0x88] = Instruction{
        .name = "ADC A,B - 0x88",
        .type = .ADC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .B,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x89] = Instruction{
        .name = "ADC A,C - 0x89",
        .type = .ADC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .C,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x90] = Instruction{
        .name = "SUB A,B - 0x90",
        .type = .SUB,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .B,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x91] = Instruction{
        .name = "SUB A,C - 0x91",
        .type = .SUB,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .C,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x95] = Instruction{
        .name = "SUB A,L - 0x95",
        .type = .SUB,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .L,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };

    t_instructions[0x96] = Instruction{
        .name = "SUB A,(HL) - 0x96",
        .type = .SUB,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x99] = Instruction{
        .name = "SBC A,C - 0x99",
        .type = .SBC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .C,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0x9F] = Instruction{
        .name = "SBC A,A - 0x9F",
        .type = .SBC,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .A,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    //0xAX

    t_instructions[0xAF] = Instruction{
        .name = "XOR A,A - 0xAF",
        .type = .XOR,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .A,
        .tcycle = 1,
    };
    t_instructions[0xA5] = Instruction{
        .name = "AND A,L - 0xA5",
        .type = .AND,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .L,
        .tcycle = 1,
    };

    //0xBx

    t_instructions[0xB9] = Instruction{
        .name = "CP A,C - 0xB9",
        .type = .CP,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .C,
        .tcycle = 1,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0xBB] = Instruction{
        .name = "CP A,E - 0xBB",
        .type = .CP,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .E,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    t_instructions[0xC1] = Instruction{
        .name = "POP BC - 0xC1",
        .type = .POP,
        .length = 1,
        .leftOperand = .BC,
        .tcycle = 3,
    };
    t_instructions[0xBE] = Instruction{
        .name = "CP A,(HL) - 0xBE",
        .type = .CP,
        .length = 1,
        .leftOperand = .A,
        .rightOperand = .HL,
        .rightOperandPointer = true,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .half_carry = .DEPENDENT,
            .carry = .DEPENDENT,
        },
    };
    //0xCX
    t_instructions[0xC5] = Instruction{
        .name = "PUSH BC - 0xC5",
        .type = .PUSH,
        .length = 1,
        .leftOperand = .BC,
        .tcycle = 4,
    };
    t_instructions[0xC9] = Instruction{
        .name = "RET - 0xC9",
        .type = .RET,
        .length = 1,
        .tcycle = 4,
    };
    t_instructions[0xCB] = Instruction{
        .name = "PREFIX CB - 0xCB",
        .type = .CB,
        .length = 1,
        .tcycle = 1,
    };
    t_instructions[0xCC] = Instruction{
        .name = "CALL Z,u16 - 0xCC",
        .type = .CALL,
        .length = 3,
        .leftOperand = .U16,
        .condition = .Z,
        .tcycle = 3,
    };
    t_instructions[0xCD] = Instruction{
        .name = "CALL u16 - 0xCD",
        .type = .CALL,
        .length = 3,
        .leftOperand = .U16,
        .tcycle = 6,
    };
    t_instructions[0xCE] = Instruction{
        .name = "ADC A,u8 - 0xCE",
        .type = .ADC,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
    };
    //0xDX
    t_instructions[0xD2] = Instruction{
        .name = "JP NC,u16 - 0xD2",
        .type = .JP,
        .leftOperand = .U16,
        .condition = .NC,
        .length = 3,
        .tcycle = 2,
    };

    t_instructions[0xD8] = Instruction{
        .name = "RET C - 0xD8",
        .type = .RET,
        .leftOperand = .C,
        .length = 1,
        .tcycle = 4,
    };
    t_instructions[0xD9] = Instruction{
        .name = "RETI - 0xD9",
        .type = .RETI,
        .length = 1,
        .tcycle = 4,
    };
    t_instructions[0xDC] = Instruction{
        .name = "CALL C,u16 - 0xDC",
        .type = .CALL,
        .length = 3,
        .leftOperand = .C,
        .rightOperand = .U16,
        .tcycle = 3,
    };

    //0xEX
    t_instructions[0xE0] = Instruction{
        .name = "LD (FF00+u8),A - 0xE0",
        .type = .LD,
        .length = 2,
        .leftOperand = .U8,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .offset_left = 0xFF00,
        .tcycle = 3,
    };
    t_instructions[0xE2] = Instruction{
        .name = "LD (FF00+C),A - 0xE2",
        .type = .LD,
        .length = 1,
        .leftOperand = .C,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .offset_left = 0xFF00,
        .tcycle = 3,
    };

    t_instructions[0xE6] = Instruction{
        .name = "AND A,u8 - 0xE6",
        .type = .AND,
        .length = 2,
        .leftOperand = .A,
        .rightOperand = .U8,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .UNSET,
            .half_carry = .SET,
            .carry = .UNSET,
        },
    };
    t_instructions[0xEA] = Instruction{
        .name = "LD (u16),A - 0xEA",
        .type = .LD,
        .length = 3,
        .leftOperand = .U16,
        .leftOperandPointer = true,
        .rightOperand = .A,
        .tcycle = 4,
    };
    //0xFX
    t_instructions[0xF0] = Instruction{
        .name = "LD A,(FF00+u8) - 0xF0",
        .type = .LD,
        .length = 2,
        .leftOperand = .A,
        .rightOperand = .U8,
        .rightOperandPointer = true,
        .offset_right = 0xFF00,
        .tcycle = 1,
    };
    t_instructions[0xF2] = Instruction{
        .name = "LD A,(FF00+C) - 0xF2",
        .type = .LD,
        .length = 1,
        .leftOperand = .U16,
        .leftOperandPointer = true,
        .rightOperand = .C,
        .offset_right = 0xFF00,
        .tcycle = 2,
    };
    t_instructions[0xF7] = Instruction{
        .name = "RST 30h - 0xF7",
        .type = .RST,
        .number = 0x30,
        .leftOperand = .NUMBER,
        .length = 1,
        .tcycle = 4,
    };
    t_instructions[0xFA] = Instruction{
        .name = "LD A,(u16) - 0xFA",
        .type = .LD,
        .leftOperand = .A,
        .rightOperand = .U16,
        .rightOperandPointer = true,
        .length = 3,
        .tcycle = 4,
    };

    t_instructions[0xFE] = Instruction{
        .name = "CP A,u8 - 0xFE",
        .type = .CP,
        .leftOperand = .A,
        .rightOperand = .U8,
        .length = 2,
        .tcycle = 2,
        .flags = .{
            .zero = .DEPENDENT,
            .sub = .SET,
            .carry = .DEPENDENT,
            .half_carry = .DEPENDENT,
        },
    };
    t_instructions[0xFF] = Instruction{
        .name = "RST 38h - 0xFF",
        .type = .RST,
        .number = 0x38,
        .leftOperand = .NUMBER,
        .length = 1,
        .tcycle = 4,
    };

    break :blk t_instructions;
};

test "1" {
    std.debug.print("0:{any}", .{instructions[0]});
}

test "dissasemble" {
    try Cartridge.loadFromFile("dmg_boot.bin", std.testing.allocator);
}
