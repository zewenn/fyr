<h1 align="center"><font style="font-size: 72pt;">FYR</font></h1>
<p align="center"><a href="./docs/">Docs</a> | <a href="./src/demo/">Demo Project</a></p>

> [!NOTE]
> This project uses zig version `0.14.0`.

**fyr** is a custom **zig-based** wrapper of [Not-Nik](https://github.com/Not-Nik)'s [raylib-zig](https://github.com/Not-Nik/raylib-zig); containing an entity component system, asset loading, automatic rendering and many more features...

> [!IMPORTANT]
> This project is still very much under development, take care when using! Contributions are welcome.

## Add the `fyr` library

You are only a couple of easy steps away fromm building your dream project:

1. Run the following command to save the dependency:
   ```bash
   zig fetch --save git+https://github.com/zewenn/fyr#stable
   ```
2. Add the following to your `build.zig`:

   ```zig
   const fyr_module = b.dependency("fyr", .{
       .target = target,
       .optimize = optimize,
   });

   const fyr = fyr_module.module("fyr");

   exe.root_module.addImport("fyr", fyr);
   ```

3. You are ready to go! Now you can import fyr with a regular zig `@import()`:
   ```zig
   const fyr = @import("fyr");
   ```

## Project Setup

Setting up a project with `fyr` is so easy, even your grandma could do it :smile:

> [!NOTE]
> You can follow the documentation, or take a look at the [demo project](./src/demo/main.zig)

```zig
// This handles the entire program, from start to finish
// All your code must be configured within these blocks
fyr.project({
    // This block will run before initalising the raylib window
    // Great place to configure default behaviours

    // Set the title of the window
    fyr.title("fyr-demo");
    // Resize to 720p
    fyr.winSize(fyr.Vec2(1280, 720));

    // Set the path of the debug assets dir
    fyr.useAssetDebugPath("./src/demo/assets/");
})({
    // This codeblock will run after the initalisation, but before the loop
    // Code here is used to configure scenes, entities, scripts and uis

    // Create the "default" scene, fyr will auto load the scene with this id
    fyr.scene("default")({
        // This block is used to configure the scene itself

        // Adding entities for example
        fyr.entities(.{
            try Player(),
            try Box(),
        });
    });
});
```
