#define _GNU_SOURCE
#include "affinity.h"
#include <sched.h>
//#include <cstdint>
#include <stdlib.h>

void* jl_get_affinity(int64_t pid)
{
    // Go through malloc - need to attach finalizer to the returned pointer to call `free`.
    void* ptr = malloc(sizeof(cpu_set_t));
    cpu_set_t* affinity = (cpu_set_t*)(ptr);

    // Get our affinity.
    sched_getaffinity(pid, sizeof(cpu_set_t), affinity);
    return ptr;
}

void jl_set_affinity(int64_t pid, int64_t cpu)
{
    cpu_set_t affinity;
    CPU_ZERO(&affinity);
    CPU_SET(cpu, &affinity);
    sched_setaffinity(pid, sizeof(cpu_set_t), &affinity);
}

void jl_reset_affinity(int64_t pid, void* cpu_set)
{
    sched_setaffinity(pid, sizeof(cpu_set_t), (cpu_set_t*) cpu_set);
}

void jl_free(void* ptr)
{
    free(ptr);
}
