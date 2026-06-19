CC		:= gcc
CFLAGS		:= -Wall -Wextra -Wpedantic -Wno-unused-parameter -Werror -std=c11 -g -fsanitize=address,undefined

function_pointers: main.c
	$(CC) $(CFLAGS) -o $@ $^

.PHONY: clean
clean:
	rm -f function_pointers
