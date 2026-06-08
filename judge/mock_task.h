#ifndef MOCK_TASK_H
#define MOCK_TASK_H

#include "task_base.h"

struct MockTask : public TaskBase {
    virtual bool test(AutomatonBase const &);
};

#endif