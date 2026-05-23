#include <verilated.h>
#include <cstdio>
#include <cstring>
#include <iostream>

#include "Vperf_core_tb.h"

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    vluint64_t max_time = 2000000;
    for (int i = 0; i < argc; i++) {
        if (std::sscanf(argv[i], "+cpp_timeout=%llu", &max_time) == 1) {
            std::cout << "C++ timeout set to " << max_time << "\n";
        }
    }

    Vperf_core_tb *tb = new Vperf_core_tb;
    tb->clk = 1;
    tb->rst_n = 0;

    for (int i = 0; i < 20; i++) {
        tb->clk = !tb->clk;
        tb->eval();
        Verilated::timeInc(1);
    }

    tb->rst_n = 1;

    while (!Verilated::gotFinish() && Verilated::time() <= max_time) {
        tb->clk = !tb->clk;
        tb->eval();
        Verilated::timeInc(1);
    }

    if (!Verilated::gotFinish()) {
        std::cerr << "C++ timeout at " << Verilated::time() << " ticks\n";
    }

    delete tb;
    return 0;
}
