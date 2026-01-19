//! simp - Simple iterative message processor
//! A loop around amp that executes a prompt until finish criteria is met.

const std = @import("std");
const File = std.fs.File;

const Args = struct {
    max_iterations: ?u32 = null,
    prompt: ?[]const u8 = null,
    finish: ?[]const u8 = null,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout_buf: [4096]u8 = undefined;
    var stdin_buf: [4096]u8 = undefined;
    var stdin = File.stdin().reader(&stdin_buf);
    var stdout = File.stdout().writer(&stdout_buf);
    defer stdout.interface.flush() catch {};
    const out = &stdout.interface;

    const cli_args = try parseArgs(allocator);

    var prompt_owned: ?[]u8 = null;
    var finish_owned: ?[]u8 = null;
    defer if (prompt_owned) |p| allocator.free(p);
    defer if (finish_owned) |f| allocator.free(f);

    const max_iterations = cli_args.max_iterations orelse
        try promptNumber(&stdin.interface, out, "Max iterations (1-25): ", 1, 25);

    const prompt = cli_args.prompt orelse blk: {
        prompt_owned = try promptLine(allocator, &stdin.interface, out, "Prompt to execute each iteration:\n> ");
        break :blk prompt_owned.?;
    };

    const finish_criteria = cli_args.finish orelse blk: {
        finish_owned = try promptLine(allocator, &stdin.interface, out, "Finish criteria:\n> ");
        break :blk finish_owned.?;
    };

    try out.print("\nStarting loop (max {d} iterations)...\n\n", .{max_iterations});
    try out.flush();

    for (0..max_iterations) |i| {
        try out.print("── Iteration {d}/{d} ──\n", .{ i + 1, max_iterations });
        try out.flush();

        const completed = try runAmp(allocator, prompt, finish_criteria);

        if (completed) {
            try out.print("\n✓ Finish criteria satisfied. Stopping.\n", .{});
            return;
        }

        try out.print("\n", .{});
    }

    try out.print("⚠ Max iterations reached without completion.\n", .{});
}

fn promptNumber(reader: *std.Io.Reader, writer: *std.Io.Writer, msg: []const u8, min: u32, max: u32) !u32 {
    while (true) {
        try writer.print("{s}", .{msg});
        try writer.flush();

        const line = reader.takeSentinel('\n') catch |err| switch (err) {
            error.EndOfStream => return error.EndOfStream,
            else => continue,
        };
        const trimmed = std.mem.trim(u8, line, " \t\r");
        const num = std.fmt.parseInt(u32, trimmed, 10) catch continue;
        if (num >= min and num <= max) return num;
        try writer.print("  Please enter a number between {d} and {d}\n", .{ min, max });
    }
}

fn promptLine(allocator: std.mem.Allocator, reader: *std.Io.Reader, writer: *std.Io.Writer, msg: []const u8) ![]u8 {
    try writer.print("{s}", .{msg});
    try writer.flush();

    const line = reader.takeSentinel('\n') catch return error.EndOfStream;
    return allocator.dupe(u8, line);
}

fn parseArgs(allocator: std.mem.Allocator) !Args {
    var args = Args{};
    var iter = try std.process.argsWithAllocator(allocator);
    defer iter.deinit();

    _ = iter.skip(); // skip program name

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--max")) {
            if (iter.next()) |val| {
                args.max_iterations = std.fmt.parseInt(u32, val, 10) catch null;
            }
        } else if (std.mem.eql(u8, arg, "--prompt")) {
            args.prompt = iter.next();
        } else if (std.mem.eql(u8, arg, "--finish")) {
            args.finish = iter.next();
        }
    }

    return args;
}

fn runAmp(allocator: std.mem.Allocator, prompt: []const u8, finish_criteria: []const u8) !bool {
    const args: []const []const u8 = &.{ "amp", "-x", prompt };
    var child = std.process.Child.init(args, allocator);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = try child.wait();

    if (term != .Exited) return false;

    const check_prompt = try std.fmt.allocPrint(allocator,
        \\Check if this finish criteria is FULLY satisfied: {s}
        \\
        \\Output ONLY <promise>COMPLETED</promise> if the finish criteria is satisfied.
        \\Output ONLY <promise>PENDING</promise> if not satisfied.
    , .{finish_criteria});
    defer allocator.free(check_prompt);

    const check_args: []const []const u8 = &.{ "amp", "-x", check_prompt };
    var check_child = std.process.Child.init(check_args, allocator);
    check_child.stdout_behavior = .Pipe;
    check_child.stderr_behavior = .Inherit;

    try check_child.spawn();

    var stdout_content: [8192]u8 = undefined;
    var total_read: usize = 0;
    while (total_read < stdout_content.len) {
        const n = check_child.stdout.?.read(stdout_content[total_read..]) catch break;
        if (n == 0) break;
        total_read += n;
    }

    _ = try check_child.wait();

    return std.mem.indexOf(u8, stdout_content[0..total_read], "<promise>COMPLETED</promise>") != null;
}

test "basic sanity" {
    const min: u32 = 1;
    const max: u32 = 25;
    try std.testing.expect(min <= max);
}
