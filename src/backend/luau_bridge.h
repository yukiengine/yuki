#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lua_State lua_State;

/* Creates a fresh Luau VM state through Luau's C++ ABI. */
lua_State *yuki_luau_new_state(void);

/* Destroys a Luau VM state created by yuki_luau_new_state. */
void yuki_luau_close(lua_State *state);

/* Returns the current Luau stack height for smoke tests/debug checks. */
int yuki_luau_stack_top(lua_State *state);

#ifdef __cplusplus
}
#endif
