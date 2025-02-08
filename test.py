import os

TEST_PATHS = ["main.zig", "libs/assets.zig", "libs/gui/export.zig"]

for path in TEST_PATHS:
    print(f"\nrunning test: {path}")
    os.system(f"zig test ./src/lib/{path} -l c")