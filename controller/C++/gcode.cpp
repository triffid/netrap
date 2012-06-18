#include "gcode.hpp"

#include <cstdio>
#include <cstdlib>

uint32_t Gcode::parse(const char *line, int len, float words[32]) {
	uint32_t seen = 0;
	for (int i = 0; i < len; ) {
		char c = line[i];
		int n = 255;
		if (c >= 'a' && c <= 'z')
			c -= 'a' - 'A';
		if (c >= 'A' && c <= 'Z') {
			n = c - 'A';
		}
		else if (c == '*') {
			n = 26;
		}
		else if (c != ' ' || c != '\t' || c != '\r' || c != '\n') {
			// non-whitespace in gcode- bad line?
			printf("invalid gcode:\n\"%s\"\n", line);
			for (;i;i--) printf(" ");
			printf("^\n");
			return 0;
		}
		if (n < 32) {
			i++;
			char *ep = (char *) &line[i];;
			words[n] = strtof(ep, &ep);
			if (ep > &line[i]) {
				seen |= 1<<n;
				i += ep - &line[i];
			}
		}
	}
	return seen;
}
