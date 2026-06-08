#ifndef TIMEOUT_H
#define TIMEOUT_H
#include <exception>

// extern bool TIMEOUT;

class TimeoutException : std::exception {}; // jak nie idzie policzyć, czyli timeout

#endif