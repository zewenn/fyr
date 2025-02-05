> [!WARNING]
> The docs are still under construction, they might be incomplete or out of date.

# The Entity Component System (ECS) of FYR

FYR uses a Unity-like entity component system with [Entities](./entities.md), [Components](./components.md), and [Behaviours](./behaviours.md).

## [Components](./components.md)

Components are the base building blocks of the ECS.
These are usually data structures that rarely handle game logic. This is your regular `Transform`, `Display`...
[Read more](./components.md)

## [Behvaiours](./behaviours.md)

Behaviours are Components with hooks into the eventloop. This means they can have `init()`, `update()`, `deinit()`, and other methods which are called by the eventloop...
[Read more](./behaviours.md)

## [Entities](./entities.md)

Entities are basically arrays of type-instance pairs. This means an entity can have more components of the same type (_khm_ just look at `Behaviour`s)...
[Read more](./entities.md)
