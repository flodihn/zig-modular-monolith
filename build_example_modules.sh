#zig build-lib -dynamic -O ReleaseFast src/example_module.zig -femit-bin=example_module.so
zig build-lib -dynamic src/example_module.zig -femit-bin=example_module.so
rm example_module.so.o

zig build-lib -dynamic src/example_module2.zig -femit-bin=example_module2.so
rm example_module2.so.o
