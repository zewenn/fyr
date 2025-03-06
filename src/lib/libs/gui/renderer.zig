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

    if (style.top) |top| rect.y += switch (top) {
        .fill, .fit => 0,
        .percent => (parent.rect orelse empty).height * top.percent * 0.01,
        .px => top.px,
        .vw => winsize.x * top.vw * 0.01,
        .vh => winsize.y * top.vh * 0.01,
    };

    if (style.left) |left| rect.x += switch (left) {
        .fill, .fit => 0,
        .percent => (parent.rect orelse empty).width * left.percent * 0.01,
        .px => left.px,
        .vw => winsize.x * left.vw * 0.01,
        .vh => winsize.y * left.vh * 0.01,
    };

    element.rect = rect;

    if (style.width) |width| switch (width) {
        .fit => {
            for (element.children.items) |child| {
                if (child.style.position == .super) continue;
                child.rect = getElementRect(
                    child,
                    element,
                ) catch empty;

                const cwidth = child.rect.?.width + child.rect.?.x - element.rect.?.x;

                if (style.flow == .vertical) {
                    if (rect.width >= cwidth) continue;
                    rect.width = cwidth;
                    continue;
                }

                child.rect.?.x += rect.width;
                rect.width += child.rect.?.width;
            }
        },
        .fill => switch (style.flow) {
            .horizontal => {
                rect.width = (parent.rect orelse empty).width + (parent.rect orelse empty).x - rect.x;
                var after_self: bool = false;

                for (parent.children.items) |sibling| {
                    if (sibling.uuid == element.uuid) {
                        after_self = true;
                        continue;
                    }
                    const srect: fyr.Rectangle = getElementRect(
                        sibling,
                        parent,
                    ) catch empty;

                    sibling.rect = null;

                    if (!after_self) {
                        sibling.rect = srect;
                    }

                    rect.x += if (!after_self) srect.x - (parent.rect orelse empty).x + srect.width else 0;
                    rect.width -= srect.width + (srect.x - parent.rect.?.x);
                }

                const parent_rect = parent.rect orelse empty;
                var base_rect = fyr.Rect(parent_rect.x, parent_rect.y, 0, parent_rect.height);

                for (parent.children.items) |child| {
                    if (child.style.position == .super) continue;
                    child.rect = if (child.uuid != element.uuid) getElementRect(
                        child,
                        parent,
                    ) catch empty else rect;

                    const cwidth = child.rect.?.width + child.rect.?.x - base_rect.x;

                    if (style.flow == .vertical) break;

                    child.rect.?.x += base_rect.width - child.rect.?.width;
                    base_rect.width += cwidth;
                }
            },
            .vertical => {
                rect.width = (parent.rect orelse rect).width + (parent.rect orelse empty).x - rect.x;
            },
        },
        .percent => rect.width = (parent.rect orelse empty).width * width.percent * 0.01,
        .px => rect.width = width.px,
        .vw => rect.width = winsize.x * width.vw * 0.01,
        .vh => rect.width = winsize.y * width.vh * 0.01,
    };

    element.rect = rect;

    if (style.height) |height| switch (height) {
        .fit => {
            for (element.children.items) |child| {
                if (child.style.position == .super) continue;
                child.rect = getElementRect(
                    child,
                    element,
                ) catch empty;

                const cheight = child.rect.?.height + child.rect.?.y - element.rect.?.y;

                if (style.flow == .horizontal) {
                    if (rect.height >= cheight) continue;
                    rect.height = cheight;
                    continue;
                }

                child.rect.?.y += rect.height;
                rect.height += cheight;
            }
        },
        .fill => switch (style.flow) {
            .vertical => {
                rect.height = (parent.rect orelse empty).height + (parent.rect orelse empty).y - rect.y;
                var after_self: bool = false;

                for (parent.children.items) |sibling| {
                    if (sibling.uuid == element.uuid) {
                        after_self = true;
                        continue;
                    }
                    const srect: fyr.Rectangle = getElementRect(
                        sibling,
                        parent,
                    ) catch empty;

                    sibling.rect = null;

                    if (!after_self) {
                        sibling.rect = srect;
                    }

                    std.log.debug("id: {s} srect: {any}", .{ sibling.id orelse "NOID", sibling.rect });

                    rect.y += if (!after_self) srect.y - (parent.rect orelse empty).y + srect.height else 0;
                    rect.height -= srect.height + (srect.y - parent.rect.?.y);
                }

                const parent_rect = parent.rect orelse empty;
                var base_rect = fyr.Rect(parent_rect.x, parent_rect.y, parent_rect.width, 0);

                for (parent.children.items) |child| {
                    if (child.style.position == .super) continue;
                    child.rect = if (child.uuid != element.uuid) getElementRect(
                        child,
                        parent,
                    ) catch empty else rect;

                    const cheight = child.rect.?.height + child.rect.?.y - base_rect.y;

                    if (style.flow == .horizontal) break;

                    child.rect.?.y += base_rect.height - child.rect.?.height;
                    base_rect.height += cheight;
                }
            },
            .horizontal => {
                rect.height = (parent.rect orelse rect).height + (parent.rect orelse empty).y - rect.y;
            },
        },
        .percent => rect.height = (parent.rect orelse rect).height * height.percent * 0.01,
        .px => rect.height = height.px,
        .vw => rect.height = winsize.x * height.vw * 0.01,
        .vh => rect.height = winsize.y * height.vh * 0.01,
    };

    element.rect = rect;

    const fontptr = (element.font orelse &(try rl.getFontDefault())).*;

    const text_size = measureText(
        fontptr,
        style.font.size,
        element.text orelse "",
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
                break :Blk fyr.rect();
            };
            break :Blk element.rect.?;
        };
        const style = element.style;

        if (style.background.color) |color|
            rl.drawRectanglePro(rect, fyr.vec2(), 0, color);

        if (style.font.family) |ff| {
            const loaded = fyr.assets.font.get(ff, .{});
            element.font = loaded;
        }

        if (element.text) |text| rl.drawTextPro(
            (element.font orelse &(try rl.getFontDefault())).*,
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
