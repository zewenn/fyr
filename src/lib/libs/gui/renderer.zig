const std = @import("std");
const fyr = @import("../../main.zig");

const rl = @import("raylib");
const rg = @import("raygui");

const ui = fyr.gui;

pub const Element = @import("Element.zig");
pub const Style = @import("Style.zig");

const Font = rl.Font;

fn measureText(font: Font, font_size: f32, text: []const u8) fyr.Vector2 {
    var text_size = fyr.vec2();

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
            line_text_width += fyr.tof32(font.glyphs[index].advanceX);
        } else {
            line_text_width += font.recs[index].width + fyr.tof32(font.glyphs[index].offsetX);
        }
    }

    max_text_width = @max(max_text_width, line_text_width);

    text_size.x = max_text_width * scale_factor;
    text_size.y = text_height;

    return text_size;
}

fn getElementRect(element: *Element, parent: *Element) !fyr.Rectangle {
    const empty = fyr.Rect(0, 0, 0, 0);

    var rect = fyr.Rect(
        (parent.rect orelse empty).x,
        (parent.rect orelse empty).y,
        0,
        0,
    );

    const winsize = fyr.window.size.get();

    const style = element.style;

    if (style.top) |top| {
        rect.y += switch (top) {
            .fill, .fit => 0,
            .percent => (parent.rect orelse empty).height * top.percent * 0.01,
            .px => top.px,
            .vw => winsize.x * top.vw * 0.01,
            .vh => winsize.y * top.vh * 0.01,
        };
    }

    if (style.width) |width| switch (width) {
        .fit => {
            for (element.children.items) |child| {
                child.rect = getElementRect(
                    child,
                    element,
                ) catch empty;

                const cwidth = (child.rect orelse continue).width;

                if (style.flow == .vertical) {
                    if (rect.width >= cwidth) continue;
                    rect.width = cwidth;
                    continue;
                }

                child.rect.?.x = rect.width;
                rect.width += cwidth;
            }
        },
        .fill => switch (style.flow) {
            .horizontal => {
                rect.width = (parent.rect orelse empty).width;

                for (parent.children.items) |child| {
                    if (child.uuid == element.uuid) continue;

                    child.rect = getElementRect(
                        child,
                        parent,
                    ) catch empty;
                    const cwidth = (child.rect orelse continue).width;

                    rect.width -= cwidth;
                }
            },
            .vertical => {
                rect.width = (parent.rect orelse rect).width;
            },
        },
        .percent => rect.width = (parent.rect orelse empty).width * width.percent * 0.01,
        .px => rect.width = width.px,
        .vw => rect.width = winsize.x * width.vw * 0.01,
        .vh => rect.width = winsize.y * width.vh * 0.01,
    };

    if (style.height) |height| switch (height) {
        .fit => {
            for (element.children.items) |child| {
                child.rect = getElementRect(
                    child,
                    element,
                ) catch empty;

                const cheight = (child.rect orelse continue).height;

                if (style.flow == .horizontal) {
                    if (rect.height >= cheight) continue;
                    rect.height = cheight;
                    continue;
                }

                rect.height += cheight;
            }
        },
        .fill => switch (style.flow) {
            .vertical => {
                rect.width = (parent.rect orelse empty).width;

                for (parent.children.items) |sibling| {
                    if (sibling.uuid == element.uuid) continue;

                    sibling.rect = getElementRect(
                        sibling,
                        parent,
                    ) catch empty;
                    const sibling_height = (sibling.rect orelse continue).height;

                    rect.height -= sibling_height;
                }
            },
            .horizontal => {
                rect.height = (parent.rect orelse rect).height;
            },
        },
        .percent => rect.height = (parent.rect orelse rect).height * height.percent * 0.01,
        .px => rect.height = height.px,
        .vw => rect.height = winsize.x * height.vw * 0.01,
        .vh => rect.height = winsize.y * height.vh * 0.01,
    };

    const fontptr = style.font.family orelse rl.getFontDefault();

    const text_size = measureText(
        fontptr,
        style.font.size,
        std.mem.span(element.text orelse ""),
    );

    rect.width = @max(rect.width, text_size.x);
    rect.height = @max(rect.height, text_size.y);

    return rect;
}

pub fn render(arr: []?Element) !void {
    const winsize = fyr.window.size.get();

    var root = Element.create();
    root.rect = fyr.Rect(
        0,
        0,
        winsize.x,
        winsize.y,
    );

    for (arr) |*el| {
        const element = &(el.* orelse continue);

        const rect = element.rect orelse Blk: {
            element.rect = getElementRect(
                element,
                element.parent orelse &root,
            ) catch {
                std.log.warn("Couldn't get rectangle of ID: {s}", .{element.id orelse "NOID"});
                continue;
            };
            break :Blk element.rect.?;
        };
        const style = element.style;

        if (style.background.color) |color|
            rl.drawRectanglePro(rect, fyr.vec2(), 0, color);

        if (element.text) |text| rl.drawTextPro(
            style.font.family orelse rl.getFontDefault(),
            text,
            fyr.Vec2(rect.x, rect.y),
            fyr.vec2(),
            0,
            style.font.size,
            0,
            style.font.color,
        );
    }
}
