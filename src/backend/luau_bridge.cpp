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

extern "C" void yuki_luau_create_table(lua_State *state, int array_count,
                                       int record_count) {
  lua_createtable(state, array_count, record_count);
}

extern "C" void yuki_luau_set_readonly(lua_State *state, int index,
                                       int enabled) {
  lua_setreadonly(state, index, enabled);
}

extern "C" int yuki_luau_raise_error(lua_State *state, const char *message) {
  lua_pushstring(state, message ? message : "Luau runtime error");
  lua_error(state);
  return 0;
}

extern "C" int yuki_luau_read_string(lua_State *state, int index,
                                     const char **out_data, size_t *out_size) {
  if (!out_data || !out_size)
    return 0;

  if (lua_type(state, index) != LUA_TSTRING)
    return 0;

  size_t size = 0;
  const char *data = lua_tolstring(state, index, &size);

  if (!data)
    return 0;

  *out_data = data;
  *out_size = size;
  return 1;
}

extern "C" void yuki_luau_push_string(lua_State *state, const char *data,
                                      size_t size) {
  lua_pushlstring(state, data, size);
}

extern "C" void yuki_luau_push_boolean(lua_State *state, int value) {
  lua_pushboolean(state, value);
}

extern "C" void yuki_luau_push_light_userdata(lua_State *state, void *data) {
  lua_pushlightuserdata(state, data);
}

extern "C" void *yuki_luau_to_light_userdata_upvalue(lua_State *state,
                                                     int upvalue_index) {
  return lua_touserdata(state, lua_upvalueindex(upvalue_index));
}

extern "C" void yuki_luau_push_c_closure(lua_State *state,
                                         YukiLuauCFunction function,
                                         const char *debug_name,
                                         int upvalue_count) {
  lua_pushcclosure(state, (lua_CFunction)function, debug_name, upvalue_count);
}

extern "C" void yuki_luau_set_field(lua_State *state, int table_index,
                                    const char *field_name) {
  lua_setfield(state, table_index, field_name);
}

extern "C" void *yuki_luau_new_userdata(lua_State *state, size_t size) {
  return lua_newuserdata(state, size);
}

extern "C" void *yuki_luau_to_userdata(lua_State *state, int index) {
  return lua_touserdata(state, index);
}

extern "C" void yuki_luau_set_metatable(lua_State *state, int index) {
  lua_setmetatable(state, index);
}

extern "C" void yuki_luau_push_value(lua_State *state, int index) {
  lua_pushvalue(state, index);
}

struct YukiBridgeVector2 {
  double x;
  double y;
};

static int yuki_luau_raise(lua_State *state, const char *message) {
  lua_pushstring(state, message);
  lua_error(state);
  return 0;
}

static bool yuki_luau_read_number(lua_State *state, int index, double *out) {
  int is_number = 0;
  const double value = lua_tonumberx(state, index, &is_number);

  if (!is_number)
    return false;

  *out = value;
  return true;
}

static bool yuki_luau_read_vector2(lua_State *state, int index,
                                   YukiBridgeVector2 *out) {
  const int table_index = lua_absindex(state, index);

  if (!lua_istable(state, table_index))
    return false;

  double x = 0.0;
  double y = 0.0;

  lua_getfield(state, table_index, "x");
  const bool has_x = yuki_luau_read_number(state, -1, &x);
  lua_pop(state, 1);

  lua_getfield(state, table_index, "y");
  const bool has_y = yuki_luau_read_number(state, -1, &y);
  lua_pop(state, 1);

  if (!has_x || !has_y)
    return false;

  out->x = x;
  out->y = y;
  return true;
}

extern "C" int yuki_luau_read_vector2_value(lua_State *state, int index,
                                            YukiLuauVector2 *out) {
  if (!out)
    return 0;

  YukiBridgeVector2 value = {};

  if (!yuki_luau_read_vector2(state, index, &value))
    return 0;

  out->x = value.x;
  out->y = value.y;
  return 1;
}

static void yuki_luau_set_number_field(lua_State *state, int table_index,
                                       const char *name, double value) {
  lua_pushnumber(state, value);
  lua_setfield(state, table_index, name);
}

static void yuki_luau_set_function_field(lua_State *state, int table_index,
                                         const char *name, lua_CFunction fn,
                                         const char *debug_name) {
  lua_pushcfunction(state, fn, debug_name);
  lua_setfield(state, table_index, name);
}

static int yuki_vector2_new(lua_State *state);
static int yuki_vector2_add(lua_State *state);
static int yuki_vector2_sub(lua_State *state);
static int yuki_vector2_mul(lua_State *state);
static int yuki_vector2_div(lua_State *state);
static int yuki_vector2_unm(lua_State *state);
static int yuki_vector2_eq(lua_State *state);

static void yuki_luau_push_vector2_metatable(lua_State *state) {
  lua_createtable(state, 0, 8);

  const int metatable_index = lua_absindex(state, -1);

  lua_pushvalue(state, metatable_index);
  lua_setfield(state, metatable_index, "__index");

  yuki_luau_set_function_field(state, metatable_index, "__add",
                               yuki_vector2_add, "Vector2.__add");
  yuki_luau_set_function_field(state, metatable_index, "__sub",
                               yuki_vector2_sub, "Vector2.__sub");
  yuki_luau_set_function_field(state, metatable_index, "__mul",
                               yuki_vector2_mul, "Vector2.__mul");
  yuki_luau_set_function_field(state, metatable_index, "__div",
                               yuki_vector2_div, "Vector2.__div");
  yuki_luau_set_function_field(state, metatable_index, "__unm",
                               yuki_vector2_unm, "Vector2.__unm");
  yuki_luau_set_function_field(state, metatable_index, "__eq", yuki_vector2_eq,
                               "Vector2.__eq");

  lua_setreadonly(state, metatable_index, 1);
}

static void yuki_luau_push_vector2(lua_State *state, double x, double y) {
  lua_createtable(state, 0, 2);

  const int vector_index = lua_absindex(state, -1);

  yuki_luau_set_number_field(state, vector_index, "x", x);
  yuki_luau_set_number_field(state, vector_index, "y", y);

  yuki_luau_push_vector2_metatable(state);
  lua_setmetatable(state, vector_index);

  lua_setreadonly(state, vector_index, 1);
}

static int yuki_vector2_new(lua_State *state) {
  double x = 0.0;
  double y = 0.0;

  if (!yuki_luau_read_number(state, 1, &x))
    return yuki_luau_raise(state, "Vector2.new expected number x");

  if (!yuki_luau_read_number(state, 2, &y))
    return yuki_luau_raise(state, "Vector2.new expected number y");

  yuki_luau_push_vector2(state, x, y);
  return 1;
}

static int yuki_vector2_add(lua_State *state) {
  YukiBridgeVector2 left = {};
  YukiBridgeVector2 right = {};

  if (!yuki_luau_read_vector2(state, 1, &left) ||
      !yuki_luau_read_vector2(state, 2, &right))
    return yuki_luau_raise(state,
                           "Vector2 addition expects two Vector2 values");

  yuki_luau_push_vector2(state, left.x + right.x, left.y + right.y);
  return 1;
}

static int yuki_vector2_sub(lua_State *state) {
  YukiBridgeVector2 left = {};
  YukiBridgeVector2 right = {};

  if (!yuki_luau_read_vector2(state, 1, &left) ||
      !yuki_luau_read_vector2(state, 2, &right))
    return yuki_luau_raise(state,
                           "Vector2 subtraction expects two Vector2 values");

  yuki_luau_push_vector2(state, left.x - right.x, left.y - right.y);
  return 1;
}

static int yuki_vector2_mul(lua_State *state) {
  YukiBridgeVector2 vector = {};
  double scalar = 0.0;

  if (yuki_luau_read_vector2(state, 1, &vector) &&
      yuki_luau_read_number(state, 2, &scalar)) {
    yuki_luau_push_vector2(state, vector.x * scalar, vector.y * scalar);
    return 1;
  }

  if (yuki_luau_read_number(state, 1, &scalar) &&
      yuki_luau_read_vector2(state, 2, &vector)) {
    yuki_luau_push_vector2(state, vector.x * scalar, vector.y * scalar);
    return 1;
  }

  return yuki_luau_raise(state,
                         "Vector2 multiplication expects Vector2 and number");
}

static int yuki_vector2_div(lua_State *state) {
  YukiBridgeVector2 vector = {};
  double scalar = 0.0;

  if (!yuki_luau_read_vector2(state, 1, &vector) ||
      !yuki_luau_read_number(state, 2, &scalar))
    return yuki_luau_raise(state,
                           "Vector2 division expects Vector2 and number");

  if (scalar == 0.0)
    return yuki_luau_raise(state, "Vector2 division by zero");

  yuki_luau_push_vector2(state, vector.x / scalar, vector.y / scalar);
  return 1;
}

static int yuki_vector2_unm(lua_State *state) {
  YukiBridgeVector2 vector = {};

  if (!yuki_luau_read_vector2(state, 1, &vector))
    return yuki_luau_raise(state, "Vector2 negation expects Vector2");

  yuki_luau_push_vector2(state, -vector.x, -vector.y);
  return 1;
}

static int yuki_vector2_eq(lua_State *state) {
  YukiBridgeVector2 left = {};
  YukiBridgeVector2 right = {};

  if (!yuki_luau_read_vector2(state, 1, &left) ||
      !yuki_luau_read_vector2(state, 2, &right)) {
    lua_pushboolean(state, 0);
    return 1;
  }

  lua_pushboolean(state, left.x == right.x && left.y == right.y);
  return 1;
}

extern "C" void yuki_luau_install_vector2(lua_State *state) {
  lua_createtable(state, 0, 5);

  const int api_index = lua_absindex(state, -1);

  yuki_luau_set_function_field(state, api_index, "new", yuki_vector2_new,
                               "Vector2.new");

  yuki_luau_push_vector2(state, 0.0, 0.0);
  lua_setfield(state, api_index, "zero");

  yuki_luau_push_vector2(state, 1.0, 1.0);
  lua_setfield(state, api_index, "one");

  yuki_luau_push_vector2(state, 1.0, 0.0);
  lua_setfield(state, api_index, "right");

  yuki_luau_push_vector2(state, 0.0, 1.0);
  lua_setfield(state, api_index, "up");

  lua_setreadonly(state, api_index, 1);
  lua_setglobal(state, "Vector2");
}

extern "C" void yuki_luau_push_vector2_value(lua_State *state, double x,
                                             double y) {
  yuki_luau_push_vector2(state, x, y);
}
