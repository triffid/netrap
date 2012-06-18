#ifndef _GCODE_HPP
#define _GCODE_HPP

#include <cstdint>

class Gcode {
public:
	static uint32_t parse(const char *line, int len, float words[32]);
};

#endif /* _GCODE_HPP */
