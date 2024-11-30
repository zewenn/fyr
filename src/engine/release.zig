// This file contains all platform specific runtime code

const std = @import("std");
const builtin = @import("builtin");

/// Handles all platform specific API calls. For example this detaches the windows console.
pub fn callPlatformAPIs() void {
    switch (builtin.os.tag) {
        .windows => {
            const wapi = @cImport({
                @cInclude("windows.h");
            });

            _ = wapi.FreeConsole();
        },
        .macos => {},
        else => {},
    }
}
