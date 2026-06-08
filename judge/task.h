#ifndef TASK_H
#define TASK_H

#include <vector>
#include "automaton_kind.h"
#include "automaton_base.h"
#include "task_base.h"
#include <string>

struct Task : public TaskBase {
    std::vector<std::string> mustAccept;
    std::vector<std::string> mustReject;

    virtual bool test(AutomatonBase const &);
};

#endif