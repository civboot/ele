
all: test

LP = "./?.lua;../civlib/?.lua;${LUA_PATH}"

test:
	mkdir -p out/
	LUA_PATH=${LP} lua tests/test_gap.lua
	LUA_PATH=${LP} lua tests/test_motion.lua
	LUA_PATH=${LP} lua tests/test_buffer.lua
	LUA_PATH=${LP} lua tests/test_model.lua

run:
	LUA_PATH=${LP} lua lua/model.lua

installlocal:
	luarocks make rockspec --local

uploadrock:
	source ~/.secrets && luarocks upload rockspec --api-key=${ROCKAPI}
