#include "task_base.h"
#include "timeout.h"


bool TaskBase::kindAcceptable(AutomatonBase const &automaton) {
    for (AutomatonKind kind : this->acceptableKinds) {
        if (kind == automaton.automatonKind()) {
            return true;
        }
        if (kind == AutomatonKind::ENFA) {
            if ((automaton.automatonKind() == AutomatonKind::DFA) || (automaton.automatonKind() == AutomatonKind::SNFA)) {
                return true;
            }
        }
        if (kind == AutomatonKind::SNFA) {
            if ((automaton.automatonKind() == AutomatonKind::DFA)) {
                return true;
            }
        }
    }
    return false;
}

Verdict TaskBase::verdict(AutomatonBase const &a) {
    try {
        if (this->test(a)) return Verdict::Accepted;
        else return Verdict::Rejected;
    } catch (TimeoutException const &) {
        return Verdict::Timeout;
    } catch (std::exception const &) {
        return Verdict::Other_error;
    }
}