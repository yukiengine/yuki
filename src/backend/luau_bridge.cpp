#include "backend/luau_bridge.h"

#include <cstdlib>

#include <lua.h>
#include <luacode.h>
#include <lualib.h>

extern "C" lua_State *yuki_luau_new_state(void) { return luaL_newstate(); }

extern "C" void yuki_luau_close(lua_State *state) { lua_close(state); }

extern "C" int yuki_luau_stack_top(lua_State *state) {
  return lua_gettop(state);
}

extern "C" int yuki_luau_compile(const char *source, size_t source_size,
                                 YukiLuauBytecode *out_bytecode) {
  if (!source || !out_bytecode)
    return YUKI_LUAU_COMPILE_FAILED;

  lua_CompileOptions options = {};
  options.optimizationLevel = 1;
  options.debugLevel = 1;
  options.typeInfoLevel = 0;
  options.coverageLevel = 0;

  size_t bytecode_size = 0;
  char *bytecode = luau_compile(source, source_size, &options, &bytecode_size);

  if (!bytecode)
    return YUKI_LUAU_COMPILE_FAILED;

  out_bytecode->data = bytecode;
  out_bytecode->size = bytecode_size;

  return YUKI_LUAU_OK;
}

extern "C" void yuki_luau_free_bytecode(YukiLuauBytecode bytecode) {
  std::free(bytecode.data);
}

extern "C" int yuki_luau_load_bytecode(lua_State *state, const char *chunk_name,
                                       const char *bytecode,
                                       size_t bytecode_size) {
  const int status = luau_load(state, chunk_name, bytecode, bytecode_size, 0);

  if (status != LUA_OK)
    return YUKI_LUAU_LOAD_FAILED;

  return YUKI_LUAU_OK;
}

extern "C" int yuki_luau_call(lua_State *state, int arg_count,
                              int result_count) {
  const int status = lua_pcall(state, arg_count, result_count, 0);

  if (status != LUA_OK)
    return YUKI_LUAU_RUNTIME_FAILED;

  return YUKI_LUAU_OK;
}

extern "C" int yuki_luau_is_table(lua_State *state, int index) {
  return lua_type(state, index) == LUA_TTABLE;
}

extern "C" int yuki_luau_ref(lua_State *state, int index) {
  return lua_ref(state, index);
}

extern "C" void yuki_luau_unref(lua_State *state, int ref) {
  lua_unref(state, ref);
}

extern "C" void yuki_luau_pop(lua_State *state, int count) {
  lua_settop(state, -count - 1);
}

extern "C" const char *yuki_luau_to_string(lua_State *state, int index) {
  return lua_tolstring(state, index, nullptr);
}

extern "C" void yuki_luau_get_ref(lua_State *state, int ref) {
  lua_getref(state, ref);
}

extern "C" int yuki_luau_get_field(lua_State *state, int index,
                                   const char *field_name) {
  return lua_getfield(state, index, field_name);
}

extern "C" int yuki_luau_is_nil(lua_State *state, int index) {
  return lua_isnil(state, index);
}

extern "C" int yuki_luau_is_function(lua_State *state, int index) {
  return lua_isfunction(state, index);
}

extern "C" void yuki_luau_push_nil(lua_State *state) { lua_pushnil(state); }

extern "C" void yuki_luau_push_number(lua_State *state, double value) {
  lua_pushnumber(state, value);
}
