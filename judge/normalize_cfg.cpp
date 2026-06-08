#include "cfg.h"
#include <unordered_set>
using namespace std;

using BinaryProd=CNF::BinaryProd;
using UnaryProd=CNF::UnaryProd;

template <typename T>
inline bool contains(std::unordered_set<T> st, T v) {
    return st.find(v)!=st.end();
}

CNF normalizeCFG(CFG const &g) {
    CNF cnf;

    std::vector<CFG_Production> prods = g.productions;
    int next_id = g.next_id;


    // nowy symbol startowy
    int s0 = next_id++;
    prods.push_back(CFG_Production(s0, vector<int>{g.start}));

    // binaryzacja produkcji
    std::unordered_set<int> nullable;
    std::vector<BinaryProd> binary;
    std::vector<UnaryProd> unary;
    for (auto &p : prods) {
        if (p.to.size() == 0) nullable.insert(p.from);
        
        int cur_lhs = p.from;
        for (size_t i = 0; i + 2 < p.to.size(); ++i) {
            int right_lhs = next_id++;
            binary.push_back(BinaryProd{cur_lhs, p.to[i], right_lhs});
            cur_lhs = right_lhs;
        }
        binary.push_back(BinaryProd{cur_lhs, p.to[p.to.size()-2], p.to[p.to.size()-1]});
    }

    // wywalanie epsilon produkcji
    while (1) {
        // Możliwa optymalizacja: żeby się wiele razy nie iterować po już znullowanych
        bool changed = false;
        for (auto &p : binary) {
            if (nullable.count(p.from)) continue;
            if (nullable.count(p.left) && nullable.count(p.right)) { nullable.insert(p.from); changed = true; }
        }
        for (auto &p : unary) {
            if (nullable.count(p.from)) continue;
            if (nullable.count(p.to)) { nullable.insert(p.from); changed = true; }
        }
        if (!changed) break;
    }
    for (auto &p : binary) {
        if (nullable.count(p.left)) unary.push_back(UnaryProd{p.from, p.right});
        if (nullable.count(p.right)) unary.push_back(UnaryProd{p.from, p.left});
    }
    
    // deduplikacja
    {
        unordered_set<BinaryProd> binary_set(binary.begin(), binary.end());
        unordered_set<UnaryProd> unary_set(unary.begin(), unary.end());
        binary = vector<BinaryProd>(binary_set.begin(), binary_set.end());
        unary = vector<UnaryProd>(unary_set.begin(), unary_set.end());
    }

    // redukcja produkcji unarnych
    {
        std::unordered_map<int,std::unordered_set<int>> unit_closure;
        // Collect all non-terminal ids
        std::unordered_set<int> all_nt;
        for (auto &p : binary) {
            all_nt.insert(p.from);
            all_nt.insert(p.left);
            all_nt.insert(p.right);
        }
        for (auto &p : unary) {
            all_nt.insert(p.from);
            all_nt.insert(p.to);
        }
        for (int A : all_nt) unit_closure[A].insert(A);


        while (1) { // TODO: to az sie prosi o strukture grafowa
            bool changed = false;
            for (auto &p : unary) {
                for (int C : unit_closure[p.to]) {
                    if (unit_closure[p.from].insert(C).second) changed = true;
                }
            }
            if (!changed) break;
        }

        std::vector<BinaryProd> new_binary;
        for (auto &p : binary) {
            for (int A : all_nt) {
                if (unit_closure[A].count(p.from)) {
                    new_binary.push_back(BinaryProd{A, p.left, p.right});
                }
            }
        }
        binary = std::move(new_binary);
    }
    unary.clear();

    // deduplikacja raz jeszcze
    {
        unordered_set<BinaryProd> binary_set(binary.begin(), binary.end());
        binary = vector<BinaryProd>(binary_set.begin(), binary_set.end());
    }


    // TODO: eliminacja symboli nieużytecznych (nie wpływa na poprawność)    

    cnf.start = s0;
    cnf.binary = std::move(binary);
    cnf.accepts_empty = (bool)(nullable.count(s0));
    return cnf;
}