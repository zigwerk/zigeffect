const std = @import("std");
const webui = @import("webui");
const workbench_session = @import("causal_workbench_session");

var artifact_payload: [:0]const u8 = "";
var session_payload: [:0]const u8 = "";
var log_snapshot_path: ?[:0]const u8 = null;
var artifact_file_path: ?[:0]const u8 = null;
var estate_scan_executable: ?[:0]const u8 = null;
var estate_connection_id: ?[:0]const u8 = null;
var host_io: std.Io = undefined;

fn loadArtifact(event: *webui.Event) void {
    const path = artifact_file_path orelse {
        event.returnValue(artifact_payload);
        return;
    };
    returnFileBounded(event, path, workbench_session.max_artifact_bytes);
}

fn scanEstate(event: *webui.Event) void {
    const executable = estate_scan_executable orelse {
        event.returnValue("{\"schema\":\"ziac.estate-scan-error.v1\",\"code\":\"host_not_configured\"}");
        return;
    };
    const connection_id = estate_connection_id orelse {
        event.returnValue("{\"schema\":\"ziac.estate-scan-error.v1\",\"code\":\"host_not_configured\"}");
        return;
    };
    const output_path = artifact_file_path orelse {
        event.returnValue("{\"schema\":\"ziac.estate-scan-error.v1\",\"code\":\"artifact_not_configured\"}");
        return;
    };
    const result = std.process.run(std.heap.page_allocator, host_io, .{
        .argv = &.{ executable, "estate", "scan", "--connection", connection_id, "--out", output_path, "--json" },
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    }) catch {
        event.returnValue("{\"schema\":\"ziac.estate-scan-error.v1\",\"code\":\"scanner_unavailable\"}");
        return;
    };
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);
    const succeeded = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!succeeded) {
        event.returnValue("{\"schema\":\"ziac.estate-scan-error.v1\",\"code\":\"scan_failed\"}");
        return;
    }
    const payload = std.heap.page_allocator.dupeZ(u8, std.mem.trim(u8, result.stdout, " \t\r\n")) catch {
        event.returnValue("{\"schema\":\"ziac.estate-scan-error.v1\",\"code\":\"receipt_unavailable\"}");
        return;
    };
    defer std.heap.page_allocator.free(payload);
    event.returnValue(payload);
}

fn returnFileBounded(event: *webui.Event, path: []const u8, max_bytes: usize) void {
    const bytes = std.Io.Dir.cwd().readFileAlloc(
        host_io,
        path,
        std.heap.page_allocator,
        .limited(max_bytes),
    ) catch {
        event.returnValue("");
        return;
    };
    defer std.heap.page_allocator.free(bytes);
    const payload = std.heap.page_allocator.dupeZ(u8, bytes) catch {
        event.returnValue("");
        return;
    };
    defer std.heap.page_allocator.free(payload);
    event.returnValue(payload);
}

fn loadSession(event: *webui.Event) void {
    event.returnValue(session_payload);
}

fn loadLogSnapshot(event: *webui.Event) void {
    const path = log_snapshot_path orelse {
        event.returnValue("");
        return;
    };
    const bytes = std.Io.Dir.cwd().readFileAlloc(
        host_io,
        path,
        std.heap.page_allocator,
        .limited(8 * 1024 * 1024),
    ) catch {
        event.returnValue("");
        return;
    };
    defer std.heap.page_allocator.free(bytes);
    const payload = std.heap.page_allocator.dupeZ(u8, bytes) catch {
        event.returnValue("");
        return;
    };
    defer std.heap.page_allocator.free(payload);
    event.returnValue(payload);
}

fn failUsage() noreturn {
    std.debug.print("{s}", .{workbench_session.usage()});
    std.process.exit(1);
}

fn printLastWebuiError(prefix: []const u8) void {
    const info = webui.getLastError();
    if (info.msg.len == 0) return;

    std.debug.print("{s}: webui error {d}: {s}\n", .{ prefix, info.num, info.msg });
}

fn startServer(window: *webui) !void {
    const url = try window.startServer("index.html");
    std.debug.print("zigeffect causal workbench server: {s}\n", .{url});
}

fn configureWindow(window: *webui) !void {
    _ = try window.binding("zigeffect_load_artifact", loadArtifact);
    _ = try window.binding("zigeffect_load_session", loadSession);
    _ = try window.binding("ziac_load_log_snapshot", loadLogSnapshot);
    _ = try window.binding("ziac_scan_estate", scanEstate);
    try window.setRootFolder(workbench_session.default_workbench_root);
    window.setSize(1280, 860);
}

fn launch(window: *webui, mode: workbench_session.LaunchMode) !void {
    switch (mode) {
        .server_only => try startServer(window),
        .window => window.show("index.html") catch |err| switch (err) {
            error.ShowError => {
                printLastWebuiError("causal workbench window launch failed; serving read-only UI instead");
                var server_window = webui.newWindow();
                try configureWindow(&server_window);
                try startServer(&server_window);
            },
            else => return err,
        },
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const launch_options = workbench_session.parseLaunchArgs(args) orelse failUsage();
    host_io = init.io;
    log_snapshot_path = launch_options.log_path;
    artifact_file_path = launch_options.artifact_path;
    estate_scan_executable = launch_options.estate_scan_executable;
    estate_connection_id = launch_options.estate_connection_id;

    const artifact_path = launch_options.artifact_path;
    const artifact_json = workbench_session.readArtifactBounded(
        init.io,
        allocator,
        std.Io.Dir.cwd(),
        artifact_path,
    ) catch |err| switch (err) {
        error.CausalWorkbenchArtifactTooLarge => {
            std.debug.print(
                "causal workbench artifact too large: {s} exceeds {d} bytes\n",
                .{ artifact_path, workbench_session.max_artifact_bytes },
            );
            std.process.exit(1);
        },
        else => return err,
    };
    defer allocator.free(artifact_json);

    const session_json = try workbench_session.formatSessionJson(allocator, .{
        .artifact_path = artifact_path,
        .artifact_bytes = artifact_json.len,
    });
    defer allocator.free(session_json);

    artifact_payload = try allocator.dupeZ(u8, artifact_json);
    defer allocator.free(artifact_payload);
    session_payload = try allocator.dupeZ(u8, session_json);
    defer allocator.free(session_payload);

    webui.setConfig(.multi_client, true);

    var window = webui.newWindow();
    try configureWindow(&window);
    try launch(&window, launch_options.mode);

    webui.wait();
    webui.clean();
}
