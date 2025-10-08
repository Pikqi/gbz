const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;

var buffer: [1024]u8 = undefined;
pub const DoctorLogger = struct {
    emu: *Emulator,
    writer: *std.Io.Writer,
    file_writer: ?std.fs.File.Writer = null,
    pub fn initWithFile(emu: *Emulator, file_path: []const u8) !DoctorLogger {
        const file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
        var writer = file.writerStreaming(&buffer);
        const doc = DoctorLogger{ .emu = emu, .file_writer = writer, .writer = &writer.interface };
        return doc;
    }

    pub fn initStdOut(emu: *Emulator) DoctorLogger {
        const std_out = std.fs.File.stdout();
        var writer = std_out.writerStreaming(&buffer);
        const doc = DoctorLogger{ .emu = emu, .writer = &writer.interface };
        return doc;
    }

    pub fn log(self: DoctorLogger) !void {
        const pc = self.emu.cpu.pc;
        if (pc >= self.emu.mem.len - 4) {
            return;
        }
        const pcmem1 = self.emu.mem[pc];
        const pcmem2 = self.emu.mem[pc + 1];
        const pcmem3 = self.emu.mem[pc + 2];
        const pcmem4 = self.emu.mem[pc + 3];
        const c = &self.emu.cpu;

        @breakpoint();
        try self.writer.print("A:{X:02} F:{X:02} B:{X:02} C:{X:02} D:{X:02} E:{X:02} H:{X:02} L:{X:02} SP:{X:04} PC:{X:04} PCMEM:{X:02},{X:02},{X:02},{X:02}\n", .{
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
            pcmem1,
            pcmem2,
            pcmem3,
            pcmem4,
        });
        try self.writer.flush();
    }
};

// todo write bytes to a buffer and test against that buffer
test "doctorLogger test" {
    var stdout = std.fs.File.stderr().writer(&buffer);
    var emu = Emulator.init();
    std.debug.print("doctor start \n", .{});

    const file = try std.fs.cwd().createFile("doctor.log", .{ .truncate = true });
    var file_writer = file.writer(&buffer);

    emu.cpu.getU8Register(.A).* = 0x01;
    emu.cpu.getU8Register(.F).* = 0xB0;
    emu.cpu.getU8Register(.B).* = 0x00;
    emu.cpu.getU8Register(.C).* = 0x13;
    emu.cpu.getU8Register(.D).* = 0x00;
    emu.cpu.getU8Register(.E).* = 0xD8;
    emu.cpu.getU8Register(.L).* = 0x4D;
    emu.cpu.getU16Register(.SP).* = 0xFFFE;
    emu.cpu.getU16Register(.PC).* = 0x0100;

    var doctor_stdout = DoctorLogger{ .emu = &emu, .writer = &stdout.interface };
    try doctor_stdout.log();
    try doctor_stdout.log();
    try doctor_stdout.log();

    var doctor_file = DoctorLogger{ .emu = &emu, .writer = &file_writer.interface };
    try doctor_file.log();
    try doctor_file.log();
    try doctor_file.log();

    //
    // try doctor.doctorLoggerToWriter();
    // try doctor.doctorLoggerToWriter();
    // try doctor.doctorLogger();
    // try doctor.doctorLogger();
    // try doctor.doctorLogger();

    std.debug.print("doctor end \n", .{});
}
