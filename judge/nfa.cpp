#include <unordered_set>
#include "nfa.h"
using namespace std;

const char NFA::EPSILON='\0';

bool NFA::accepts(std::string_view s) const {
    unordered_set<int> states = {this->init_state}, states_new;

    while (states.size()!=0) {
        // epsilon przejście

        vector<int> states_v; states_v.reserve((states.size()));
        for (int state: states) states_v.push_back(state);

        for (unsigned int i=0; i<states_v.size(); ++i) {
            for (int state : this->states[states_v[i]].getTrans(EPSILON)) {
                if (states.find(state)==states.end()) {
                    states.insert(state);
                    states_v.push_back(state);
                }
            }
        }

        // zwykle przejscie
        
        if (s.length()==0) break;
        char c = s[0]; s.remove_prefix(1);
        states_new = decltype(states_new)();

        for (int state : states) {
            for (int state2 : this->states[state].getTrans(c)) {
                states_new.insert(state2);
            }
        }
        swap(states, states_new);
    }

    for (int state : states) {
        if (this->states[state].accepting) return true;
    }
    return false;
}
