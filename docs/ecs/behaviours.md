> [!WARNING]
> The docs are still under construction, they might be incomplete or out of date.

# Behaviours

> [docs](../README.md) / [ecs](./README.md) / behaviours

Behaviours are [Components](./components.md) with hooks to the eventloop. This allows them to handle engine events like `Awake`, `Start`, `Update`, `Tick`, and `End`.

You can define a behaviour type by adding a single public constant variable to it's decleration:

```zig
const myBehaviour = struct {
    pub const FYR_BEHAVIOUR = {};
};
```

By adding the `FYR_BEHAVIOUR` variable:

```zig
pub const FYR_BEHAVIOUR = {};
```

you can flag the type as a behaviour type. Now you can define the event handler functions, such as `Awake()`, `Start()`, etc.

## Event Handler Functions

> [!IMPORTANT]
> When defining an event handler function - such as `Update` - you must capitalise the first letter, this is so that we can differentiate event handlers from regular functions.

You can define five different event handlers:

### `Awake`

This runs once, when the object is loaded into the scene.

### `Start`

This runs once, after the `Awake` event has been handled.

### `Update`

Runs on every frame.

### `Tick`

Runs 20 times per second.

### `End`

Runs when the Enity is destroyed.
