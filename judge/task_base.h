#ifndef TASK_BASE_H
#define  TASK_BASE_H

#include "automaton_base.h"
#include "automaton_kind.h"
#include <vector>
#include "verdict.h"

struct TaskBase {
    std::vector<AutomatonKind> acceptableKinds;
    Verdict verdict(AutomatonBase const &);
    bool kindAcceptable(AutomatonBase const &);

    private:
    virtual bool test(AutomatonBase const &) = 0;
};

#endif