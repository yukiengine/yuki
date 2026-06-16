#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lua_State lua_State;

/*
 * Small owned bytecode buffer returned by the Luau compiler.
 *
 * Luau allocates this buffer with malloc-compatible storage. Yuki owns it after
 * compilation and must release it with yuki_luau_free_bytecode.
 */
typedef struct YukiLuauBytecode {
  char *data;
  size_t size;
} YukiLuauBytecode;

/* Shared status codes returned by the C++ bridge. */
enum YukiLuauStatus {
  YUKI_LUAU_OK = 0,
  YUKI_LUAU_COMPILE_FAILED = 1,
  YUKI_LUAU_LOAD_FAILED = 2,
  YUKI_LUAU_RUNTIME_FAILED = 3,
};

/* Creates a fresh Luau VM state through Luau's C++ ABI. */
lua_State *yuki_luau_new_state(void);

/* Destroys a Luau VM state created by yuki_luau_new_state. */
void yuki_luau_close(lua_State *state);

/* Returns the current Luau stack height for smoke tests/debug checks. */
int yuki_luau_stack_top(lua_State *state);

/* Compiles Luau source text into bytecode that can be loaded by the VM. */
int yuki_luau_compile(const char *source, size_t source_size,
                      YukiLuauBytecode *out_bytecode);

/* Releases bytecode returned by yuki_luau_compile. */
void yuki_luau_free_bytecode(YukiLuauBytecode bytecode);

/* Loads compiled bytecode and leaves the loaded function on the stack. */
int yuki_luau_load_bytecode(lua_State *state, const char *chunk_name,
                            const char *bytecode, size_t bytecode_size);

/* Calls a function already present on the stack. */
int yuki_luau_call(lua_State *state, int arg_count, int result_count);

/* Returns true when the stack value at index is a table. */
int yuki_luau_is_table(lua_State *state, int index);

/* Stores a registry reference to the stack value at index. */
int yuki_luau_ref(lua_State *state, int index);

/* Releases a registry reference created by yuki_luau_ref. */
void yuki_luau_unref(lua_State *state, int ref);

/* Pops count values from the stack. */
void yuki_luau_pop(lua_State *state, int count);

/* Returns a stack value as a string when Luau can represent it that way. */
const char *yuki_luau_to_string(lua_State *state, int index);

/* Pushes a registry-referenced value onto the stack. */
void yuki_luau_get_ref(lua_State *state, int ref);

/* Pushes table[field_name] onto the stack and returns the Luau value type. */
int yuki_luau_get_field(lua_State *state, int index, const char *field_name);

/* Returns true when the stack value at index is nil. */
int yuki_luau_is_nil(lua_State *state, int index);

/* Returns true when the stack value at index is a function. */
int yuki_luau_is_function(lua_State *state, int index);

/* Pushes nil onto the stack for the temporary ctx placeholder. */
void yuki_luau_push_nil(lua_State *state);

/* Pushes a numeric value onto the stack. */
void yuki_luau_push_number(lua_State *state, double value);

/* Pushes a new table onto the stack. */
void yuki_luau_create_table(lua_State *state, int array_count,
                            int record_count);

/* Marks a table as readonly or writable. */
void yuki_luau_set_readonly(lua_State *state, int index, int enabled);

#ifdef __cplusplus
}
#endif
