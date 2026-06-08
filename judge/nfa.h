#ifndef NFA_H
#define NFA_H

#include <string_view>
#include <vector>
#include <unordered_map>
#include "automaton_kind.h"
#include "automaton_base.h"

struct NFA_state {
    std::unordered_map<char, std::vector<int>> transitions;
    bool accepting=false;

    std::vector<int> const & getTrans(char c) const {
        static const std::vector<int> EMPTY_VECTOR = std::vector<int>();
        auto it = transitions.find(c);
        if (it==transitions.end()) return EMPTY_VECTOR;
        return it->second;
    }
};


struct NFA : public AutomatonBase {
    std::vector<NFA_state> states;
    std::vector<int> start_states;
    AutomatonKind kind;

    static const char EPSILON;

    virtual AutomatonKind automatonKind() const {return kind;}
    virtual bool accepts(std::string_view s) const;
};

#endif