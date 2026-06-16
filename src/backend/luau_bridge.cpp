#include "backend/luau_bridge.h"

#include <lua.h>
#include <lualib.h>

extern "C" lua_State *yuki_luau_new_state(void) { return luaL_newstate(); }

extern "C" void yuki_luau_close(lua_State *state) { lua_close(state); }

extern "C" int yuki_luau_stack_top(lua_State *state) {
  return lua_gettop(state);
}
