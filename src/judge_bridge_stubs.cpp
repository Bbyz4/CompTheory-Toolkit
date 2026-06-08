#include <exception>
#include <string_view>

#include <caml/memory.h>
#include <caml/mlvalues.h>

#include "nfa.cpp"

namespace {

bool int_in_range(value value, int upper_bound) {
    int index = Int_val(value);
    return index >= 0 && index < upper_bound;
}

bool add_accept_states(NFA& nfa, value accept_states, int state_count) {
    mlsize_t count = Wosize_val(accept_states);
    for (mlsize_t i = 0; i < count; ++i) {
        value state_value = Field(accept_states, i);
        if (!int_in_range(state_value, state_count)) {
            return false;
        }
        nfa.states[Int_val(state_value)].accepting = true;
    }
    return true;
}

bool add_start_state_edges(NFA& nfa, value start_states, int state_count) {
    mlsize_t count = Wosize_val(start_states);
    if (count == 0) {
        return false;
    }

    for (mlsize_t i = 0; i < count; ++i) {
        value state_value = Field(start_states, i);
        if (!int_in_range(state_value, state_count)) {
            return false;
        }
        nfa.states[nfa.init_state]
            .transitions[NFA::EPSILON]
            .push_back(Int_val(state_value));
    }
    return true;
}

bool add_transition(NFA& nfa, value transition, int state_count) {
    value from_value = Field(transition, 0);
    value to_value = Field(transition, 1);
    value symbol_option = Field(transition, 2);

    if (!int_in_range(from_value, state_count) ||
        !int_in_range(to_value, state_count)) {
        return false;
    }

    char symbol = NFA::EPSILON;
    if (!Is_long(symbol_option)) {
        value symbol_value = Field(symbol_option, 0);
        if (caml_string_length(symbol_value) != 1) {
            return false;
        }
        symbol = String_val(symbol_value)[0];
    }

    nfa.states[Int_val(from_value)]
        .transitions[symbol]
        .push_back(Int_val(to_value));
    return true;
}

bool add_transitions(NFA& nfa, value transitions, int state_count) {
    mlsize_t count = Wosize_val(transitions);
    for (mlsize_t i = 0; i < count; ++i) {
        if (!add_transition(nfa, Field(transitions, i), state_count)) {
            return false;
        }
    }
    return true;
}

int judge_nfa_explicit(value state_count_value, value start_states,
                       value accept_states, value transitions, value tests) {
    int state_count = Int_val(state_count_value);
    if (state_count <= 0) {
        return -2;
    }

    NFA nfa;
    nfa.states.resize(static_cast<size_t>(state_count + 1));
    nfa.init_state = state_count;
    nfa.kind = AutomatonKind::ENFA;

    if (!add_start_state_edges(nfa, start_states, state_count) ||
        !add_accept_states(nfa, accept_states, state_count) ||
        !add_transitions(nfa, transitions, state_count)) {
        return -2;
    }

    mlsize_t test_count = Wosize_val(tests);
    for (mlsize_t i = 0; i < test_count; ++i) {
        value test_value = Field(tests, i);
        std::string_view word(String_val(test_value),
                              caml_string_length(test_value));
        if (!nfa.accepts(word)) {
            return static_cast<int>(i);
        }
    }

    return -1;
}

}  // namespace

extern "C" value recognita_judge_nfa_explicit(value state_count,
                                               value start_states,
                                               value accept_states,
                                               value transitions,
                                               value tests) {
    CAMLparam5(state_count, start_states, accept_states, transitions, tests);
    int result = -3;
    try {
        result = judge_nfa_explicit(state_count, start_states, accept_states,
                                    transitions, tests);
    } catch (std::exception const&) {
        result = -3;
    } catch (...) {
        result = -3;
    }
    CAMLreturn(Val_int(result));
}
