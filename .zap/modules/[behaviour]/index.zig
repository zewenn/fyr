const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Callback = @import("../../main.zig").engine.types.Callback;
const CallbackSafe = @import("../../main.zig").engine.types.CallbackSafe;
const WrappedArray = @import("../[WrappedArray]/index.zig").WrappedArray;

awake: ?Callback,

init: ?Callback,
deinit: ?CallbackSafe,

update: ?Callback,
tick: ?Callback,

on: WrappedArray(Callback),
