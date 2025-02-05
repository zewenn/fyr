> [!WARNING]
> The docs are still under construction, they might be incomplete or out of date.

# Behaviours

> [docs](../README.md) / [ecs](./README.md) / behaviours

Behaviours are [Components](./components.md) with hooks to the eventloop. This allows them to handle engine events like `awake`, `init`, `update`, `tick`, and `deinit`.

## Standard Behaviour Creation

If you want to use the modern, simple way to create Behaviours - _and your behaviour does not need arguments_ - use the `fyr.Behaviour.factory(comptime T: type)` function to map a type to the `fyr.Behaviour` interface.

```zig
pub const MovementBehaviour = fyr.Behaviour.factory(struct {
    const Self = @This();

    transform: ?*fyr.Transform = null,
    speed: f32 = 350,

    pub fn awake(Entity: *fyr.Entity, cache: *Self) !void {
        const transform = Entity.getComponent(fyr.Transform);
        cache.transform = transform;
    }

    pub fn update(Entity: *fyr.Entity, cache: *Self) !void {
        const transform = cache.transform orelse return;

        var move_vec = fyr.Vec3(0, 0, 0);

        if (fyr.rl.isKeyDown(.w)) {
            move_vec.y -= 1;
        }
        if (fyr.rl.isKeyDown(.s)) {
            move_vec.y += 1;
        }
        if (fyr.rl.isKeyDown(.a)) {
            move_vec.x -= 1;
        }
        if (fyr.rl.isKeyDown(.d)) {
            move_vec.x += 1;
        }

        move_vec = move_vec.normalize();

        transform.position = transform.position.add(
            move_vec.multiply(
                fyr.Vec3(cache.speed, cache.speed, 0),
            ).multiply(
                fyr.Vec3(
                    fyr.time.deltaTime(),
                    fyr.time.deltaTime(),
                    0,
                ),
            ),
        );

        if (move_vec.length() < 0.5) return;
        const animator = Entity.getComponent(fyr.Animator) orelse return;

        try animator.play("test");
    }
});
```

## Behaviours with an Argument

If you need to pass an argument to a Behaviour (e.i.: start position), you can use the `fyr.Behaviour.factoryAutoInferArgument()` function.
When a new Behaviour of your type is initalised the `T.create()` function will be called with one argument.

```zig
pub const Renderer = fyr.Behaviour.factoryAutoInferArgument(struct {
    const Self = @This();

    base: Display,
    display: ?*Display = null,
    transform: ?*Transform = null,
    display_cache: ?*DisplayCache = null,

    pub fn create(args: Display) Self {
        return Self{
            .base = args,
        };
    }

    pub fn awake(Entity: *fyr.Entity, cache: *Self) !void {
        try Entity.addComonent(cache.base);
        cache.display = Entity.getComponent(Display);

        cache.transform = Entity.getComponent(Transform);
        if (cache.transform == null) {
            try Entity.addComonent(Transform{});
            cache.transform = Entity.getComponent(Transform);
        }

        const c_transform = cache.transform.?;
        const c_display = cache.display.?;

        var display_cache = DisplayCache{
            .path = c_display.img,
            .transform = c_transform.*,
        };

        display_cache.img = try assets.get.image(
            display_cache.path,
            display_cache.transform.scale,
            display_cache.transform.rotation,
        );
        if (display_cache.img) |i| {
            display_cache.texture = try assets.get.texture(
                display_cache.path,
                i.*,
                c_transform.rotation,
            );
        }

        try Entity.addComonent(display_cache);
        cache.display_cache = Entity.getComponent(DisplayCache);
    }

    pub fn update(_: *fyr.Entity, cache: *Self) !void {
        const display_cache = cache.display_cache orelse return;
        const transform = cache.transform orelse return;
        const display = cache.display orelse return;

        const has_to_be_updated = Blk: {
            if (!transform.eqlSkipPosition(display_cache.transform)) break :Blk true;
            if (!std.mem.eql(u8, display.img, display_cache.path)) break :Blk true;
            break :Blk false;
        };

        if (has_to_be_updated) {
            display_cache.free();

            display_cache.* = DisplayCache{
                .path = display.img,
                .transform = transform.*,
            };
            display_cache.img = assets.get.image(
                display_cache.path,
                display_cache.transform.scale,
                display_cache.transform.rotation,
            ) catch {
                std.log.err("Image error!", .{});
                return;
            };

            if (display_cache.img) |i| {
                display_cache.texture = assets.get.texture(
                    display_cache.path,
                    i.*,
                    transform.rotation,
                ) catch {
                    std.log.err("Texture error!", .{});
                    return;
                };
            }
        }

        const texture = display_cache.texture orelse return;
        try fyr.display.add(.{
            .texture = texture.*,
            .transform = transform.*,
            .display = display.*,
        });
    }

    pub fn deinit(_: *fyr.Entity, cache: *Self) !void {
        const c_display_cache = cache.display_cache orelse return;

        c_display_cache.free();
    }
});
```
