const std = @import("std");

const Emulator = @import("emulator.zig").Emulator;

// div is increased once per 64 machine cycles
const DIVM_CYCLES = 64;
const TIMA_CYCLES = 64;

pub const Timer = struct {
    div_remainder_cycles: u64 = 0,
    tima_remainder_cycles: u64 = 0,

    pub fn tick(self: *Timer) !void {
        const emu: *Emulator = @fieldParentPtr("timer", self);

        var cycles = emu.cpu_cycles + self.div_remainder_cycles;

        const div = emu.mem.getMemoryRegister(.TIMER_DIV);
        const new_div: u8 = div +% @as(u8, @intCast((cycles / DIVM_CYCLES)));
        self.div_remainder_cycles = cycles % DIVM_CYCLES;
        if (new_div != div) {
            emu.mem.writeMemoryRegister(.TIMER_DIV, new_div);
        }
        const tac_speed = getTacSpeed(self);
        std.debug.print("tac {d}\n", .{emu.mem.getMemoryRegister(.TIMER_TAC)});
        if (tac_speed == 0) {
            return;
        }

        var tima = emu.mem.getMemoryRegister(.TIMER_TIMA);
        cycles = emu.cpu_cycles + self.tima_remainder_cycles;
        const ticks: u8 = @truncate(cycles / tac_speed);
        tima, const of = @addWithOverflow(tima, ticks);
        if (of == 1) {
            emu.mem.IF.timer = true;
            const tma = emu.mem.getMemoryRegister(.TIMER_TMA);
            emu.mem.writeMemoryRegister(.TIMER_TIMA, tma);
        } else {
            emu.mem.writeMemoryRegister(.TIMER_TIMA, tima);
        }
    }
    fn getTacSpeed(self: *Timer) u64 {
        const emu: *Emulator = @fieldParentPtr("timer", self);
        const tac = emu.mem.getMemoryRegister(.TIMER_TAC);
        // check if timer is enabled
        if (tac & 0b100 == 0) {
            return 0;
        }
        return switch (tac & 0b11) {
            0b00 => 256,
            0b01 => 4,
            0b10 => 16,
            0b11 => 64,
            else => unreachable,
        };
    }
};
