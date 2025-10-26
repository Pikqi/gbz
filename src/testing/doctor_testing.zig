const std = @import("std");
const core = @import("core");
const Emulator = core.emulator.Emulator;
const alloc = std.testing.allocator;
const log_file_prefix = ".logs/";
const success_log_prefix = "./doctor_success/";
const roms_prefix = "roms/cpu_instrs/individual/";

test "1" {
    try doctor_test("01-special.gb", 1256633, "B027786B6FD343FA19993A8B733BE7EBA5931E0E73A89A3D347BF2C0D9C9CD3E4630C55FB5FB963B9BF39D9438F2060BBA015B0D64A1EC7509971CEA3CAA0A4B");
}

test "3" {
    try doctor_test("03-op sp,hl.gb", 1066160, "A84C230C00A6830586D23D7DAF4875B385AAB65715DFD12B9F73AF9B33A54EB2A4EFE7402549078D494B3176FC384BDA5F7E914A4154EA94D0EEFD261A261A38");
}

test "4" {
    try doctor_test("04-op r,imm.gb", 1260504, "221E897E8226EE7AB1D64961AD4ECE9E3838BE8DDE35631DFA84B5F271A23AC838B3166A238274AA3681430E0AA797D3F23DDEC35B1CDE2D00EE62D7B9D05F54");
}

test "5" {
    try doctor_test("05-op rp.gb", 1761126, "2EF343F906AAC21F07AE36D02BD819188B4EDC60FB9A5F8C9950C6CC73C3672FF02E7BAAE805FD69C868DD1E594C44BA0D9303873788D823B9CD6164A6D56573");
}

test "6" {
    try doctor_test("06-ld r,r.gb", 241011, "E970CBE5F5249BF6E6939262E81FB11EA5F5A32C4ED8CA4A34636773A0E229A930E7A9D8C0E9F89D1ACF459B67946723D74EFA4F160B5CD2CAE87656D578E226");
}

test "7" {
    try doctor_test("07-jr,jp,call,ret,rst.gb", 587415, "9E25B32BA03229438948E6592476EE2C7A7357DF1A08126D3829D4FF5F8EAA1D349104466B185A8CCB6DFAE902FFA853E10F3AF3AD77E4202BDB036C52422274");
}

test "8" {
    try doctor_test("08-misc instrs.gb", 221630, "253462D38EC4546A4C38A23DC97B0BA2C44674C5ABE080A222D641F97024BC397064DB7D42FD532950E27A0E493FCCA53BD85999A0AB2E5793B4AAF90BE8B9B9");
}

test "9" {
    try doctor_test("09-op r,r.gb", 4418120, "D6A320C3F4A992519A498CFD2A4235FA3E42EEC954384F88B695E9C993F62859707A28923EC61E6DFE841420DA21076A75AE197C52B8C15D1E631BBE69EA54EC");
}

test "10" {
    try doctor_test("10-bit ops.gb", 6712461, "E663B821009CAD17CFE055DD72F8F4C83E39D6DD41553FF2B752EA9BFD03BAD7BAC42A865832CDD8C4081FC0E3A7224F7A64C42ED807261E938009C9686EF737");
}

test "11" {
    try doctor_test("11-op a,(hl).gb", 7427500, "C1779902BECFABD43BF2B2F6D2CDBD81ACA85887E89CF6508BE73395B0386F06776ABA54353F1F6E1A599C8D8D0FF4C81C3129FB7103FA61A9A203CF14420E24");
}

fn doctor_test(comptime file_name: []const u8, comptime lines_limit: usize, hash: []const u8) !void {
    try run_emu_with_doctor(file_name, lines_limit);
    const doctor_file = try std.fs.cwd().openFile(log_file_prefix ++ file_name ++ ".log", .{
        .mode = .read_only,
    });

    var read_buffer: [4096]u8 = undefined;

    var doctor_reader = doctor_file.reader(&read_buffer);
    const doctor_all = try doctor_reader.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(doctor_all);

    var sum: [64]u8 = undefined;
    std.crypto.hash.Blake3.hash(doctor_all, &sum, .{});
    const sum_hex = std.fmt.bytesToHex(&sum, .upper);

    try std.testing.expectEqualStrings(hash, &sum_hex);
    // try std.testing.expectEqualSlices(u8, success_all, doctor_all);
}

fn run_emu_with_doctor(comptime file_name: []const u8, comptime lines_limit: usize) !void {
    const file = try std.fs.cwd().openFile(roms_prefix ++ file_name, .{});
    const contents = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(contents);

    const log_file_name = log_file_prefix ++ file_name ++ ".log";
    try std.fs.cwd().makePath(log_file_prefix);
    var emu = Emulator.initBootRom();
    try emu.initDoctorFile(log_file_name);
    emu.doctor.?.line_limit = lines_limit;
    try emu.load_rom(contents);
    emu.mem.writeMemoryRegister(.PPU_LY, 0x90);
    emu.disable_ppu = true;
    emu.mem.logs_enabled = false;

    try emu.run_emu();
}
