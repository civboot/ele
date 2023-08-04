
all: test

# export LUA_PATH = "${LUA_PATH};../civc/lua/?.lua"
LP = "${LUA_PATH};./lua/?.lua"

test:
	mkdir -p out/
	LUA_PATH=${LP} lua tests/test_gap.lua
	LUA_PATH=${LP} lua tests/test_lede.lua

run:
	LUA_PATH=${LP} lua lua/lede.lua

