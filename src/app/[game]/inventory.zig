const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const GUI = e.GUI;

const u = GUI.u;
const toUnit = GUI.toUnit;

const prefabs = @import("items.zig").prefabs;
const usePrefab = @import("items.zig").usePrefab;

var current_row_bag_items: usize = 0;
var current_row_bag_spells: usize = 0;
const max_rows: comptime_int = 12;

const bag_pages: comptime_int = 3;
const bag_page_rows: comptime_int = 4;
const bag_page_cols: comptime_int = 4;
const items_bag_size: comptime_int = max_rows * bag_page_cols;
const spells_bag_size: comptime_int = (max_rows) * spell_bag_page_cols;
const bag_page_size: comptime_int = bag_page_cols * bag_page_rows;

const spell_bag_page_rows: comptime_int = 4;
const spell_bag_page_cols: comptime_int = 2;

pub const Item = conf.Item;

pub var delete_mode: bool = false;
pub var delete_mode_last_frame: bool = false;

pub var HandsWeapon: Item = undefined;

pub var bag: []?conf.Item = undefined;
pub var sorted_bag: []*?conf.Item = undefined;

pub var spell_bag: []?conf.Item = undefined;
pub var sorted_spell_bag: []*?conf.Item = undefined;

pub var animation_mapping_dummy: e.entities.Entity = undefined;
pub var dummy_animator: e.Animator = undefined;

pub var spell_equip_mode: bool = false;

pub const equippedbar = struct {
    pub var current_weapon: *Item = &HandsWeapon;
    pub var ring: ?*Item = null;
    pub var amethyst: ?*Item = null;
    pub var wayfinder: ?*Item = null;

    pub const spells = struct {
        pub var q: ?*Item = null;
        pub var e: ?*Item = null;
        pub var r: ?*Item = null;
        pub var x: ?*Item = null;
    };

    pub fn equip(item: *Item) void {
        switch (item.T) {
            .spell => {
                spell_equip_mode = true;
                return;
            },
            .weapon => {
                unequip(current_weapon);
                current_weapon = item;
            },
            .ring => {
                if (ring != null) unequip(ring.?);
                ring = item;
            },
            .amethyst => {
                if (amethyst != null) unequip(amethyst.?);
                amethyst = item;
            },
            .wayfinder => {
                if (wayfinder != null) unequip(wayfinder.?);
                wayfinder = item;
            },
        }

        item.equipped = true;

        sortBag();
        updateGUI() catch {};
        autoSelect() catch {};
    }

    pub fn equipSpell(item: *Item, slot: conf.SpellSlots) void {
        if (item.T != .spell) {
            equip(item);
            return;
        }

        const ptr = switch (slot) {
            .q => &(spells.q),
            .e => &(spells.e),
            .r => &(spells.r),
            .x => &(spells.x),
        };

        if (ptr.* != null) unequip(ptr.*.?);

        ptr.* = item;

        item.equipped = true;
        item.equipped_spell_slot = slot;

        spell_equip_mode = false;

        sortBag();
        updateGUI() catch {};
        autoSelect() catch {};
    }

    pub fn autoEquip() void {
        for (bag, 0..) |itemornull, index| {
            if (itemornull == null) continue;
            const item = &(bag[index].?);
            if (!item.equipped) continue;

            equippedbar.equipSpell(item, if (item.equipped_spell_slot) |x| x else .q);
        }
        for (spell_bag, 0..) |itemornull, index| {
            if (itemornull == null) continue;
            const item = &(spell_bag[index].?);
            if (!item.equipped) continue;

            equippedbar.equipSpell(item, if (item.equipped_spell_slot) |x| x else .q);
        }
    }

    pub fn unequip(item: *Item) void {
        item.equipped = false;
        switch (item.T) {
            .spell => Spell: {
                if (item.equipped_spell_slot == null) break :Spell;
                const ptr = switch (item.equipped_spell_slot.?) {
                    .q => &(spells.q),
                    .e => &(spells.e),
                    .r => &(spells.r),
                    .x => &(spells.x),
                };

                ptr.* = null;
                item.equipped_spell_slot = null;
            },
            .weapon => {
                current_weapon = &HandsWeapon;
                HandsWeapon.equipped = true;
            },
            .ring => ring = null,
            .amethyst => amethyst = null,
            .wayfinder => wayfinder = null,
        }
    }

    pub fn get(comptime T: conf.ItemStats) f32 {
        const fieldname: []const u8 = comptime switch (T) {
            .damage => "damage",
            .health => "health",
            .crit_rate => "crit_rate",
            .crit_damage => "crit_damage",
            .movement_speed => "movement_speed",
            .tenacity => "tenacity",
            .dash_charges => "dash_charges",
        };

        return @field(current_weapon, fieldname) +
            if (ring) |i| @field(i, fieldname) else 0 +
            if (amethyst) |i| @field(i, fieldname) else 0 +
            if (wayfinder) |i| @field(i, fieldname) else 0;
    }
};

var INVENTORY_GUI: *GUI.GUIElement = undefined;
var shown: bool = false;
var bag_element: *GUI.GUIElement = undefined;
var is_preview_heap_loaded = false;
var item_slots: []*GUI.GUIElement = undefined;
var spell_slots: []*GUI.GUIElement = undefined;

const SLOT_SIZE: f32 = 24 * 4;
const SPACING_SIZE: f32 = SLOT_SIZE / 4;
const PREVIEW_FONT_COLOR: e.Colour.HEX = e.Colour.white;

const WIDTH_VW: f32 = SLOT_SIZE * bag_page_cols + SPACING_SIZE * (bag_page_cols - 1);
const HEIGHT_VW: f32 = SLOT_SIZE * bag_page_rows + SPACING_SIZE * (bag_page_rows - 1);

const SPELLS_BAR_WIDTH_VW: f32 = SLOT_SIZE * 2 + SPACING_SIZE;
const EQUIPPED_BAR_WIDTH_VW: f32 = SLOT_SIZE * 2 + SPACING_SIZE;

const PREVIEW_2x1 = "sprites/gui/preview_2x1.png";
const PREVIEW_4x1 = "sprites/gui/preview_4x1.png";
const PREVIEW_2x2 = "sprites/gui/slots/48x48/common.png";
const PREVIEW_EPIC_2x2 = "sprites/gui/slots/48x48/epic.png";
const PREVIEW_LEGENDARY_2x2 = "sprites/gui/slots/48x48/legendary.png";

const SLOT_HIGHLIGHT = "sprites/gui/selectors/normal/24x24.png";
const SLOT_DELETE = "sprites/gui/selectors/delete/24x24.png";

pub const preview = struct {
    var is_shown = false;
    var selected = false;
    var selected_item: ?*Item = null;

    pub var element: *GUI.GUIElement = undefined;

    pub var display: *GUI.GUIElement = undefined;
    pub var display_item: *GUI.GUIElement = undefined;
    pub var level_number: *GUI.GUIElement = undefined;
    pub var name: *GUI.GUIElement = undefined;
    pub var damage: *GUI.GUIElement = undefined;
    pub var health: *GUI.GUIElement = undefined;
    pub var crit_rate: *GUI.GUIElement = undefined;
    pub var crit_damage: *GUI.GUIElement = undefined;
    pub var move_speed: *GUI.GUIElement = undefined;
    pub var attack_speed: *GUI.GUIElement = undefined;
    pub var tenacity: *GUI.GUIElement = undefined;
    pub var upgrade_title_text: *GUI.GUIElement = undefined;
    pub var upgrade_cost_text: *GUI.GUIElement = undefined;
    pub var upgrade_currency_shower: *GUI.GUIElement = undefined;
    pub var equip: *GUI.GUIElement = undefined;

    pub const generic_stat_button_style = GUI.StyleSheet{
        .background = .{
            .image = "sprites/gui/slots/52x12/empty.png",
        },
        .width = .{
            .value = SLOT_SIZE * 2 + SPACING_SIZE,
            .unit = .unit,
        },
        .height = .{
            .value = SLOT_SIZE / 2,
            .unit = .unit,
        },

        .translate = .{
            .x = .min,
            .y = .center,
        },

        .font = .{
            .size = 14,
            .shadow = .{
                .color = e.Colour.black,
                .offset = e.Vec2(2, 2),
            },
        },
    };

    pub fn select() void {
        element = GUI.assertSelect("#item-preview");

        display = GUI.assertSelect("#preview-display");
        display_item = GUI.assertSelect("#preview-display-item");
        level_number = GUI.assertSelect("#preview-level-number");
        name = GUI.assertSelect("#preview-item-name");
        damage = GUI.assertSelect("#preview-damage-number");
        health = GUI.assertSelect("#preview-health-number");
        crit_rate = GUI.assertSelect("#preview-crit-rate-number");
        crit_damage = GUI.assertSelect("#preview-crit-damage-number");
        move_speed = GUI.assertSelect("#preview-move-speed-number");
        attack_speed = GUI.assertSelect("#preview-attack-speed-number");
        tenacity = GUI.assertSelect("#preview-tenacity-number");
        upgrade_title_text = GUI.assertSelect("#preview-upgrade-title");
        upgrade_cost_text = GUI.assertSelect("#preview-upgrade-text");
        upgrade_currency_shower = GUI.assertSelect("#preview-upgrade-currency");
        equip = GUI.assertSelect("#preview-equip-button");

        selected = true;
    }

    pub fn toNamedHeapString(elem: *GUI.GUIElement, string: []const u8, number: f32, percent: bool) !void {
        const named_string = try std.fmt.allocPrint(e.ALLOCATOR, "{s}: {d:.0}{s}", .{ string, number, if (percent) "%" else "" });
        defer e.ALLOCATOR.free(named_string);

        elem.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, named_string);
        elem.is_content_heap = true;
    }

    pub fn show(item: *Item) !void {
        if (selected_item != item) {
            spell_equip_mode = false;
        }
        selected_item = item;

        if (!selected) {
            std.log.warn("Element weren't selected!", .{});
            select();
        }

        free();

        display.options.style.background.image = switch (item.rarity) {
            .common => PREVIEW_2x2,
            .epic => PREVIEW_EPIC_2x2,
            .legendary => PREVIEW_LEGENDARY_2x2,
        };

        display_item.options.style.background.image = item.icon;

        const level_string = try e.zlib.arrays.NumberToString(e.ALLOCATOR, item.level);
        defer e.ALLOCATOR.free(level_string);

        level_number.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, level_string);
        level_number.is_content_heap = true;

        name.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, item.name);
        name.is_content_heap = true;

        try toNamedHeapString(damage, "DAMAGE", item.damage, false);
        try toNamedHeapString(health, "HEALTH", item.health, false);
        try toNamedHeapString(crit_rate, "CRIT RATE", item.crit_rate, true);
        try toNamedHeapString(crit_damage, "CRIT DMG", item.crit_damage_multiplier, true);
        try toNamedHeapString(move_speed, "MOVE SPEED", item.movement_speed, false);
        try toNamedHeapString(attack_speed, "ATK SPEED", @round(1 / item.attack_speed), false);
        try toNamedHeapString(tenacity, "TENACITY", item.tenacity, false);

        const upgrade_text_string = try e.zlib.arrays.NumberToString(
            e.ALLOCATOR,
            item.base_upgrade_cost + item.cost_per_level * item.level,
        );
        defer e.ALLOCATOR.free(upgrade_text_string);

        upgrade_cost_text.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, upgrade_text_string);
        upgrade_cost_text.is_content_heap = true;

        upgrade_cost_text.options.style.width = .{
            .value = e.loadf32(upgrade_text_string.len) * upgrade_cost_text.options.style.font.size,
            .unit = .px,
        };

        upgrade_cost_text.options.style.left = .{
            .value = -1 * (upgrade_cost_text.options.style.font.size) / 2,
            .unit = .px,
        };

        upgrade_currency_shower.options.style.left = toUnit(
            e.loadf32(upgrade_text_string.len - 1) / 2 * upgrade_cost_text.options.style.font.size,
        );

        upgrade_title_text.contents = switch (e.input.input_mode) {
            .Keyboard => "UPGRADE (U)",
            .KeyboardAndMouse => "UPGRADE",
        };

        equip.contents = switch (e.input.input_mode) {
            .KeyboardAndMouse => switch (item.equipped) {
                true => "UNEQUIP",
                false => "EQUIP",
            },
            .Keyboard => switch (item.equipped) {
                true => "UNEQUIP (E)",
                false => "EQUIP (E)",
            },
        };
        equip.options.style.color = switch (item.unequippable) {
            true => PREVIEW_FONT_COLOR,
            false => e.Colour.gray,
        };

        showElement();
    }

    pub fn repaint() !void {
        if (preview.selected_item == null) return;
        try preview.show(selected_item.?);
    }

    pub fn free() void {
        if (level_number.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, level_number.contents.?);
        }
        if (name.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, name.contents.?);
        }
        if (damage.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, damage.contents.?);
        }
        if (health.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, health.contents.?);
        }
        if (crit_rate.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, crit_rate.contents.?);
        }
        if (crit_damage.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, crit_damage.contents.?);
        }
        if (move_speed.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, move_speed.contents.?);
        }
        if (attack_speed.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, attack_speed.contents.?);
        }
        if (tenacity.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, tenacity.contents.?);
        }
        if (upgrade_cost_text.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, upgrade_cost_text.contents.?);
        }
    }

    pub fn showElement() void {
        if (!selected) {
            std.log.warn("Element' weren't selectedd!", .{});
            select();
        }

        element.options.style.top = u("50%");
        is_shown = true;
    }

    pub fn hideElement() void {
        if (!selected) {
            std.log.warn("Element' weren't selectedd!", .{});
            select();
        }

        selected_item = null;
        element.options.style.top = u("-100%");
        is_shown = false;
    }

    pub fn equippButtonCallback() !void {
        const it = preview.selected_item;
        const item = it orelse return;
        //
        if (!item.unequippable) return;
        //
        switch (item.equipped) {
            true => equippedbar.unequip(item),
            false => equippedbar.equip(item),
        }
        //
        sortBag();
        try updateGUI();
        try preview.show(preview.selected_item.?);
    }
};

/// The sorting function `sortBag()` uses.
fn sortItems(_: void, a: *?conf.Item, b: *?conf.Item) bool {
    if (b.* == null) return true;
    if (a.* == null) return false;

    if (a.*.?.equipped and !b.*.?.equipped) return true;
    if (!a.*.?.equipped and b.*.?.equipped) return false;

    if (b.*.?.rarity == .common and a.*.?.rarity != .common) return true;
    if (b.*.?.rarity == .epic and a.*.?.rarity == .legendary) return true;

    const a_val: usize = @intFromEnum(a.*.?.T);
    const b_val: usize = @intFromEnum(b.*.?.T);
    if (b.*.?.rarity == a.*.?.rarity) {
        if (a_val != b_val) return a_val <= b_val;
        if (a_val == @intFromEnum(conf.ItemTypes.weapon) and b_val == @intFromEnum(conf.ItemTypes.weapon)) {
            return @intFromEnum(a.*.?.weapon_type) <= @intFromEnum(b.*.?.weapon_type);
        }
    }

    if (a.*.?.rarity == .common and b.*.?.rarity != .common) return false;
    if (a.*.?.rarity == .epic and b.*.?.rarity == .legendary) return false;

    return a.*.?.name[0] <= b.*.?.name[0];
}

/// Sorts the bag, result is in `sorted_bag`.
/// `null`s will be at the end of the array.
pub fn sortBag() void {
    std.sort.insertion(
        *?conf.Item,
        sorted_bag,
        {},
        sortItems,
    );
    std.sort.insertion(
        *?conf.Item,
        sorted_spell_bag,
        {},
        sortItems,
    );
}

/// Return `true` when the item was picked up successfully,
/// `false` when the inventory is full.
pub fn pickUp(item: conf.Item) bool {
    const iterated_bag: []?conf.Item = switch (item.T) {
        .spell => spell_bag,
        else => bag,
    };

    for (iterated_bag, 0..) |it, index| {
        if (it != null) continue;

        iterated_bag[index] = item;
        return true;
    }
    return false;
}

/// Picks up the item, if the inventory is full returns `false` else `true`.
/// Sorts the bag by calling `sortBag()`.
pub fn pickUpSort(item: conf.Item) bool {
    const res = pickUp(item);
    sortBag();
    return res;
}

/// Refreses the UI to contain all items on the page
pub fn updateGUI() !void {
    for (0..bag_page_rows) |row| {
        for (0..bag_page_cols) |col| {
            const index =
                (row + @min(current_row_bag_items, max_rows - bag_page_rows)) *
                bag_page_cols +
                col;

            const element_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(element_selector);

            const button_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-btn-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(button_selector);

            const shower_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-btn-shower-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(shower_selector);

            const element: *GUI.GUIElement = if (GUI.select(element_selector)) |el| el else continue;
            const button: *GUI.GUIElement = if (GUI.select(button_selector)) |el| el else continue;
            const shower: *GUI.GUIElement = if (GUI.select(shower_selector)) |el| el else continue;

            const item = sorted_bag[index].*;

            if (item) |it| {
                shower.options.style.background.image = it.icon;

                element.options.style.background.image = switch (it.equipped) {
                    false => switch (it.rarity) {
                        .common => "sprites/gui/slots/24x24/common.png",
                        .epic => "sprites/gui/slots/24x24/epic.png",
                        .legendary => "sprites/gui/slots/24x24/legendary.png",
                    },
                    true => switch (it.rarity) {
                        .common => "sprites/gui/slots/24x24/common_equipped.png",
                        .epic => "sprites/gui/slots/24x24/epic_equipped.png",
                        .legendary => "sprites/gui/slots/24x24/legendary_equipped.png",
                    },
                };

                if (delete_mode) {
                    button.options.hover.background.image = "sprites/gui/delete_slot.png";
                    continue;
                }
                button.options.hover.background.image = SLOT_HIGHLIGHT;
                continue;
            }

            button.options.hover.background.image = switch (delete_mode) {
                false => SLOT_HIGHLIGHT,
                true => SLOT_DELETE,
            };

            shower.options.style.background.image = null;
            element.options.style.background.image = "sprites/gui/item_slot_empty.png";
        }
    }
    for (0..spell_bag_page_rows) |row| {
        for (0..spell_bag_page_cols) |col| {
            const index =
                (row + @min(current_row_bag_spells, max_rows - spell_bag_page_rows)) *
                spell_bag_page_cols +
                col;

            const element_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#spell-slot-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(element_selector);

            const button_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#spell-slot-btn-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(button_selector);

            const shower_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#spell-slot-btn-shower-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(shower_selector);

            const element: *GUI.GUIElement = if (GUI.select(element_selector)) |el| el else continue;
            const button: *GUI.GUIElement = if (GUI.select(button_selector)) |el| el else continue;
            const shower: *GUI.GUIElement = if (GUI.select(shower_selector)) |el| el else continue;

            const spell = sorted_spell_bag[index].*;

            if (spell) |sp| {
                shower.options.style.background.image = sp.icon;

                element.options.style.background.image = switch (sp.equipped) {
                    false => switch (sp.rarity) {
                        .common => "sprites/gui/slots/24x24/common.png",
                        .epic => "sprites/gui/slots/24x24/epic.png",
                        .legendary => "sprites/gui/slots/24x24/legendary.png",
                    },
                    true => switch (sp.rarity) {
                        .common => "sprites/gui/slots/24x24/common_equipped.png",
                        .epic => "sprites/gui/slots/24x24/epic_equipped.png",
                        .legendary => "sprites/gui/slots/24x24/legendary_equipped.png",
                    },
                };

                if (delete_mode) {
                    button.options.hover.background.image = "sprites/gui/delete_slot.png";
                    continue;
                }
                button.options.hover.background.image = SLOT_HIGHLIGHT;
                continue;
            }

            button.options.hover.background.image = switch (delete_mode) {
                false => SLOT_HIGHLIGHT,
                true => SLOT_DELETE,
            };

            shower.options.style.background.image = null;
            element.options.style.background.image = "sprites/gui/slots/24x24/empty_spell.png";
        }
    }

    const delete_button = GUI.assertSelect("#delete_mode_shower");
    switch (delete_mode) {
        true => {
            delete_button.options.style.rotation = 15;
        },
        false => {
            delete_button.options.style.rotation = 0;
        },
    }

    const base_tags = [_][]const u8{
        "weapon",
        "ring",
        "amethyst",
        "wayfinder",
        "spell_q",
        "spell_e",
        "spell_r",
        "spell_x",
    };
    const enum_tags = [_]conf.ItemTypes{
        .weapon,
        .ring,
        .amethyst,
        .wayfinder,
        .spell,
        .spell,
        .spell,
        .spell,
    };

    for (base_tags, enum_tags) |tag, etag| {
        const element_selector = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "#equipped_{s}",
            .{tag},
        );
        defer e.ALLOCATOR.free(element_selector);

        const button_selector = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "#equipped_{s}_btn",
            .{tag},
        );
        defer e.ALLOCATOR.free(button_selector);

        const shower_selector = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "#equipped_{s}_shower",
            .{tag},
        );
        defer e.ALLOCATOR.free(shower_selector);

        const element: *GUI.GUIElement = if (GUI.select(element_selector)) |el| el else continue;
        const button: *GUI.GUIElement = if (GUI.select(button_selector)) |el| el else continue;
        const shower: *GUI.GUIElement = if (GUI.select(shower_selector)) |el| el else continue;

        const item: ?*Item = switch (etag) {
            .spell => Res: {
                if (std.mem.eql(u8, tag, "spell_q")) break :Res equippedbar.spells.q;
                if (std.mem.eql(u8, tag, "spell_e")) break :Res equippedbar.spells.e;
                if (std.mem.eql(u8, tag, "spell_r")) break :Res equippedbar.spells.r;
                if (std.mem.eql(u8, tag, "spell_x")) break :Res equippedbar.spells.x;
                break :Res null;
            },
            .weapon => equippedbar.current_weapon,
            .ring => equippedbar.ring,
            .amethyst => equippedbar.amethyst,
            .wayfinder => equippedbar.wayfinder,
        };

        if (item == null) {
            button.options.hover.background.image = switch (delete_mode) {
                false => SLOT_HIGHLIGHT,
                true => SLOT_DELETE,
            };

            shower.options.style.background.image = null;
            element.options.style.background.image = switch (etag) {
                .spell => "sprites/gui/slots/24x24/empty_spell.png",
                .weapon => "sprites/gui/slots/24x24/empty_weapon.png",
                .amethyst => "sprites/gui/slots/24x24/empty_amethyst.png",
                .ring => "sprites/gui/slots/24x24/empty_ring.png",
                else => "sprites/gui/item_slot_empty.png",
            };
            continue;
        }

        const it = item.?;

        shower.options.style.background.image = it.icon;

        element.options.style.background.image = switch (it.rarity) {
            .common => "sprites/gui/slots/24x24/common.png",
            .epic => "sprites/gui/slots/24x24/epic.png",
            .legendary => "sprites/gui/slots/24x24/legendary.png",
        };

        if (delete_mode) {
            button.options.hover.background.image = "sprites/gui/delete_slot.png";
            continue;
        }
        button.options.hover.background.image = SLOT_HIGHLIGHT;
    }

    const spell_q_display = GUI.assertSelect("#equipped_spell_q_shower");
    const spell_e_display = GUI.assertSelect("#equipped_spell_e_shower");
    const spell_r_display = GUI.assertSelect("#equipped_spell_r_shower");
    const spell_x_display = GUI.assertSelect("#equipped_spell_x_shower");

    if (spell_equip_mode) {
        spell_q_display.contents = "Q";
        spell_e_display.contents = "E";
        spell_r_display.contents = "R";
        spell_x_display.contents = "X";
        return;
    }
    spell_q_display.contents = "";
    spell_e_display.contents = "";
    spell_r_display.contents = "";
    spell_x_display.contents = "";

    // if (e.input.input_mode == .Keyboard) try autoSelect();
}

pub fn logSortedBag() void {
    std.log.debug("Sorted bag: ", .{});
    for (sorted_bag, 0..) |it, i| {
        std.debug.print("{d}: ", .{i});
        if (it.*) |item| {
            std.debug.print("{s}\n", .{item.icon});
            continue;
        }
        std.debug.print("null\n", .{});
    }
}

pub fn autoSelect() !void {
    const button = GUI.hovered_button orelse return;

    if (button.button_interface_ptr == null) return;

    if (std.mem.containsAtLeast(u8, button.options.id, 1, "slot") or
        std.mem.containsAtLeast(u8, button.options.id, 1, "equipped"))
    {
        const dm_original = delete_mode;
        delete_mode = false;
        try button.button_interface_ptr.?.callback_fn();
        delete_mode = dm_original;
    }
}

/// Generates the button/slot interface
inline fn MainSlotButton(
    id: []const u8,
    btn_id: []const u8,
    shower_id: []const u8,
    is_spell: bool,
    col_start: f32,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = SLOT_SIZE,
                .unit = .unit,
            },
            .height = .{
                .value = SLOT_SIZE,
                .unit = .unit,
            },
            .left = .{
                .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + SPACING_SIZE),
                .unit = .unit,
            },
            .top = .{
                .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + SPACING_SIZE),
                .unit = .unit,
            },
            .background = .{
                .image = "sprites/gui/slots/24x24/common.png",
                // .color = e.Color.purple,
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .width = u("100%"),
                    .height = u("100%"),
                    .top = u("0%"),
                    .left = u("0%"),
                },
                .hover = .{
                    .background = .{
                        .image = "sprites/gui/slot_highlight.png",
                    },
                },
            },
            "",
            e.Vec2(0 + col + col_start, 0 + row + 1),
            if (func) |fun| fun else (struct {
                pub fn callback() anyerror!void {
                    const item = switch (is_spell) {
                        false => sorted_bag[
                            (current_row_bag_items +
                                row) * bag_page_cols +
                                col
                        ],
                        true => sorted_spell_bag[
                            (current_row_bag_spells +
                                row) * spell_bag_page_cols +
                                col
                        ],
                    };
                    //
                    if (delete_mode) {
                        if (col_start != 0)
                            item.* = null;
                        sortBag();
                        try updateGUI();
                        return;
                    }
                    //
                    if (item.* == null) {
                        preview.hideElement();
                        return;
                    }
                    try preview.show(
                        try e.zlib.nullAssertOptionalPointer(Item, item),
                    );
                }
            }).callback,
        ),
        try GUI.Empty(.{
            .id = shower_id,
            .style = .{
                .width = u("75%"),
                .height = u("75%"),
                .top = u("50%"),
                .left = u("50%"),
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .background = .{
                    .image = "sprites/entity/player/weapons/gloves/left.png",
                    .fill = .contain,
                },
            },
        }),
    }));
}

/// Generates the button/slot interface
inline fn EquippedSlotButton(
    id: []const u8,
    btn_id: []const u8,
    shower_id: []const u8,
    col_start: f32,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    item_type: conf.ItemTypes,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = SLOT_SIZE,
                .unit = .unit,
            },
            .height = .{
                .value = SLOT_SIZE,
                .unit = .unit,
            },
            .left = .{
                .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + SPACING_SIZE),
                .unit = .unit,
            },
            .top = .{
                .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + SPACING_SIZE),
                .unit = .unit,
            },
            .background = .{
                .image = "sprites/gui/slots/24x24/common.png",
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .width = u("100%"),
                    .height = u("100%"),
                    .top = u("0%"),
                    .left = u("0%"),
                },
                .hover = .{
                    .background = .{
                        .image = "sprites/gui/slot_highlight.png",
                    },
                },
            },
            "",
            e.Vec2(0 + col + col_start, 0 + row),
            if (func) |fun| fun else (struct {
                pub fn callback() anyerror!void {
                    const item: ?*Item = switch (item_type) {
                        .spell => Res: {
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_q")) break :Res equippedbar.spells.q;
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_e")) break :Res equippedbar.spells.e;
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_r")) break :Res equippedbar.spells.r;
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_x")) break :Res equippedbar.spells.x;
                            break :Res null;
                        },
                        .weapon => equippedbar.current_weapon,
                        .ring => equippedbar.ring,
                        .amethyst => equippedbar.amethyst,
                        .wayfinder => equippedbar.wayfinder,
                    };
                    //
                    if (item_type == .spell and spell_equip_mode) {
                        equippedbar.equipSpell(preview.selected_item.?, Res: {
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_q"))
                                break :Res .q;
                            //
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_e"))
                                break :Res .e;
                            //
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_r"))
                                break :Res .r;
                            //
                            if (std.mem.containsAtLeast(u8, id, 1, "spell_x"))
                                break :Res .x;
                            //
                            break :Res .q;
                        });
                        return;
                    }
                    //
                    if (item == null) {
                        preview.hideElement();
                        return;
                    }
                    const it = item.?;
                    if (delete_mode) {
                        if (!std.mem.eql(u8, it.name, HandsWeapon.name)) {
                            equippedbar.unequip(it);
                            // const x = @as(*?Item, @ptrCast(it));
                            // x.* = null;
                        }
                        preview.hideElement();
                        sortBag();
                        try updateGUI();
                        return;
                    }
                    try preview.show(it);
                }
            }).callback,
        ),
        try GUI.Empty(.{
            .id = shower_id,
            .style = .{
                .width = u("75%"),
                .height = u("75%"),
                .left = u("50%"),
                .top = u("50%"),
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .background = .{
                    .image = "sprites/entity/player/weapons/gloves/left.png",
                    .fill = .contain,
                },
                .color = e.Colour.white,
                .font = .{
                    .size = 28,
                    .shadow = .{
                        .offset = e.Vec2(2, 2),
                        .color = e.Colour.black,
                    },
                },
            },
        }),
    }));
}

inline fn NavigatorButton(
    id: []const u8,
    btn_id: []const u8,
    shower_id: []const u8,
    col: usize,
    row: usize,
    width: f32,
    varptr: *usize,
    towards: enum { up, down },
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = width * SLOT_SIZE,
                .unit = .unit,
            },
            .height = preview.generic_stat_button_style.height,
            // .left = u("-50%"),
            .translate = .{ .x = .center },
            .top = .{
                .value = switch (towards) {
                    .up => -1,
                    .down => 1,
                } * (HEIGHT_VW + switch (towards) {
                    .up => 2,
                    .down => 0,
                } *
                    (preview.generic_stat_button_style.height.value) + 2 * SPACING_SIZE) / 2,
                .unit = .unit,
            },
            .background = .{
                .image = switch (@as(i32, @intFromFloat(width))) {
                    4 => "sprites/gui/slots/96x12/common.png",
                    2 => "sprites/gui/slots/48x12/common.png",
                    else => "sprites/gui/slots/24x24/common.png",
                },
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .width = u("100%"),
                    .height = u("100%"),
                    .top = u("0%"),
                    .left = u("-50%"),
                },
                .hover = .{
                    .background = .{
                        .image = switch (@as(i32, @intFromFloat(width))) {
                            4 => "sprites/gui/selectors/normal/96x12.png",
                            2 => "sprites/gui/selectors/normal/48x12.png",
                            else => "sprites/gui/selectors/normal/24x24.png",
                        },
                    },
                },
            },
            "",
            e.Vec2(0 + col, 0 + row),
            (struct {
                pub fn callback() anyerror!void {
                    const value = @as(i32, @intCast(varptr.*)) + @as(i32, switch (towards) {
                        .up => -1,
                        .down => 1,
                    });
                    if (value < 0) return;
                    if (value >= @as(i32, @intCast(max_rows - spell_bag_page_rows))) return;
                    varptr.* = @intCast(value);
                    try updateGUI();
                }
            }).callback,
        ),
        try GUI.Empty(.{
            .id = shower_id,
            .style = .{
                .width = u("75%"),
                .height = u("75%"),
                // .left = u("50%"),
                .top = u("50%"),
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .background = .{
                    .image = switch (towards) {
                        .up => "sprites/gui/arrow_up.png",
                        .down => "sprites/gui/arrow_down.png",
                    },
                    .fill = .contain,
                },
            },
        }),
    }));
}

pub fn show() void {
    GUI.BM3D.setLayer(1);
    // INVENTORY_GUI.options.style.top = u("0%");
    dummy_animator.play("slide_down") catch {};

    e.input.ui_mode = true;
    shown = true;
}

pub fn hide() void {
    GUI.BM3D.resetLayer();
    dummy_animator.play("slide_up") catch {};

    e.input.ui_mode = false;
    shown = false;
}

pub fn toggle() void {
    dummy_animator.stop("slide_up");
    dummy_animator.stop("slide_down");
    if (shown) hide() else show();
}

pub fn awake() !void {
    bag = try e.ALLOCATOR.alloc(?Item, items_bag_size);
    for (bag, 0..) |_, index| {
        bag[index] = null;
    }

    spell_bag = try e.ALLOCATOR.alloc(?Item, spells_bag_size);
    for (spell_bag, 0..) |_, index| {
        spell_bag[index] = null;
    }

    animation_mapping_dummy = e.entities.Entity.dummy();
    dummy_animator = e.Animator.init(&e.ALLOCATOR, &animation_mapping_dummy);
    {
        var slide_down = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "slide_down",
            e.Animator.interpolation.ease_in_out,
            0.25,
        );
        {
            _ = slide_down
                .chain(
                0,
                .{
                    .y = -100,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 0,
                    },
                },
            )
                .chain(
                100,
                .{
                    .y = 0,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = @intFromFloat(@round(@as(f32, 255) * @as(f32, 0.75))),
                    },
                },
            );
        }
        try dummy_animator.chain(slide_down);

        var slide_up = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "slide_up",
            e.Animator.interpolation.ease_in_out,
            0.25,
        );
        {
            _ = slide_up
                .chain(
                0,
                .{
                    .y = 0,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = @intFromFloat(@round(@as(f32, 255) * @as(f32, 0.85))),
                    },
                },
            )
                .chain(
                100,
                .{
                    .y = -100,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 0,
                    },
                },
            );
        }
        try dummy_animator.chain(slide_up);
    }

    GUI.BM3D.setLayer(1);
    HandsWeapon = usePrefab(prefabs.hands);

    sorted_bag = try e.ALLOCATOR.alloc(*?conf.Item, items_bag_size);
    sorted_spell_bag = try e.ALLOCATOR.alloc(*?conf.Item, spells_bag_size);

    for (0..bag.len) |index| {
        sorted_bag[index] = &(bag[index]);
    }

    for (0..spell_bag.len) |index| {
        sorted_spell_bag[index] = &(spell_bag[index]);
    }

    sortBag();

    // Auto equip last equipped items, since the equipped bar ain't saved
    // for (bag) |itemornull| {
    //     const item: *Item = if (itemornull) |*t| @constCast(t) else continue;
    //     if (!item.equipped) continue;

    //     equippedbar.equip(item);
    // }

    // Slot Generation
    item_slots = try e.ALLOCATOR.alloc(*GUI.GUIElement, bag_page_rows * bag_page_cols);

    inline for (0..bag_page_rows) |row| {
        inline for (0..bag_page_cols) |col| {
            const id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-{d}-{d}",
                .{ row, col },
            );
            const button_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-btn-{d}-{d}",
                .{ row, col },
            );
            const button_shower_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-btn-shower-{d}-{d}",
                .{ row, col },
            );

            item_slots[row * bag_page_cols + col] = try MainSlotButton(
                id,
                button_id,
                button_shower_id,
                false,
                2,
                col,
                row,
                WIDTH_VW,
                HEIGHT_VW,
                null,
            );

            item_slots[row * bag_page_cols + col].heap_id = true;
            item_slots[row * bag_page_cols + col].children.?.items[0].heap_id = true;
            item_slots[row * bag_page_cols + col].children.?.items[1].heap_id = true;
        }
    }

    spell_slots = try e.ALLOCATOR.alloc(*GUI.GUIElement, spell_bag_page_rows * spell_bag_page_cols);

    inline for (0..spell_bag_page_rows) |row| {
        inline for (0..spell_bag_page_cols) |col| {
            const id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "spell-slot-{d}-{d}",
                .{ row, col },
            );
            const button_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "spell-slot-btn-{d}-{d}",
                .{ row, col },
            );
            const button_shower_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "spell-slot-btn-shower-{d}-{d}",
                .{ row, col },
            );

            spell_slots[row * spell_bag_page_cols + col] = try MainSlotButton(
                id,
                button_id,
                button_shower_id,
                true,
                6,
                col,
                row,
                SPELLS_BAR_WIDTH_VW,
                HEIGHT_VW,
                null,
            );

            spell_slots[row * spell_bag_page_cols + col].heap_id = true;
            spell_slots[row * spell_bag_page_cols + col].children.?.items[0].heap_id = true;
            spell_slots[row * spell_bag_page_cols + col].children.?.items[1].heap_id = true;
        }
    }

    // The main GUI
    INVENTORY_GUI = try GUI.Container(
        .{
            .id = "InventoryParentBackground",
            .style = .{
                .background = .{
                    .color = 0x000000cc,
                },
                .top = u("-100%"),
                .left = u("50%"),
                .translate = .{
                    .x = .center,
                },
                .width = u("100w"),
                .height = u("100h"),
            },
        },
        @constCast(&[_]*GUI.GUIElement{
            // Main inventory / Items
            try GUI.Container(
                .{
                    .id = "Bag",
                    .style = .{
                        .width = .{
                            .value = WIDTH_VW,
                            .unit = .unit,
                        },
                        .height = .{
                            .value = HEIGHT_VW,
                            .unit = .unit,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = -1 * (2 * SLOT_SIZE + 2 * SPACING_SIZE),
                            .unit = .unit,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.blue,
                        },
                    },
                },
                item_slots,
            ),
            // Main inventory / Spells
            try GUI.Container(
                .{
                    .id = "Bag-Spells",
                    .style = .{
                        .width = .{
                            .value = SPELLS_BAR_WIDTH_VW,
                            .unit = .unit,
                        },
                        .height = .{
                            .value = HEIGHT_VW,
                            .unit = .unit,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = 1 * SLOT_SIZE + 1 * SPACING_SIZE,
                            .unit = .unit,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.pink,
                        },
                    },
                },
                // slots,
                spell_slots,
            ),
            // Equipped - Delete
            try GUI.Container(
                .{
                    .id = "equippedShower",
                    .style = .{
                        .width = .{
                            .value = EQUIPPED_BAR_WIDTH_VW,
                            .unit = .unit,
                        },
                        .height = .{
                            .value = HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                            .unit = .unit,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = -1 * (6 * SLOT_SIZE + 4 * SPACING_SIZE),
                            .unit = .unit,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.green,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    // Weapon
                    try EquippedSlotButton(
                        "equipped_weapon",
                        "equipped_weapon_btn",
                        "equipped_weapon_shower",
                        0,
                        0,
                        0,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .weapon,
                        null,
                    ),
                    // Ring
                    try EquippedSlotButton(
                        "equipped_ring",
                        "equipped_ring_btn",
                        "equipped_ring_shower",
                        0,
                        0,
                        1,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .ring,
                        null,
                    ),
                    // Amethyst
                    try EquippedSlotButton(
                        "equipped_amethyst",
                        "equipped_amethyst_btn",
                        "equipped_amethyst_shower",
                        0,
                        0,
                        2,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .amethyst,
                        null,
                    ),
                    // Wayfinder
                    try EquippedSlotButton(
                        "equipped_wayfinder",
                        "equipped_wayfinder_btn",
                        "equipped_wayfinder_shower",
                        0,
                        0,
                        3,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .wayfinder,
                        null,
                    ),
                    // Spell - Q
                    try EquippedSlotButton(
                        "equipped_spell_q",
                        "equipped_spell_q_btn",
                        "equipped_spell_q_shower",
                        0,
                        1,
                        0,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .spell,
                        null,
                    ),
                    // Spell - E
                    try EquippedSlotButton(
                        "equipped_spell_e",
                        "equipped_spell_e_btn",
                        "equipped_spell_e_shower",
                        0,
                        1,
                        1,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .spell,
                        null,
                    ),
                    // Spell - R
                    try EquippedSlotButton(
                        "equipped_spell_r",
                        "equipped_spell_r_btn",
                        "equipped_spell_r_shower",
                        0,
                        1,
                        2,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .spell,
                        null,
                    ),
                    // Spell - X
                    try EquippedSlotButton(
                        "equipped_spell_x",
                        "equipped_spell_x_btn",
                        "equipped_spell_x_shower",
                        0,
                        1,
                        3,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        .spell,
                        null,
                    ),
                    try MainSlotButton(
                        "delete_mode",
                        "delete_mode_btn",
                        "delete_mode_shower",
                        false,
                        0,
                        0,
                        4,
                        EQUIPPED_BAR_WIDTH_VW,
                        HEIGHT_VW + SLOT_SIZE + SPACING_SIZE,
                        (struct {
                            pub fn callback() anyerror!void {
                                delete_mode = !delete_mode;
                                try updateGUI();
                            }
                        }).callback,
                    ),
                }),
            ),
            // Main inventory / Items / BUTTONS
            try GUI.Container(
                .{
                    .id = "Bag-Buttons",
                    .style = .{
                        .width = .{
                            .value = WIDTH_VW,
                            .unit = .unit,
                        },
                        .height = .{
                            .value = HEIGHT_VW + 2 + preview.generic_stat_button_style.height.value * @as(f32, 2),
                            .unit = .unit,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = -1 * (2 * SLOT_SIZE + 2 * SPACING_SIZE),
                            .unit = .unit,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.lime,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    try NavigatorButton(
                        "bag-nav-up",
                        "bag-nav-up-btn",
                        "bag-nav-up-shower",
                        2,
                        0,
                        bag_page_cols,
                        &current_row_bag_items,
                        .up,
                    ),
                    try NavigatorButton(
                        "bag-nav-down",
                        "bag-nav-down-btn",
                        "bag-nav-down-shower",
                        2,
                        5,
                        bag_page_cols,
                        &current_row_bag_items,
                        .down,
                    ),
                }),
            ),
            // Main inventory / Spells / BUTTONS
            try GUI.Container(
                .{
                    .id = "Bag-Spells-Buttons",
                    .style = .{
                        .width = .{
                            .value = SPELLS_BAR_WIDTH_VW,
                            .unit = .unit,
                        },
                        .height = .{
                            .value = HEIGHT_VW + 2 + preview.generic_stat_button_style.height.value * @as(f32, 2),
                            .unit = .unit,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = -1 * (-1 * SLOT_SIZE - 1 * SPACING_SIZE),
                            .unit = .unit,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.lime,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    try NavigatorButton(
                        "bag-spells-nav-up",
                        "bag-spells-nav-up-btn",
                        "bag-spells-nav-up-shower",
                        6,
                        0,
                        spell_bag_page_cols,
                        &current_row_bag_spells,
                        .up,
                    ),
                    try NavigatorButton(
                        "bag-spells-nav-down",
                        "bag-spells-nav-down-btn",
                        "bag-spells-nav-down-shower",
                        6,
                        5,
                        spell_bag_page_cols,
                        &current_row_bag_spells,
                        .down,
                    ),
                }),
            ),

            // Preview
            try GUI.Container(
                .{
                    .id = "item-preview",
                    .style = .{
                        .width = .{
                            .value = SLOT_SIZE * 4 + 3 * SPACING_SIZE,
                            .unit = .unit,
                        },
                        .height = .{
                            .value = SLOT_SIZE * 7 + 6 * SPACING_SIZE,
                            .unit = .unit,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = 5 * SLOT_SIZE + 3 * SPACING_SIZE,
                            .unit = .unit,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.red,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    // Display
                    try GUI.Container(
                        .{
                            .id = "preview-display",
                            .style = .{
                                .width = .{
                                    .value = 2 * SLOT_SIZE + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .height = .{
                                    .value = 2 * SLOT_SIZE + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .top = u("-50%"),
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + SPACING_SIZE) - 0.5 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .background = .{
                                    .image = "sprites/gui/slots/24x24/legendary.png",
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Empty(
                                .{
                                    .id = "preview-display-item",
                                    .style = .{
                                        .width = u("75%"),
                                        .height = u("75%"),
                                        .top = u("50%"),
                                        .left = u("50%"),
                                        .background = .{
                                            .image = "sprites/entity/player/weapons/gloves/left.png",
                                            .fill = .contain,
                                        },
                                        .rotation = 0,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                            ),
                        }),
                    ),
                    // Level
                    try GUI.Container(
                        .{
                            .id = "preview-level-container",
                            .style = .{
                                .width = .{
                                    .value = 2 * SLOT_SIZE + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .height = .{
                                    .value = 2 * SLOT_SIZE + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = -2.5 * SLOT_SIZE - 2.5 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .left = .{
                                    .value = SLOT_SIZE * 1 + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .background = .{
                                    .image = "sprites/gui/slots/48x48/empty.png",
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Text(
                                .{
                                    .id = "preview-level-text",
                                    .style = .{
                                        .top = u("-28u"),
                                        .font = .{
                                            .size = 16,
                                            .shadow = preview.generic_stat_button_style.font.shadow,
                                        },
                                        .color = PREVIEW_FONT_COLOR,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "Level",
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-level-number",
                                    .style = .{
                                        .top = u("12u"),
                                        .font = .{
                                            .size = 44,
                                            .shadow = preview.generic_stat_button_style.font.shadow,
                                        },
                                        .color = PREVIEW_FONT_COLOR,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "90",
                            ),
                        }),
                    ),
                    // Name
                    try GUI.Text(
                        .{
                            .id = "preview-item-name",
                            .style = .{
                                // .width = .{
                                //     .value = 4 * SLOT_SIZE + SPACING_SIZE,
                                //     .unit = .unit,
                                // },
                                .width = u("100%"),
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = -1 * SLOT_SIZE * 1 - SPACING_SIZE,
                                    .unit = .unit,
                                },
                                // .left = .{
                                //     .value = SLOT_SIZE * 1 + 1,
                                //     .unit = .unit,
                                // },
                                .color = PREVIEW_FONT_COLOR,
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .background = .{
                                    .image = "sprites/gui/slots/108x24/empty.png",
                                },
                                .font = .{
                                    .size = 20,
                                    .shadow = preview.generic_stat_button_style.font.shadow,
                                },
                            },
                        },
                        "Item Name",
                    ),
                    // Damage
                    try GUI.Container(
                        .{
                            .id = "preview-damage-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5 * SPACING_SIZE),
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = -0.5 * SLOT_SIZE + SPACING_SIZE,
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-damage-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Health
                    try GUI.Container(
                        .{
                            .id = "preview-health-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .top = .{
                                    .value = -0.5 * SLOT_SIZE + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .left = .{
                                    .value = 0.5 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-health-number",
                                        .style = .{
                                            // .top = u("10x"),
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Crit Rate
                    try GUI.Container(
                        .{
                            .id = "preview-crit-rate-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .top = .{
                                    .value = 0 * SLOT_SIZE + 2 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5 * SPACING_SIZE),
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-crit-rate-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Crit Damage
                    try GUI.Container(
                        .{
                            .id = "preview-crit-damage-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .top = .{
                                    .value = 0 * SLOT_SIZE + 2 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .left = .{
                                    .value = 0.5 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-crit-damage-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Move Speed
                    try GUI.Container(
                        .{
                            .id = "preview-move-speed-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5 * SPACING_SIZE),
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = 0.5 * SLOT_SIZE + 3 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-move-speed-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Attack Speed
                    try GUI.Container(
                        .{
                            .id = "preview-attack-speed-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = 0.5 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = 0.5 * SLOT_SIZE + 3 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-attack-speed-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "10",
                                ),
                            },
                        ),
                    ),
                    // Tenacity
                    try GUI.Container(
                        .{
                            .id = "preview-tenacity-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5 * SPACING_SIZE),
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = 1 * SLOT_SIZE + 4 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-tenacity-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Equip
                    try GUI.Button(
                        .{
                            .id = "preview-equip-button",
                            .style = .{
                                .width = .{
                                    .value = SLOT_SIZE * 2 + 1 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .unit,
                                },
                                .left = .{
                                    .value = -1 * SLOT_SIZE - 1 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = SLOT_SIZE * 3 + 3 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .color = PREVIEW_FONT_COLOR,
                                .background = .{
                                    .image = "sprites/gui/slots/48x24/common.png",
                                },
                            },
                        },
                        "EQUIP",
                        e.Vec2(9, 5),
                        preview.equippButtonCallback,
                    ),
                    // Upgrade
                    try GUI.Container(
                        .{
                            .id = "preview-level-up",
                            .style = .{
                                .width = .{
                                    .value = SLOT_SIZE * 2 + SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .unit,
                                },
                                .left = .{
                                    .value = SLOT_SIZE + 1 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .top = .{
                                    .value = SLOT_SIZE * 3 + 3 * SPACING_SIZE,
                                    .unit = .unit,
                                },
                                .background = .{
                                    .image = "sprites/gui/page_btn_inactive.png",
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Button(
                                .{
                                    .id = "preview-upgrade-button",
                                    .style = .{
                                        .top = u("00%"),
                                        .left = u("00%"),
                                        .width = u("100%"),
                                        .height = u("100%"),
                                        .color = e.Colour.black,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                    .hover = .{
                                        .color = e.Colour.black,
                                        .background = .{
                                            .image = "sprites/gui/page_btn.png",
                                        },
                                    },
                                },
                                "",
                                e.Vec2(10, 0 + 5),
                                (struct {
                                    pub fn callback() anyerror!void {
                                        //
                                        sortBag();
                                        try updateGUI();
                                    }
                                }).callback,
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-upgrade-title",
                                    .style = .{
                                        .font = .{
                                            .size = 12,
                                        },
                                        .top = u("-8x"),
                                        .z_index = 10,
                                    },
                                },
                                "UPGRADE",
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-upgrade-text",
                                    .style = .{
                                        .font = .{
                                            .size = 16,
                                        },
                                        .top = u("8x"),
                                        .left = u("-4x"),
                                        .z_index = 10,
                                        .background = .{
                                            .color = e.Colour.blue,
                                        },
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "1",
                            ),
                            try GUI.Empty(
                                .{
                                    .id = "preview-upgrade-currency",
                                    .style = .{
                                        .width = u("16x"),
                                        .height = u("16x"),
                                        .left = u("4x"),
                                        .background = .{
                                            .image = e.MISSINGNO,
                                        },
                                        .z_index = 10,
                                    },
                                },
                            ),
                        }),
                    ),
                }),
            ),
        }),
    );

    const delete_button: *GUI.GUIElement = GUI.select("#delete_mode_shower") orelse return;

    delete_button.options.style.background.image = "sprites/gui/delete_toggle.png";
    delete_button.options.style.translate = .{
        .x = .center,
        .y = .center,
    };
    delete_button.options.style.top = u("50%");
    delete_button.options.style.left = u("50%");

    animation_mapping_dummy.transform.position.y = -100;
}

pub fn init() !void {
    preview.select();
    preview.hideElement();

    // _ = pickUpSort(
    //     usePrefab(prefabs.legendaries.weapons.legendary_sword),
    // );
    // _ = pickUpSort(
    //     usePrefab(prefabs.epics.weapons.piercing_sword),
    // );
    // _ = pickUpSort(
    //     usePrefab(prefabs.epics.amethysts.test_amethyst),
    // );
    // _ = pickUpSort(
    //     usePrefab(prefabs.legendaries.weapons.staff),
    // );
    // _ = pickUpSort(
    //     usePrefab(prefabs.legendaries.weapons.daggers),
    // );
    // _ = pickUpSort(
    //     usePrefab(.{
    //         .id = e.uuid.v7.new(),
    //         .T = .spell,

    //         .rarity = .common,

    //         .name = "Spell",

    //         .icon = "sprites/entity/enemies/brute/right_0.png",
    //     }),
    // );

    loadFromSave();
    if (bag[0] == null) {
        _ = pickUpSort(
            usePrefab(prefabs.legendaries.weapons.legendary_sword),
        );
        _ = pickUpSort(
            usePrefab(prefabs.epics.weapons.piercing_sword),
        );
        _ = pickUpSort(
            usePrefab(prefabs.epics.amethysts.normal_amethyst),
        );
        _ = pickUpSort(
            usePrefab(prefabs.legendaries.weapons.staff),
        );
        _ = pickUpSort(
            usePrefab(prefabs.legendaries.weapons.daggers),
        );
    }
    if (spell_bag[0] == null) {
        _ = pickUpSort(
            usePrefab(.{
                .id = e.uuid.v7.new(),
                .T = .spell,

                .rarity = .legendary,

                .spell_blessings = conf.createTypeArrayUnknownLength(
                    conf.Blessings,
                    @constCast(&[_]?conf.Blessings{
                        .steel,
                        .steel,
                        .fracture,
                        .fracture,
                        .fracture,
                        .fracture,
                        .fracture,
                        .fracture,
                        .fire,
                        .fire,
                        .fire,
                        .fire,
                        .zephyr,
                        .zephyr,
                    }),
                ),

                .name = "Spell",

                .icon = "sprites/entity/enemies/brute/left_0.png",
            }),
        );
        _ = pickUpSort(
            usePrefab(.{
                .id = e.uuid.v7.new(),
                .T = .spell,

                .rarity = .epic,

                .spell_blessings = conf.createTypeArrayUnknownLength(
                    conf.Blessings,
                    @constCast(&[_]?conf.Blessings{
                        .zephyr,
                        .zephyr,
                        .zephyr,
                        .zephyr,
                        .fracture,
                        .fracture,
                        .fracture,
                        .curse,
                        .curse,
                        .curse,
                        .curse,
                        .blood,
                        .blood,
                        .blood,
                    }),
                ),

                .name = "Spell",

                .icon = "sprites/entity/enemies/brute/left_0.png",
            }),
        );
    }

    // _ = pickUpSort(
    //     usePrefab(prefabs.epics.amethysts.normal_amethyst),
    // );
    // _ = pickUpSort(
    //     usePrefab(prefabs.legendaries.weapons.claymore),
    // );

    equippedbar.autoEquip();

    sortBag();

    try updateGUI();
}

pub fn update() !void {
    if (e.isKeyPressed(.key_i) or e.isKeyPressed(.key_tab)) toggle();
    if (e.isKeyPressed(.key_escape) and shown) hide();

    dummy_animator.update();

    INVENTORY_GUI.options.style.top = .{
        .value = animation_mapping_dummy.transform.position.y,
        .unit = .percent,
    };
    if (!e.input.ui_mode) return;

    if (GUI.BM3D.current_layer != 1) return;

    if ((e.isMouseButtonPressed(.mouse_button_left) or
        e.isKeyPressed(.key_enter) or
        e.isKeyPressed(.key_backspace) or
        e.isKeyPressed(.key_space)) and
        delete_mode_last_frame)
    {
        delete_mode = false;
        try updateGUI();
    }

    if (e.isKeyPressed(.key_backspace) and !delete_mode_last_frame) {
        delete_mode = true;
        try updateGUI();
    }

    if ((e.isKeyPressed(.key_up) or
        e.isKeyPressed(.key_down) or
        e.isKeyPressed(.key_left) or
        e.isKeyPressed(.key_right)) and
        GUI.hovered_button != null)
    {
        try autoSelect();
    }

    if (spell_equip_mode and preview.selected_item != null) {
        if (e.isKeyPressed(.key_q))
            equippedbar.equipSpell(preview.selected_item.?, .q)
        else if (e.isKeyPressed(.key_e))
            equippedbar.equipSpell(preview.selected_item.?, .e)
        else if (e.isKeyPressed(.key_r))
            equippedbar.equipSpell(preview.selected_item.?, .r)
        else if (e.isKeyPressed(.key_x))
            equippedbar.equipSpell(preview.selected_item.?, .x);

        if (preview.selected_item.?.equipped) {
            spell_equip_mode = false;

            sortBag();
            try updateGUI();
            try preview.repaint();
        }
    } else if (e.isKeyPressed(.key_e) and preview.is_shown) {
        try preview.equippButtonCallback();
    }

    if (e.isKeyPressed(.key_r) and e.isKeyDown(.key_left_control)) {
        loadFromSave();
        sortBag();
        try updateGUI();
        try preview.repaint();
    }

    delete_mode_last_frame = delete_mode;
}

pub fn deinit() !void {
    e.saveloader.save(e.ALLOCATOR, bag, "saved/bag.json") catch {
        std.log.err("Failed to save gamestate", .{});
    };
    e.saveloader.save(e.ALLOCATOR, spell_bag, "saved/spell_bag.json") catch {
        std.log.err("Failed to save gamestate", .{});
    };

    e.ALLOCATOR.free(item_slots);
    e.ALLOCATOR.free(spell_slots);
    e.ALLOCATOR.free(sorted_bag);
    e.ALLOCATOR.free(sorted_spell_bag);
    preview.free();

    dummy_animator.deinit();
    animation_mapping_dummy.deinit();

    e.ALLOCATOR.free(bag);
    e.ALLOCATOR.free(spell_bag);
}

fn loadFromSave() void {
    // BAG
    // ------------------------------------------------------------------------------------
    const loaded_bag = e.saveloader.load([]?Item, e.ARENA, "saved/bag.json");

    const loaded_bag_unwrapped = loaded_bag orelse return;
    defer e.ARENA.free(loaded_bag_unwrapped);

    std.mem.copyForwards(?Item, bag, loaded_bag_unwrapped);

    // SPELL BAG
    // ------------------------------------------------------------------------------------
    const loaded_spell_bag = e.saveloader.load([]?Item, e.ARENA, "saved/spell_bag.json");

    const loaded_spell_bag_unwrapped = loaded_spell_bag orelse return;
    defer e.ARENA.free(loaded_spell_bag_unwrapped);

    std.mem.copyForwards(?Item, spell_bag, loaded_spell_bag_unwrapped);
}
