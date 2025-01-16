<img src="./readme/logo_large.png" width="200" align="left" style="margin-right: 25px">

### **zap**

zap is a custom **zig-based** wrapper of [Not-Nik](https://github.com/Not-Nik)'s [raylib-zig](https://github.com/Not-Nik/raylib-zig); containing an entity component system, asset loading, automatic rendering and many more features...

**NOTE: This project is still very much under development, take care when using! Contributions are welcome.**

<br>

## Add the `zap` library

You are only a couple of easy steps away fromm building your dream project:

1. Run the following command to save the dependency:
   ```bash
   zig fetch --save git+https://github.com/zewenn/zap
   ```
2. Add the following to your `build.zig`:

   ```zig
   const zap_module = b.dependency("zap", .{
       .target = target,
       .optimize = optimize,
   });

   const zap = zap_module.module("zap");

   exe.root_module.addImport("zap", zap);
   ```

3. You are ready to go! Now you can import zap with a regular zig `@import()`:
   ```zig
   const zap = @import("zap");
   ```
