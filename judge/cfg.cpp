#include "cfg.h"
#include "timeout.h"
using namespace std;

CFG_Production::CFG_Production (int from, std::vector<int> const &to) {
    this-> from = from;
    this -> to = to;
}

bool CFG::accepts(std::string_view s) const {
    if (this->cnf.has_value()) this->cnf = normalizeCFG(*this);
    if (this->cnf->gave_up) throw TimeoutException();

    return this->cnf->cyk(s, this->terminals);
};