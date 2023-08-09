
all: test

# export LUA_PATH = "${LUA_PATH};../civc/lua/?.lua"
LP = "${LUA_PATH};./lua/?.lua"

test:
	mkdir -p out/
	LUA_PATH=${LP} lua tests/test_gap.lua
	LUA_PATH=${LP} lua tests/test_motion.lua
	LUA_PATH=${LP} lua tests/test_buffer.lua
	LUA_PATH=${LP} lua tests/test_model.lua

run:
	LUA_PATH=${LP} lua lua/model.lua

