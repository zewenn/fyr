const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const entities = @import("../engine.m.zig").entities;
const zlib = @import("../z/z.m.zig");
const input = @import("../input.m.zig");

const loadusize = @import("../engine.m.zig").loadusize;

pub const GUIElement = @import("GUIElement.zig");
pub const StyleSheet = @import("StyleSheet.zig");
pub const ButtonInterface = @import("ButtonInterface.zig");
pub const u = @import("Unit.zig").u;
pub const toUnit = @import("Unit.zig").toUnit;
pub const Unit = @import("Unit.zig");

pub const manager = zlib.HeapManager(GUIElement, (struct {
    pub fn callback(_: Allocator, item: *GUIElement) !void {
        if (item.is_hovered) {
            item.is_hovered = false;
            hovered_button = null;
        }

        if (!item.heap_id) return;
        alloc.free(item.options.id);
    }
}).callback);

pub const BM3D = @import("button_matrix_3d.zig");

pub const BUTTON_MATRIX_WIDTH = BM3D.BUTTON_MATRIX_WIDTH;
pub const BUTTON_MATRIX_HEIGHT = BM3D.BUTTON_MATRIX_HEIGHT;
pub const BUTTON_MATRIX_DEPTH = BM3D.BUTTON_MATRIX_DEPTH;

pub var hovered_button: ?*GUIElement = null;
pub var keyboard_cursor_position = rl.Vector2.init(0, 0);

var alloc: Allocator = undefined;

pub fn init(allocator: Allocator) void {
    alloc = allocator;
    manager.init(alloc);

    BM3D.clear();
}

pub fn update() void {
    if (!input.ui_mode) return;
    hovered_button = null;

    switch (input.input_mode) {
        .KeyboardAndMouse => {
            for (BM3D.getCurrentLayer(), 0..) |row, y| {
                for (row, 0..) |btn, x| {
                    if (btn == null) continue;

                    const button = btn.?.element_ptr.?;
                    if (button.transform == null) _ = button.calculateTransform();

                    const button_rect = button.transform.?.getRect();
                    const mouse_rect = rl.Rectangle.init(
                        input.mouse_position.x - 5,
                        input.mouse_position.y - 5,
                        5,
                        5,
                    );

                    if (!mouse_rect.checkCollision(button_rect)) {
                        button.is_hovered = false;
                        // hovered_button = null;
                        continue;
                    }

                    keyboard_cursor_position.x = @floatFromInt(x);
                    keyboard_cursor_position.y = @floatFromInt(y);

                    button.is_hovered = true;
                    hovered_button = button;

                    if (rl.isMouseButtonPressed(.mouse_button_left)) {
                        btn.?.callback_fn() catch {};
                    }
                }
            }
        },

        .Keyboard => {
            for (BM3D.getCurrentLayer()) |row| {
                for (row) |btn| {
                    if (btn) |button| button.element_ptr.?.is_hovered = false;
                }
            }

            var towards: ?zlib.arrays.Direction = null;

            if (rl.isKeyPressed(.key_left) and keyboard_cursor_position.x > 0)
                towards = .left;

            if (rl.isKeyPressed(.key_right) and keyboard_cursor_position.x < 15)
                towards = .right;

            if (rl.isKeyPressed(.key_up) and keyboard_cursor_position.y > 0)
                towards = .up;

            if (rl.isKeyPressed(.key_down) and keyboard_cursor_position.y < 8)
                towards = .down;

            if (towards) |direction| {
                const next_tuple = zlib.arrays.searchMatrixForNext(
                    ButtonInterface,
                    BUTTON_MATRIX_WIDTH,
                    BUTTON_MATRIX_HEIGHT,
                    BM3D.getCurrentLayer(),
                    direction,
                    @intFromFloat(keyboard_cursor_position.x),
                    @intFromFloat(keyboard_cursor_position.y),
                );

                keyboard_cursor_position.x = @floatFromInt(next_tuple[0]);
                keyboard_cursor_position.y = @floatFromInt(next_tuple[1]);
            }
            const button = BM3D.get(
                BM3D.current_layer,
                keyboard_cursor_position.y,
                keyboard_cursor_position.x,
            );

            if (button) |btn| {
                btn.element_ptr.?.is_hovered = true;
                hovered_button = btn.element_ptr.?;

                if (rl.isKeyPressed(.key_space) or rl.isKeyPressed(.key_enter)) {
                    btn.callback_fn() catch {};
                }
            }
        },
    }
}

pub fn remove(element: *GUIElement) !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        if (!zlib.eql(element, item)) continue;

        manager.removeFreeId(item);
    }
}

pub fn deinit() void {
    const items = manager.items() catch return;
    defer manager.alloc.free(items);

    for (items) |item| {
        if (item.children) |children| {
            children.deinit();
        }

        manager.removeFreeId(item);
    }
    manager.deinit();
}

pub fn select(selector: []const u8) ?*GUIElement {
    const items = manager.items() catch return Err: {
        std.log.err("FAILED TO GET MANAGER ITEMS IN GUI/SELECT!", .{});
        break :Err null;
    };
    defer manager.alloc.free(items);

    for (items) |value| {
        switch (selector[0]) {
            '.' => {
                // Class based search
                if (std.mem.containsAtLeast(
                    u8,
                    value.options.class,
                    1,
                    selector[1..],
                )) {
                    return value;
                }
            },
            '#' => {
                // ID based search
                if (std.mem.eql(u8, value.options.id, selector[1..])) {
                    return value;
                }
            },
            else => return null,
        }
    }
    return null;
}

pub fn assertSelect(selector: []const u8) *GUIElement {
    return if (select(selector)) |el| el else zlib.panicWithArgs(
        "FATAL Element couldn't be found: {s}",
        .{selector},
    );
}

pub fn clear() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        if (item.children) |children| {
            children.deinit();
        }
        manager.removeFreeId(item);
    }

    std.log.debug("GUI: {d}", .{manager.len()});
    hovered_button = null;

    BM3D.clear();
}

pub fn Element(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !*GUIElement {
    var childrn = std.ArrayList(*GUIElement).init(alloc);

    for (children) |child| {
        try childrn.append(child);
    }

    var Parent = GUIElement{ .options = options };
    Parent.children = childrn;
    Parent.contents = content;

    try manager.append(Parent);

    const getFMT = try std.fmt.allocPrint(alloc, "#{s}", .{Parent.options.id});
    defer alloc.free(getFMT);

    const el_ptr = select(getFMT).?;

    for (childrn.items) |child| {
        if (child.options.style.z_index == 0)
            child.options.style.z_index = Parent.options.style.z_index;
        child.parent = el_ptr;
    }

    return el_ptr;
}

pub fn Container(options: GUIElement.Options, children: []*GUIElement) !*GUIElement {
    return try Element(options, children, "");
}

pub fn Empty(options: GUIElement.Options) !*GUIElement {
    return try Element(options, &[_]*GUIElement{}, "");
}

pub fn Text(options: GUIElement.Options, text: [*:0]const u8) !*GUIElement {
    var el = try Element(options, &[_]*GUIElement{}, text);

    const len = std.mem.indexOfSentinel(u8, 0, text);

    if (options.style.width.value == 64 and options.style.height.value == 64) {
        el.options.style.width = .{ .value = (@as(f32, @floatFromInt(len)) * el.options.style.font.size), .unit = .px };
        el.options.style.height = .{ .value = el.options.style.font.size, .unit = .px };
    }

    el.options.style.text_align = .{
        .x = .center,
        .y = .center,
    };

    return el;
}

pub fn Button(options: GUIElement.Options, text: [*:0]const u8, grid_pos: rl.Vector2, callback: *const fn () anyerror!void) !*GUIElement {
    BM3D.set(
        BM3D.current_layer,
        grid_pos.y,
        grid_pos.x,
        ButtonInterface{
            .button_id = options.id,
            .callback_fn = callback,
        },
    );

    const len = std.mem.indexOfSentinel(u8, 0, text);

    var O = options;
    if (zlib.eql(O.hover, StyleSheet{})) {
        O.hover = StyleSheet{
            .font = .{
                .size = O.style.font.size + 1,
            },
        };
    }

    if (O.style.width.value == 64 and O.style.height.value == 64) {
        O.hover.width = .{
            .value = (@as(f32, @floatFromInt(len)) * (O.hover.font.size)),
            .unit = .px,
        };
        O.hover.height = .{
            .value = O.hover.font.size,
            .unit = .px,
        };
    }

    var element = try Text(O, text);
    element.is_button = true;
    element.button_interface_ptr = BM3D.getPtr(BM3D.current_layer, grid_pos.y, grid_pos.x);

    element.button_interface_ptr.?.element_ptr = element;

    return element;
}

pub fn Body(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !void {
    _ = try Element(options, children, content);
}
