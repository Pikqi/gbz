const std = @import("std");
const Cartridge = @import("cartridge.zig").Cartridge;

const Instruction = struct {
    name: []const u8,
    type: InstructionType,
    length: u8,
    leftOperand: InstructionOpperands = .NONE,
    leftOperandPointer: bool = false,
    rightOperand: InstructionOpperands = .NONE,
    rightOperandPointer: bool = false,
    flags: InstructionFlagRegister = .{},
    tcycle: u8,
};

const NUMBER_OF_INSTRUCTIONS = 0x100;

const InstructionArray = [NUMBER_OF_INSTRUCTIONS]?Instruction;

const InstructionOpperands = enum {
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

const instructions: InstructionArray = blk: {
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
        .rightOperand = .u8,
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

    break :blk t_instructions;
};

test "1" {
    std.debug.print("0:{any}", .{instructions[0]});
}

test "dissasemble" {
    try Cartridge.loadFromFile("dmg_boot.bin", std.testing.allocator);
}
