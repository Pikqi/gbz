const std = @import("std");
const Cpu = struct {
    A: u8,
    B: u8,
    C: u8,
    D: u8,
    E: u8,
    H: u8,
    L: u8,
    F: u8,
    pc: u16,
    sp: u16,

    pub fn getAF(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.A)) << 8 | @as(u16, @intCast(self.F));
    }
    pub fn setAF(self: *Cpu, value: u16) void {
        self.A = (value & 0xFF00) >> 8;
        self.F = (value & 0xFF);
    }
    pub fn getBC(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.B)) << 8 | @as(u16, @intCast(self.C));
    }
    pub fn setBC(self: *Cpu, value: u16) void {
        self.B = (value & 0xFF00) >> 8;
        self.C = (value & 0xFF);
    }
    pub fn getDE(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.D)) << 8 | @as(u16, @intCast(self.E));
    }
    pub fn setDE(self: *Cpu, value: u16) void {
        self.D = (value & 0xFF00) >> 8;
        self.E = (value & 0xFF);
    }
    pub fn getHL(self: *const Cpu) u16 {
        return @as(u16, @intCast(self.H)) << 8 | @as(u16, @intCast(self.L));
    }
    pub fn setHL(self: *Cpu, value: u16) void {
        self.H = (value & 0xFF00) >> 8;
        self.L = (value & 0xFF);
    }
};
