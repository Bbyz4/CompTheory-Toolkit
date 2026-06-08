#include "parse.h"
#include <nlohmann/json.hpp>
#include <string>
#include "nfa.h"
#include "cfg.h"
#include <unordered_map>
using namespace std;

unique_ptr<NFA> parse_nfa(nlohmann::json &j) {
    auto nfa = make_unique<NFA>();
    unordered_map<string, int> id_map; int next_id=0;
    for (auto & el : j["model"]["states"]) {
        string state = el;
        if (id_map.find(state)!=id_map.end()) return nullptr;
        id_map[state] = next_id++;
        nfa->states.push_back(NFA_state());
    }

    for (auto &trans : j["model"]["transitions"]) {
        string from = trans["from"];
        string to = trans["to"];
        string symbol = trans["symbol"];
        if ((id_map.find(from)==id_map.end()) || (id_map.find(to)==id_map.end())) return nullptr;
        if (symbol.length()>1) return nullptr;
        if (symbol.length()==0) symbol = "\0";
        nfa->states[id_map[from]].transitions[symbol[0]].push_back(id_map[to]);
    }

    for (auto & el : j["model"]["startStates"]) {
        string state = el;
        if (id_map.find(state)==id_map.end()) return nullptr;
        nfa->start_states.push_back(id_map[state]);
    }
    for (auto & el : j["model"]["acceptStates"]) {
        string state = el;
        if (id_map.find(state)==id_map.end()) return nullptr;
        nfa->states[id_map[state]].accepting = true;
    }

    return nfa;
}

std::unique_ptr<CFG> parse_cfg(nlohmann::json &j) {
    return nullptr;
}

std::unique_ptr<AutomatonBase> parse_automaton(char* s) {
    unique_ptr<AutomatonBase> automaton = nullptr;
    auto j = nlohmann::json::parse(s);

    string modelType = j["type"];
    if (automationKindMap.find(modelType)==automationKindMap.end()) return nullptr;
    AutomatonKind kind = automationKindMap.at(modelType);

    if ((kind==AutomatonKind::ENFA) || (kind==AutomatonKind::DFA) || (kind==AutomatonKind::SNFA)) {
        automaton = std::move(parse_nfa(j));
    } else if (kind==AutomatonKind::CFG){
        automaton = std::move(parse_cfg(j));
    }

    return automaton;
}