#ifndef MOCK_TASK_H
#define MOCK_TASK_H

#include "task_base.h"

struct MockTask : TaskBase {
    virtual bool test(AutomatonBase const &);
};

#endif