# **fyr-zig**

fyr is a custom **zig-based** wrapper of [Not-Nik](https://github.com/Not-Nik)'s [raylib-zig](https://github.com/Not-Nik/raylib-zig); containing an entity component system, asset loading, automatic rendering and many more features...

**NOTE: This project is still very much under development, take care when using! Contributions are welcome.**

<br>

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
