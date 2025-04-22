> [!WARNING]
> The docs are still under construction, they might be incomplete or out of date.

# Components

> [docs](../README.md) / [ecs](./README.md) / components

Anything can be a component. Components store simple data on entities and can be accessed by [behaviours](./behaviours.md) and other entities.

Example:

```zig
...

const MyComponent = struct {
    x: usize = 0,
};

...

myEntity.addComponent(MyComponent{});

...

```

Components can be accessed via the `getComponent` and `getComponents` methods.

```zig
// Note: we use the type for the query.
const componentRef = myEntity.getComponent(MyComponent);
```

You can also add components when initalising the entity:

```zig
const fyr = @import(fyr);

pub fn MyEntity() !*fyr.Entity {
    return try fyr.entity("MyEntity", .{
        MyComponent{},
    });
}
```
