#ifndef PARSE_H
#define PARSE_H

#include "task_base.h"
#include "automaton_base.h"
#include <string>
#include <memory>

std::unique_ptr<TaskBase> parse_task(char*);
std::unique_ptr<AutomatonBase> parse_automaton(char*);

#endif