SOURCES=$(wildcard *.s)

OUTPUTS=$(addprefix bin/, $(SOURCES:.s=.out))

all: $(OUTPUTS)

bin/%.out : %.s
	${CC} -static -march=rv64gcv -O3 driver/driver.c driver/driver.s $< -o $@
