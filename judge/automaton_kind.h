#ifndef AUTOMATON_KIND_H
#define AUTOMATON_KIND_H


enum class AutomatonKind : unsigned char {
    DFA = 1,
    SNFA = 3, // Simple NFA
    ENFA = 5,
    PDA = 2,
    CFG = 4,
    LBA = 6,
    TM = 8
}; // NFA nieparzyste (NVM nie ma znaczenia)



#endif