const std = @import("std");
const fyr = @import("../../main.zig");

const rl = @import("raylib");
const rg = @import("raygui");

pub const GUIElement = @import("GUIElement.zig");
pub const Style = @import("Style.zig");

const Font = rl.Font;

fn measureText(font: Font, font_size: f32, text: []const u8) fyr.Vector2 {
    var text_size = fyr.Vec2(0, 0);

    var max_text_width: f32 = 0;
    var line_text_width: f32 = 0;

    const text_height = font_size;
    const scale_factor = font_size / fyr.tof32(font.baseSize);

    for (0..text.len) |ind| {
        if (text[ind] == '\n') {
            max_text_width = @max(max_text_width, line_text_width);
            line_text_width = 0;
            continue;
        }
        const index = text[ind] - 32;
        if (font.glyphs[index].advanceX != 0) {
            line_text_width += @floatFromInt(font.glyphs[index].advanceX);
        } else {
            line_text_width += font.recs[index].width + fyr.tof32(font.glyphs[index].offsetX);
        }
    }

    max_text_width = @max(max_text_width, line_text_width);

    text_size.x = max_text_width * scale_factor;
    text_size.y = @floatFromInt(text_height);

    return text_size;
}

pub fn getElementDims(element: *GUIElement, parent: ?fyr.Vector2) f32 {
    var dims = fyr.Vec2(0, 0);
    const font = Blk: {
        const style = element.style orelse break :Blk null;
        break :Blk fyr.assets.get.font(style.font.family);
    } orelse rl.getFontDefault();

    const font_size = Blk: {
        const style: Style = (element.style orelse break :Blk null);
        break :Blk style.font.size;
    } orelse 12;

    if (element.style) |style| Blk: {
        const width = style.width orelse break :Blk;
        const height = style.height orelse break :Blk;

        switch (width) {
            .grow => dims.x = 0,
            .fill => dims.x = if (parent) |p| p.x else 0,
            .number => dims.x = width.number,
        }

        switch (height) {
            .grow => dims.y = 0,
            .fill => dims.x = if (parent) |p| p.y else 0,
            .number => dims.y = width.number,
        }
    }

    if (dims.equals(fyr.Vec2(0, 0)) == 0) return dims;

    for (element.children.items) |child| {
        const child_dims = switch (child) {
            .text => measureText(font, font_size, child.text),
            .element => getElementDims(child.element, dims),
        };

        dims.y += child_dims.y;
        dims.x = @max(dims.x, child_dims.x);
    }

    return dims;
}
