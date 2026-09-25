const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const notify = @import("notify.zig");

var input_dir: []const u8 = undefined;
var output_dir: []const u8 = undefined;

pub fn main(init: std.process.Init) !void {
    input_dir = init.environ_map.get("DAINGEST_INPUT") orelse {
        return error.@"DAINGEST_INPUT not set";
    };
    output_dir = init.environ_map.get("DAINGEST_OUTPUT") orelse {
        return error.@"DAINGEST_OUTPUT not set";
    };

    std.Io.Dir.cwd().createDirPath(init.io, input_dir) catch |err| {
        if (err != std.Io.Dir.CreateDirPathError.PathAlreadyExists) {
            return err;
        }
    };
    std.Io.Dir.cwd().createDirPath(init.io, output_dir) catch |err| {
        if (err != std.Io.Dir.CreateDirPathError.PathAlreadyExists) {
            return err;
        }
    };

    if (std.mem.order(u8, input_dir, output_dir) == .eq) {
        return error.@"DAINGEST_INPUT and DAINGEST_OUTPUT must not be the same directory";
    }

    try notify.start_notify(init.gpa, init.io, input_dir, start_ffmpeg);
}

fn start_ffmpeg(gpa: mem.Allocator, io: std.Io, filename: []const u8) anyerror!void {
    const input_filename = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ input_dir, filename });
    defer gpa.free(input_filename);

    const output_filename = try std.fmt.allocPrint(gpa, "{s}/{s}.mov", .{ output_dir, filename });
    defer gpa.free(output_filename);

    const argv = [_][]const u8{
        "ffmpeg",
        "-i",
        input_filename,
        "-map",
        "0:v:0",
        "-map",
        "0:a?",
        "-c:v",
        "dnxhd",
        "-profile:v",
        "dnxhr_sq",
        "-pix_fmt",
        "yuv422p",
        "-c:a",
        "pcm_s16le",
        "-map_metadata",
        "0",
        "-movflags",
        "+write_colr",
        "-y",
        output_filename,
    };

    var child = try std.process.spawn(io, .{
        .argv = &argv,
        .stdin = .ignore,
        .stdout = .inherit,
        .stderr = .inherit,
    });

    _ = try child.wait(io); // only 1 ffmpeg instance at once
}
