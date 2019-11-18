#include <stdlib.h>

#ifndef JL_AFFINITY
#define JL_AFFINITY

void* jl_get_affinity(int64_t pid);

void jl_set_affinity(int64_t pid, int64_t cpu);
void jl_reset_affinity(int64_t pid, void* cpu_set);

void jl_free(void* ptr);

#endif
