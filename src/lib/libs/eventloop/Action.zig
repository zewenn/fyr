on_fail: enum {
    ignore,
    remove,
    panic,
} = .ignore,
fn_ptr: *const fn () anyerror!void,
