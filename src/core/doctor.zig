const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;

var buffer: [128 * 1024]u8 = undefined;

pub const DoctorLogger = struct {
    emu: *Emulator,
    file_writer: std.Io.File.Writer,
    line_limit: ?usize = null,
    lines_printed: usize = 0,
    limit_reached: bool = false,
    flush_interval: usize = 1000,

    pub fn flush(self: *DoctorLogger) void {
        self.file_writer.interface.flush() catch {};
    }
    pub fn initWithFile(emu: *Emulator, file_path: []const u8, io: std.Io) !DoctorLogger {
        const file = try std.Io.Dir.cwd().createFile(io, file_path, .{});
        const doc = DoctorLogger{ .emu = emu, .file_writer = file.writer(io, &buffer) };
        return doc;
    }

    pub fn initStdOut(emu: *Emulator, io: std.Io) DoctorLogger {
        const std_out = std.Io.File.stdout();
        const doc = DoctorLogger{ .emu = emu, .file_writer = std_out.writer(io, &buffer) };
        return doc;
    }

    pub fn log(self: *DoctorLogger) !void {
        if (self.limit_reached) {
            return;
        }
        const pc = self.emu.cpu.pc;
        if (pc >= self.emu.mem.mem.len - 4) {
            return;
        }
        // const pcmem = try self.emu.mem.getSlice(pc, pc + 4);
        var pcmem: [4]u8 = undefined;
        for (&pcmem, 0..) |*m, i| {
            m.* = try self.emu.mem.read(pc + i);
        }
        const c = &self.emu.cpu;

        try self.file_writer.interface.print("A:{X:02} F:{X:02} B:{X:02} C:{X:02} D:{X:02} E:{X:02} H:{X:02} L:{X:02} SP:{X:04} PC:{X:04} PCMEM:{X:02},{X:02},{X:02},{X:02}\n", .{
            c.getU8Register(.A).*,
            c.getU8Register(.F).*,
            c.getU8Register(.B).*,
            c.getU8Register(.C).*,
            c.getU8Register(.D).*,
            c.getU8Register(.E).*,
            c.getU8Register(.H).*,
            c.getU8Register(.L).*,
            c.getU16Register(.SP).*,
            pc,
            pcmem[0],
            pcmem[1],
            pcmem[2],
            pcmem[3],
        });
        self.lines_printed += 1;
        if (self.lines_printed % self.flush_interval == 0) {
            self.file_writer.interface.flush() catch {};
        }
        if (self.line_limit) |limit| {
            if (self.lines_printed >= limit) {
                self.limit_reached = true;
            }
        }
    }
};

// todo write bytes to a buffer and test against that buffer
test "doctorLogger test" {
    const io = std.testing.io;
    var emu = Emulator.initZero();
    emu.cpu.getU8Register(.A).* = 0x01;
    emu.cpu.getU8Register(.F).* = 0xB0;
    emu.cpu.getU8Register(.B).* = 0x00;
    emu.cpu.getU8Register(.C).* = 0x13;
    emu.cpu.getU8Register(.D).* = 0x00;
    emu.cpu.getU8Register(.E).* = 0xD8;
    emu.cpu.getU8Register(.L).* = 0x4D;
    emu.cpu.getU16Register(.SP).* = 0xFFFE;
    emu.cpu.getU16Register(.PC).* = 0xC000;

    var doctor_file = try DoctorLogger.initWithFile(&emu, "doctor-test.log", io);
    try doctor_file.log();
    try doctor_file.log();
    try doctor_file.log();
}
