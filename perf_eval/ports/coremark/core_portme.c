#include "coremark.h"
#include "core_portme.h"

extern volatile ee_u32 tohost;

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif

volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

static CORETIMETYPE start_time_val;
static CORETIMETYPE stop_time_val;
ee_u32 default_num_contexts = 1;

static inline CORETIMETYPE read_cycle32(void) {
    CORETIMETYPE value;
    __asm__ volatile("csrr %0, cycle" : "=r"(value));
    return value;
}

void start_time(void) {
    start_time_val = read_cycle32();
}

void stop_time(void) {
    stop_time_val = read_cycle32();
}

CORE_TICKS get_time(void) {
    return stop_time_val - start_time_val;
}

secs_ret time_in_secs(CORE_TICKS ticks) {
    return ticks / EE_TICKS_PER_SEC;
}

void portable_init(core_portable *p, int *argc, char *argv[]) {
    (void)argc;
    (void)argv;
    p->portable_id = 1;
}

void portable_fini(core_portable *p) {
    p->portable_id = 0;
    tohost = 1;
    while (1) {
    }
}

void *portable_malloc(ee_size_t size) {
    (void)size;
    return NULL;
}

void portable_free(void *p) {
    (void)p;
}
