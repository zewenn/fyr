const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const assets = @import("../assets.m.zig");
const entities = @import("../engine.m.zig").entities;
const GUI = @import("../gui/gui.m.zig");
const input = @import("../input.m.zig");

const rl = @import("raylib");
const z = @import("../z/z.m.zig");

// ==================================================

pub const window = @import("./window.zig");
pub const Colour = @import("Colour.zig");
pub const camera = @import("./camera.zig");

// ==================================================

fn sortEntities(_: void, lsh: *entities.Entity, rsh: *entities.Entity) bool {
    if (@intFromEnum(lsh.display.layer) != @intFromEnum(rsh.display.layer)) {
        return @intFromEnum(lsh.display.layer) < @intFromEnum(rsh.display.layer);
    }

    const lsh_transform = lsh.transform;
    const rsh_transform = rsh.transform;

    return (
    //
        lsh_transform.position.y * camera.zoom +
        if (lsh_transform.anchor) |anchor| anchor.y else lsh_transform.scale.y * camera.zoom / 2) < (
    //
        rsh_transform.position.y * camera.zoom +
        if (rsh_transform.anchor) |anchor| anchor.y else rsh_transform.scale.y * camera.zoom / 2);
}

fn sortGUIElements(_: void, lsh: *GUI.GUIElement, rsh: *GUI.GUIElement) bool {
    const lsh_z_index = lsh.options.style.z_index;
    const rsh_z_index = rsh.options.style.z_index;

    return lsh_z_index < rsh_z_index;
}

pub fn update() !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(Colour.make(Colour.RENDER_FILL_BACKGROUND));

    // ==============================================

    //                    Entities

    // ==============================================

    const entity_slice = try entities.all();
    defer entities.alloc.free(entity_slice);
    std.sort.insertion(*entities.Entity, entity_slice, {}, sortEntities);

    for (entity_slice) |entity| {
        const transform = entity.transform;

        // Early continue if entity is not on screen
        {
            const start_transform = camera.worldPositionToScreenPosition(transform.position
                .subtract(transform.scale
                .multiply(rl.Vector2.init(0.5, 0.5))));
            const end_transform = camera.worldPositionToScreenPosition(transform.position
                .add(transform.scale
                .multiply(rl.Vector2.init(0.5, 0.5))));

            if ((end_transform.x < 0 or
                end_transform.y < 0) or
                (start_transform.x > window.size.x or
                start_transform.y > window.size.y))
            {
                continue;
            }
        }

        if (transform.scale.x * camera.zoom <= 0 or transform.scale.y * camera.zoom <= 0) continue;

        const display = entity.display;

        var img: rl.Image = undefined;
        defer rl.unloadImage(img);

        var texture: rl.Texture = undefined;

        const use_previous: bool = Decide: {
            if (entity.cached_display == null) break :Decide false;

            const cached = entity.cached_display.?;

            if (cached.transform.scale.equals(transform.scale) == 0) break :Decide false;
            if (cached.transform.rotation.equals(transform.rotation) == 0) break :Decide false;
            if (!std.mem.eql(u8, cached.display.sprite, display.sprite)) break :Decide false;
            if (cached.display.scaling != display.scaling) break :Decide false;
            if ((cached.display.background_tile_size == null) != (display.background_tile_size == null)) break :Decide false;
            if (display.background_tile_size) |dbts| {
                if (dbts.equals(cached.display.background_tile_size.?) == 0) break :Decide false;
            }

            if (cached.img == null) break :Decide false;
            if (cached.texture == null) break :Decide false;

            break :Decide true;
        };

        if ((use_previous and entity.cached_display != null) and camera.zoom == camera.last_zoom) {
            img = rl.imageCopy(entity.cached_display.?.img.?);
            texture = entity.cached_display.?.texture.?;
        } else {
            if (assets.get.image(display.sprite)) |_img| {
                img = _img;
            } else {
                std.log.info("DISPLAY: IMAGE: MISSING IMAGE \"{s}\"", .{display.sprite});
                continue;
            }

            const w = if (display.background_tile_size) |dbts| dbts.x else transform.scale.x;
            const h = if (display.background_tile_size) |dbts| dbts.y else transform.scale.y;

            switch (display.scaling) {
                .normal => rl.imageResize(
                    &img,
                    @intFromFloat(w * camera.zoom),
                    @intFromFloat(h * camera.zoom),
                ),
                .pixelate => rl.imageResizeNN(
                    &img,
                    @intFromFloat(w * camera.zoom),
                    @intFromFloat(h * camera.zoom),
                ),
            }
            if (entity.cached_display) |cached| {
                if (cached.img) |chached_image| {
                    rl.unloadImage(chached_image);
                }
                if (cached.texture) |cached_texture| {
                    rl.unloadTexture(cached_texture);
                }
            }

            entity.cached_display = .{
                .transform = transform,
                .display = display,
                .img = rl.imageCopy(img),
                .texture = rl.loadTextureFromImage(img),
            };

            texture = entity.cached_display.?.texture.?;
        }

        drawTetxure(
            texture,
            transform,
            display.tint,
            display.ignore_world_pos,
            entity.cached_collider,
        );
    }
    camera.last_zoom = camera.zoom;

    // ==============================================

    //                      GUI

    // ==============================================

    var GUIElements = std.ArrayList(*GUI.GUIElement).init(std.heap.page_allocator);
    defer GUIElements.deinit();

    const GUIItems = try GUI.manager.items();
    defer GUI.manager.alloc.free(GUIItems);

    for (GUIItems) |item| {
        try GUIElements.insert(0, item);
    }

    const sorted_elements = try GUIElements.toOwnedSlice();
    defer GUIElements.allocator.free(sorted_elements);

    std.sort.insertion(*GUI.GUIElement, sorted_elements, {}, sortGUIElements);

    for (sorted_elements) |element| {
        _ = element.calculateTransform();

        const style = GetStyle: {
            if (element.is_hovered) {
                break :GetStyle element.options.style.merge(element.options.hover);
            }
            break :GetStyle element.options.style;
        };

        if (!style.display) continue;

        var transform: entities.Transform = element.transform orelse continue;
        var origin = transform.anchor orelse continue;

        BackgroundColorRendering: {
            const background_color = style.background.color orelse break :BackgroundColorRendering;

            rl.drawRectanglePro(
                rl.Rectangle.init(
                    transform.position.x,
                    transform.position.y,
                    transform.scale.x,
                    transform.scale.y,
                ),
                origin,
                transform.rotation.z,
                Colour.make(background_color),
            );
        }

        BacgroundImageRendering: {
            if (style.background.image == null) break :BacgroundImageRendering;

            if (transform.scale.x <= 0 or transform.scale.y <= 0) break :BacgroundImageRendering;

            const display: entities.Display = .{
                .sprite = style.background.image.?,
                .scaling = .pixelate,
            };

            var img: rl.Image = undefined;
            defer rl.unloadImage(img);

            var texture: rl.Texture = undefined;

            const use_previous: bool = Decide: {
                if (element.cached_display == null) {
                    break :Decide false;
                }

                const cached = element.cached_display.?;

                if (cached.transform.scale.equals(transform.scale) == 0) {
                    break :Decide false;
                }
                if (cached.transform.rotation.equals(transform.rotation) == 0) {
                    break :Decide false;
                }
                if (!std.mem.eql(u8, cached.display.sprite, display.sprite)) {
                    break :Decide false;
                }
                if (cached.display.scaling != display.scaling) {
                    break :Decide false;
                }

                if (cached.img == null) break :Decide false;
                if (cached.texture == null) break :Decide false;

                break :Decide true;
            };

            if (use_previous and element.cached_display != null) {
                img = rl.imageCopy(element.cached_display.?.img.?);
                texture = element.cached_display.?.texture.?;
            } else {
                if (assets.get.image(display.sprite)) |_img| {
                    img = _img;
                } else {
                    std.log.info("DISPLAY: IMAGE: MISSING IMAGE \"{s}\"", .{display.sprite});
                    continue;
                }

                if (style.background.fill == .contain) {
                    const img_w: f32 = @floatFromInt(img.width);
                    const img_h: f32 = @floatFromInt(img.height);

                    const img_aspect_ratio: f32 = img_w / img_h;
                    const transform_aspect_ration = transform.scale.x / transform.scale.y;

                    if (!std.math.approxEqRel(
                        f32,
                        img_aspect_ratio,
                        transform_aspect_ration,
                        0.0001,
                    )) {
                        origin.x -= (transform.scale.x - transform.scale.y * img_aspect_ratio) / 2;
                        transform.scale.x = transform.scale.y * img_aspect_ratio;
                    }
                }

                switch (display.scaling) {
                    .normal => rl.imageResize(
                        &img,
                        @intFromFloat(transform.scale.x),
                        @intFromFloat(transform.scale.y),
                    ),
                    .pixelate => rl.imageResizeNN(
                        &img,
                        @intFromFloat(transform.scale.x),
                        @intFromFloat(transform.scale.y),
                    ),
                }
                if (element.cached_display) |cached| {
                    if (cached.img) |chached_image| {
                        rl.unloadImage(chached_image);
                    }
                    if (cached.texture) |cached_texture| {
                        rl.unloadTexture(cached_texture);
                    }
                }

                element.cached_display = .{
                    .transform = transform,
                    .display = display,
                    .img = rl.imageCopy(img),
                    .texture = rl.loadTextureFromImage(img),
                };

                texture = element.cached_display.?.texture.?;
            }
            // defer rl.unloadTexture(texture);
            rl.drawTexturePro(
                texture,
                rl.Rectangle.init(
                    0,
                    0,
                    transform.scale.x,
                    transform.scale.y,
                ),
                rl.Rectangle.init(
                    transform.position.x,
                    transform.position.y,
                    transform.scale.x,
                    transform.scale.y,
                ),
                origin,
                transform.rotation.z,
                rl.Color.white,
            );
        }

        FontRendering: {
            const content: [*:0]const u8 = element.contents orelse break :FontRendering;
            const font: rl.Font = assets.get.font(style.font.family) orelse break :FontRendering;

            const len = std.mem.indexOfSentinel(u8, 0, content);
            const fs = @constCast(&GUI.Unit{ .unit = .unit, .value = style.font.size }).calculate(0, 0);

            const ox: f32 = switch (style.text_align.x) {
                .min => 0,
                .center => fs * @as(f32, @floatFromInt(len)) / 2,
                .max => fs * @as(f32, @floatFromInt(len)),
            };
            const oy: f32 = switch (style.text_align.x) {
                .min => 0,
                .center => fs / 2,
                .max => fs,
            };

            if (style.font.shadow) |shadow| {
                rl.drawTextPro(
                    font,
                    content,
                    transform.position.add(shadow.offset),
                    rl.Vector2.init(ox, oy),
                    transform.rotation.z,
                    fs,
                    style.font.spacing,
                    Colour.make(shadow.color),
                );
            }

            rl.drawTextPro(
                font,
                content,
                transform.position,
                // origin,
                rl.Vector2.init(ox, oy),
                transform.rotation.z,
                fs,
                style.font.spacing,
                Colour.make(style.color),
            );
        }
    }
}

fn drawTetxure(
    texture: rl.Texture,
    transform: entities.Transform,
    tint: Colour.HEX,
    ignore_cam: bool,
    collider: ?entities.RectangleVertices,
) void {
    const X = window.size.x / 2 +
        transform.position.x * camera.zoom -
        if (!ignore_cam) camera.position.x * camera.zoom else 0;

    const Y = window.size.y / 2 +
        transform.position.y * camera.zoom -
        if (!ignore_cam) camera.position.y * camera.zoom else 0;

    const origin = (transform.anchor orelse rl.Vector2{
        .x = transform.scale.x / 2,
        .y = transform.scale.y / 2,
    }).multiply(
        rl.Vector2.init(
            camera.zoom,
            camera.zoom,
        ),
    );

    const scaled = transform.scale.multiply(rl.Vector2{
        .x = camera.zoom,
        .y = camera.zoom,
    });

    rl.drawTexturePro(
        texture,
        rl.Rectangle.init(
            0,
            0,
            scaled.x,
            scaled.y,
        ),
        rl.Rectangle.init(
            X,
            Y,
            scaled.x,
            scaled.y,
        ),
        origin,
        transform.rotation.z,
        Colour.make(tint),
    );

    // Debug
    Debug: {
        if (!z.debug.debugDisplay) break :Debug;

        const origin_point = rl.Vector2.init(X, Y)
            .subtract(rl.Vector2
            .init(origin.x, origin.y)
            .rotate(std.math.degreesToRadians(transform.rotation.z)));

        rl.drawLine(
            @intFromFloat(X),
            @intFromFloat(Y),
            @intFromFloat(origin_point.x),
            @intFromFloat(origin_point.y),
            rl.Color.yellow,
        );

        rl.drawCircle(
            @intFromFloat(X),
            @intFromFloat(Y),
            2,
            rl.Color.purple,
        );
        rl.drawCircle(
            @intFromFloat(origin_point.x),
            @intFromFloat(origin_point.y),
            2,
            rl.Color.red,
        );

        if (collider) |coll| {
            const P0 = camera.worldPositionToScreenPosition(coll.top_left);
            const P1 = camera.worldPositionToScreenPosition(coll.top_right);
            const P2 = camera.worldPositionToScreenPosition(coll.bottom_left);
            const P3 = camera.worldPositionToScreenPosition(coll.bottom_right);

            rl.drawCircle(
                @intFromFloat(
                    P0.x,
                ),
                @intFromFloat(
                    P0.y,
                ),
                4,
                rl.Color.pink,
            );
            rl.drawCircle(
                @intFromFloat(
                    P1.x,
                ),
                @intFromFloat(
                    P1.y,
                ),
                4,
                rl.Color.gold,
            );
            rl.drawCircle(
                @intFromFloat(
                    P2.x,
                ),
                @intFromFloat(
                    P2.y,
                ),
                4,
                rl.Color.green,
            );
            rl.drawCircle(
                @intFromFloat(
                    P3.x,
                ),
                @intFromFloat(
                    P3.y,
                ),
                4,
                rl.Color.sky_blue,
            );

            // P0 -> P1
            rl.drawLine(
                @intFromFloat(
                    P0.x,
                ),
                @intFromFloat(
                    P0.y,
                ),
                @intFromFloat(
                    P1.x,
                ),
                @intFromFloat(
                    P1.y,
                ),
                rl.Color.pink,
            );

            // P1 -> P3
            rl.drawLine(
                @intFromFloat(
                    P1.x,
                ),
                @intFromFloat(
                    P1.y,
                ),
                @intFromFloat(
                    P3.x,
                ),
                @intFromFloat(
                    P3.y,
                ),
                rl.Color.gold,
            );

            // P0 -> P2
            rl.drawLine(
                @intFromFloat(
                    P0.x,
                ),
                @intFromFloat(
                    P0.y,
                ),
                @intFromFloat(
                    P2.x,
                ),
                @intFromFloat(
                    P2.y,
                ),
                rl.Color.green,
            );

            // P2 -> P3
            rl.drawLine(
                @intFromFloat(
                    P2.x,
                ),
                @intFromFloat(
                    P2.y,
                ),
                @intFromFloat(
                    P3.x,
                ),
                @intFromFloat(
                    P3.y,
                ),
                rl.Color.sky_blue,
            );
            // rl.drawCircle(
            //     @intFromFloat(
            //         X + transform.scale.x - coll.rect.width / 2,
            //     ),
            //     @intFromFloat(
            //         Y + transform.scale.y - coll.rect.height / 2,
            //     ),
            //     4,
            //     rl.Color.pink,
            // );
            return;
        }

        rl.drawRectanglePro(
            rl.Rectangle.init(
                X,
                Y,
                1,
                transform.scale.y * camera.zoom,
            ),
            origin,
            transform.rotation.z,
            rl.Color.lime,
        );
        rl.drawRectanglePro(
            rl.Rectangle.init(
                X,
                Y,
                1,
                transform.scale.y * camera.zoom,
            ),
            .{
                .x = origin.x - transform.scale.x * camera.zoom,
                .y = origin.y,
            },
            transform.rotation.z,
            rl.Color.lime,
        );
        rl.drawRectanglePro(
            rl.Rectangle.init(
                X,
                Y,
                transform.scale.x * camera.zoom,
                1,
            ),
            origin,
            transform.rotation.z,
            rl.Color.lime,
        );
        rl.drawRectanglePro(
            rl.Rectangle.init(
                X,
                Y,
                transform.scale.x * camera.zoom,
                1,
            ),
            .{
                .x = origin.x,
                .y = origin.y - transform.scale.y * camera.zoom,
            },
            transform.rotation.z,
            rl.Color.lime,
        );
        rl.drawFPS(10, 10);
    }
}
