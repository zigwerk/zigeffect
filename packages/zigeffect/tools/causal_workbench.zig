const std = @import("std");
const webui = @import("webui");
const workbench_session = @import("causal_workbench_session");

var artifact_payload: [:0]const u8 = "";
var session_payload: [:0]const u8 = "";

fn loadArtifact(event: *webui.Event) void {
    event.returnValue(artifact_payload);
}

fn loadSession(event: *webui.Event) void {
    event.returnValue(session_payload);
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
