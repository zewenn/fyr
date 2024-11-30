const std = @import("std");
const e = @import("../../engine/engine.m.zig");

const GUI = e.GUI;
const u = GUI.u;
const toUnit = GUI.toUnit;

var menu_music: e.Sound = undefined;

pub fn awake() !void {
    e.input.ui_mode = true;
    menu_music = e.assets.get.wave("audio/music/main_menu.mp3").?;
    e.setSoundVolume(menu_music, 0.1);

    try GUI.Body(
        .{
            .id = "Body",
            .style = .{
                .width = u("100%"),
                .height = u("100%"),
            },
        },
        @constCast(
            &[_]*GUI.GUIElement{
                try GUI.Container(
                    .{
                        .id = "logo",
                        .style = .{
                            .width = toUnit(80 * 8),
                            .height = toUnit(16 * 8),
                            .background = .{
                                .image = "sprites/gui/logo.png",
                            },
                            .translate = .{
                                .x = .center,
                                .y = .center,
                            },
                            .left = u("50%"),
                            .top = u("35%"),
                        },
                    },
                    @constCast(
                        &[_]*GUI.GUIElement{},
                    ),
                ),
                try GUI.Button(
                    .{
                        .id = "PlayBtn",
                        .style = .{
                            .translate = .{
                                .x = .center,
                                .y = .center,
                            },
                            .left = u("50%"),
                            .top = u("50%"),
                            .font = .{
                                .size = 16,
                            },
                            .color = e.Colour.white,
                        },
                        .hover = .{
                            .font = .{
                                .size = 18,
                            },
                        },
                    },
                    "Play Game",
                    e.Vec2(8, 4),
                    (struct {
                        pub fn callback() !void {
                            try e.nextFrame((struct {
                                pub fn callback() !void {
                                    e.input.ui_mode = false;
                                    try e.scenes.load("game");
                                }
                            }).callback);
                        }
                    }).callback,
                ),
            },
        ),
        "",
    );
}

pub fn init() !void {
    e.playSound(menu_music);
    //     e.input.ui_mode = false;
    //     try e.scenes.load("game");
}

pub fn update() !void {
    if (e.isKeyPressed(.key_space)) {
        e.input.ui_mode = false;
        try e.scenes.load("game");
    }
}

pub fn deinit() !void {
    e.stopSound(menu_music);
}
