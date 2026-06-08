#include "automaton_kind.h"

const std::unordered_map<std::string, AutomatonKind> automationKindMap = {
    {"DFA", AutomatonKind::DFA},
    {"SNFA", AutomatonKind::SNFA},
    {"ENFA", AutomatonKind::ENFA},
    {"NFA", AutomatonKind::ENFA},
    {"PDA", AutomatonKind::PDA},
    {"CFG", AutomatonKind::CFG},
    {"LBA", AutomatonKind::LBA},
    {"TM", AutomatonKind::TM}
};