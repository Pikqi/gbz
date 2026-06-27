const std = @import("std");

const Emulator = @import("emulator.zig").Emulator;

// DIV incremented once per 256 tcycles
// TIMA is incremented depending on TAC register. from every 4 mcycles to 256 mcycles

// TODO Additionally, this register is reset when executing the stop instruction, and only begins ticking again once stop mode ends.
// https://gbdev.io/pandocs/Timer_and_Divider_Registers.html

pub const Timer = struct {
    div_remainder_cycles: u64 = 0,
    tima_remainder_cycles: u64 = 0,

    pub fn onDivWrite(self: *Timer) void {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        emu.mem.writeMemoryRegister(.TIMER_DIV, 0);
    }

    pub fn handleDIV(self: *Timer) !void {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        const div = emu.mem.getMemoryRegister(.TIMER_DIV);
        emu.mem.writeMemoryRegister(.TIMER_DIV, div + 1);
        emu.scheduleEvent(.TIMER_DIV, 256);
    }

    pub fn enableTIM(self: *Timer) void {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        emu.scheduleEvent(.TIMER_TIM, self.getTacSpeed());
    }

    pub fn disableTim(self: *Timer) void {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        emu.cancelEvent(.TIMER_TIM);
    }

    pub fn handleTIM(self: *Timer) !void {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        var tima = emu.mem.getMemoryRegister(.TIMER_TIMA);
        tima +%= 1;
        if (tima == 0) {
            emu.mem.setIFInterupt(.TIMER, true);
            const tma = emu.mem.getMemoryRegister(.TIMER_TMA);
            emu.mem.writeMemoryRegister(.TIMER_TIMA, tma);
        } else {
            emu.mem.writeMemoryRegister(.TIMER_TIMA, tima);
        }
        emu.scheduleEvent(.TIMER_DIV, self.getTacSpeed());
    }

    /// how many t cycles until next need for increment
    fn getTacSpeed(self: *Timer) u64 {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        const tac = emu.mem.getMemoryRegister(.TIMER_TAC);
        // check if timer is enabled
        if (tac & 0b100 == 0) {
            return 0;
        }
        return switch (tac & 0b11) {
            0b00 => 1024,
            0b01 => 16,
            0b10 => 64,
            0b11 => 256,
            else => unreachable,
        };
    }
};
