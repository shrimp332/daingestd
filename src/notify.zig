const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;

// sys/inotify.h
const IN_CLOSE_WRITE = 0x00000008;
const IN_MOVED_TO = 0x00000080;

const IN_ISDIR = 0x40000000;
const IN_IGNORED = 0x00008000;

pub fn start_notify(gpa: std.mem.Allocator, io: std.Io, watch_dir: []const u8, comptime callback: fn (gpa: std.mem.Allocator, io: std.Io, filename: [:0]const u8) anyerror!void) !void {
    const fd = linux.inotify_init1(0);
    if (posix.errno(fd) != .SUCCESS) {
        return error.@"inotify failed to initialise";
    }

    const watch_dir_sentinel = try gpa.dupeSentinel(u8, watch_dir, 0);
    defer gpa.free(watch_dir_sentinel);
    const wd = linux.inotify_add_watch(@intCast(fd), watch_dir_sentinel, IN_CLOSE_WRITE | IN_MOVED_TO);
    if (posix.errno(wd) != .SUCCESS) {
        return error.@"inotify failed to add watch";
    }

    while (true) {
        var buf: [4096]u8 align(@alignOf(linux.inotify_event)) = undefined;
        const num_read = try std.posix.read(@intCast(fd), &buf);
        if (num_read == 0) {
            return error.@"inotify reached EOF";
        }

        var i: usize = 0;
        while (i < num_read) {
            const event: *const linux.inotify_event = @ptrCast(@alignCast(&buf[i]));

            i += @sizeOf(linux.inotify_event) + event.len;

            if (event.mask & IN_IGNORED != 0) {
                return error.@"IN_IGNORED recieved: The watched directory was probably deleted";
            }

            // IN_MOVED_TO triggers on directories, this skips dirs
            if (event.mask & IN_ISDIR != 0) continue;

            try callback(gpa, io, event.getName().?);
        }
    }
}
