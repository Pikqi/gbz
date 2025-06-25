const std = @import("std");
const Allocator = std.mem.Allocator;
const CHeaderCSStart = 0x134;
const CHeaderCSEnd = 0x14D;

const CartridgeHeader = struct {
    name: []u8,
    rom_banks: usize,
    manufacturer_code: [4]u8 = .{ 0, 0, 0, 0 },
    cartridge_type: CatridgeType,
    ram_banks: u8,

    pub fn calc_checksum(header: []u8) u8 {
        var checksum: u8 = 0;
        for (header) |byte| {
            checksum, _ = @subWithOverflow(checksum, byte);
            checksum, _ = @subWithOverflow(checksum, 1);
        }
        return checksum;
    }

    pub fn print(self: CartridgeHeader) void {
        std.debug.print("Catridge Header\n", .{});
        std.debug.print("Name: {s}\n", .{self.name});
        std.debug.print("Number of rom banks: {d}\n", .{self.rom_banks});
        std.debug.print("type: {}\n", .{self.cartridge_type});
        std.debug.print("Ram size: {d} banks of 8 KiB each\n", .{self.rom_banks});
    }
};

const CatridgeType = enum(u8) {
    ROM_ONLY = 0x0,
    MBC1 = 0x1,
    MBC1_RAM = 0x2,
    MBC1_RAM_BATTERY = 0x03,
    MBC2 = 0x5,
    MBC2_BATTERY = 0x06,
    ROM_RAM = 0x08,
    ROM_RAM_BATTERY = 0x09,
    MMM01 = 0x0B,
    MMM01_RAM = 0x0C,
    MMM01_RAM_BATTERY = 0x0D,
    MBC3_TIMER_BATTERY = 0x0F,
    MBC3_TIMER_RAM_BATTERY = 0x10,
    MBC3 = 0x11,
    MBC3_RAM = 0x12,
    MBC3_RAM_BATTERY = 0x13,
    MBC5 = 0x19,
    MBC5_RAM = 0x1A,
    MBC5_RAM_BATTERY = 0x1B,
    MBC5_RUMBLE = 0x1C,
    MBC5_RUMBLE_RAM = 0x1D,
    MBC5_RUMBLE_RAM_BATTERY = 0x1E,
    MBC6 = 0x20,
    MBC7_SENSOR_RUMBLE_RAM_BATTERY = 0x22,
    POCKET_CAMERA = 0xFC,
    BANDAI_TAMA5 = 0xFD,
    HuC3 = 0xFE,
    HuC1_RAM_BATTERY = 0xFF,
};

pub const Cartridge = struct {
    contents: []u8,
    alloc: Allocator,
    ch: CartridgeHeader,

    pub fn loadFromFile(fileName: []const u8, alloc: Allocator) !Cartridge {
        const file = try std.fs.cwd().openFile(fileName, .{});
        const contents = try file.readToEndAlloc(alloc, 8096 * 1024);

        var c = Cartridge{ .contents = contents, .alloc = alloc, .ch = undefined };
        try c.parseHeader();
        c.ch.print();
        return c;
    }
    fn parseHeader(self: *Cartridge) !void {
        const name = self.contents[0x134..0x143];
        const romSizeByte = self.contents[0x148];
        const romBanks = romSizeByteToNumBanks(romSizeByte);
        const typeByte = self.contents[0x147];
        const ram_banks_byte = self.contents[0x149];
        const ram_banks: u8 = switch (ram_banks_byte) {
            0, 1 => 0,
            2 => 1,
            3 => 4,
            4 => 16,
            5 => 8,
            else => unreachable,
        };
        const cs_rom = self.contents[0x14D];

        self.ch = CartridgeHeader{
            .name = name,
            .rom_banks = romBanks,
            .cartridge_type = @enumFromInt(typeByte),
            .ram_banks = ram_banks,
        };
        const cs = CartridgeHeader.calc_checksum(self.contents[CHeaderCSStart..CHeaderCSEnd]);
        if (cs != cs_rom) {
            std.debug.print("bad cs\n cs_rom = {d}\ncs = {d}\n", .{ cs_rom, cs });
            return error.BadChecksum;
        }
    }

    pub fn printContentsBytes(self: *const Cartridge) void {
        for (self.contents[0..512], 0..) |value, i| {
            if (i % 16 == 0) {
                std.debug.print("\n", .{});
            }

            std.debug.print("{X:02} ", .{value});
        }
    }

    pub fn destroy(self: *Cartridge) void {
        self.alloc.free(self.contents);
    }

    fn romSizeByteToNumBanks(romsize: u8) usize {
        var result: usize = 2;
        result = result << @intCast(romsize);
        return result;
    }
};
