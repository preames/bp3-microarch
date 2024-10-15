SOURCES=$(wildcard *.s)

OUTPUTS=$(addprefix bin/, $(SOURCES:.s=.out))

all: $(OUTPUTS)

bin/%.out : %.s driver/driver.c driver/driver.s
	${CC} -static -march=rv64gcv -O3 $^ -o $@
