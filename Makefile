
all: build

# export LUA_PATH = "${LUA_PATH};../civc/lua/?.lua"
LP = "${LUA_PATH};./lua/?.lua"

build:
	LUA_PATH=${LP} lua tests/test_gap.lua
	LUA_PATH=${LP} lua tests/test_shrm.lua

run:
	LUA_PATH=${LP} lua lua/shrm.lua
