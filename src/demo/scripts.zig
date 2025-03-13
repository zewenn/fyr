const std = @import("std");
const fyr = @import("fyr");

const clay = fyr.clay;
const gui = fyr.gui;
const fontID = gui.fontID;

pub const DemoUI = struct {
    pub const FYR_SCRIPT = {};
    const Self = @This();

    pub fn UI(_: *Self) !void {
        fyr.clay.UI()(.{
            .id = .ID("test"),

            .layout = .{
                .sizing = .{
                    .w = .fixed(300),
                    .h = .percent(100),
                },
                .padding = .all(10),
                .child_gap = 10,
                .direction = .top_to_bottom,
            },
            .background_color = .{ 250, 250, 255, 255 },
        })({
            clay.UI()(.{
                .id = .ID("test"),
                .layout = .{
                    .sizing = .{
                        .w = .grow,
                        .h = .fixed(300),
                    },
                },
                .background_color = gui.color(20, 120, 220, 255),
            })({
                fyr.clay.text("Clay - UI Library", .{
                    .font_size = 12,
                    .letter_spacing = 1,
                    .color = .{ 0, 0, 0, 255 },
                    .font_id = gui.fontID("press_play.ttf"),
                });
            });
            clay.UI()(.{
                .id = .ID("test"),
                .layout = .{
                    .sizing = .{
                        .w = .grow,
                        .h = .fixed(100),
                    },
                },
            })({
                fyr.clay.text("Clay - UI Library", .{
                    .font_size = 12,
                    .letter_spacing = 1,
                    .color = .{ 0, 0, 0, 255 },
                    .font_id = gui.fontID("press_play.ttf"),
                });
            });
        });
    }
};
