#include <stdio.h>

typedef long uint64_t;

void read_counters(uint64_t* cycles, uint64_t* instrs);

void measure(char*);

#define N 20000

int main() {

  char A[256*1024];
  // Warm up caches
  for (int i = 0; i < 10; i++)
    measure(A);

  uint64_t cycles_begin = 0, instrs_begin = 0;
  read_counters(&cycles_begin, &instrs_begin);
  printf("%ld cycles, %ld instret (before)\n", cycles_begin, instrs_begin);

  for (int i = 0; i < N; i++)
    measure(A);

  uint64_t cycles_end = 0, instrs_end = 0;
  read_counters(&cycles_end, &instrs_end);
  printf("%ld cycles, %ld instret (after)\n", cycles_end, instrs_end);

  printf("%ld cycles, %ld instret elapsed\n", cycles_end-cycles_begin, instrs_end-instrs_begin);
  printf("  ~%f cycles-per-inst\n", (double)(cycles_end-cycles_begin)/(double)(instrs_end-instrs_begin));
  printf("  ~%f cycles-per-iteration\n", (double)(cycles_end-cycles_begin)/N);
  printf("  ~%f insts-per-iteration\n", (double)(instrs_end-instrs_begin)/N);

  return 0;
}
