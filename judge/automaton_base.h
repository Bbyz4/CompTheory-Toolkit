#ifndef AUTOMATON_BASE_H
#define AUTOMATON_BASE_H

#include "automaton_kind.h"
#include <string_view>
#include <exception>

struct AutomatonBase {
    virtual ~AutomatonBase() = default;

    virtual AutomatonKind automatonKind() const = 0;
    virtual bool accepts(std::string_view) const = 0; // throws TimeoutException
};

#endif