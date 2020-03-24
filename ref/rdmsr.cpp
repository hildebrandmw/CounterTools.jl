#include <iostream>

uint64_t get_cycles(){
    uint32_t a, d;
    int32_t ecx=(1 << 30) + 1; // This selects one of the fixed function counters
    __asm __volatile("rdmsr" : "=a"(a), "=d"(d) : "c"(ecx));
    return ((uint64_t) a) | (((uint64_t) d) << 32);
}

int main (int argc, char* argv[])
{
    uint64_t count = get_cycles();
    std::cout << "Count: " << count << std::endl;
    return 0;
}
