#include "task.h"
#include <string_view>
using namespace std;


bool Task::test(AutomatonBase const &automaton) {
    if (!kindAcceptable(automaton)) return false;

    for (string& s : this->mustAccept) {
        if (!automaton.accepts(string_view(s))) return false;
    }

    for (string& s : this->mustReject) {
        if (automaton.accepts(string_view(s))) return false;
    }

    return true;
}