#ifndef CFG_H
#define CFG_H

#include "automaton_base.h"
#include <unordered_map>
#include <vector>
#include <optional>

struct CFG_Production {
    CFG_Production (int from, std::vector<int> const &to);
    std::vector<int> to;
    int from;
};

struct CNF {
    struct BinaryProd {
        int from, left, right; // order matters (auto-constructor)
        bool operator==(const BinaryProd &o) const {
            return from == o.from && left == o.left && right == o.right;
        }
    };
    struct UnaryProd {
        int from, to; // order matters (auto-constructor)
        bool operator==(const UnaryProd &o) const {
            return from == o.from && to == o.to;
        }
    };

    std::vector<BinaryProd> binary;
    // std::vector<UnaryProd> unary;
    int start = 0;
    bool accepts_empty = false;
    mutable bool gave_up = false;

    bool cyk(std::string_view, std::unordered_map<char, int> const &terminals) const;
};

struct CFG : AutomatonBase {
    int start;
    int next_id=1;
    std::unordered_map<char, int> terminals;
    std::vector<CFG_Production> productions;
    mutable std::optional<CNF> cnf;
     

    virtual AutomatonKind automatonKind() const {return AutomatonKind::CFG;};
    virtual bool accepts(std::string_view) const;
};

CNF normalizeCFG(CFG const &);

template<> struct std::hash<CNF::BinaryProd> {
    size_t operator()(const CNF::BinaryProd &p) const {
        size_t h = std::hash<int>{}(p.from);
        h ^= std::hash<int>{}(p.left)  + 0x9e3779b9 + (h << 6) + (h >> 2);
        h ^= std::hash<int>{}(p.right) + 0x9e3779b9 + (h << 6) + (h >> 2);
        return h;
    }
};

template<> struct std::hash<CNF::UnaryProd> {
    size_t operator()(const CNF::UnaryProd &p) const {
        size_t h = std::hash<int>{}(p.from);
        h ^= std::hash<int>{}(p.to) + 0x9e3779b9 + (h << 6) + (h >> 2);
        return h;
    }
};

#endif