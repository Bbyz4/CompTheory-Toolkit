#include "mock_task.h"
#include <cstdlib>
using namespace std;

#include "rand.h"

bool MockTask::test(AutomatonBase const &automaton) {
    if (!kindAcceptable(automaton)) return false;
    return losuj()%1;
}