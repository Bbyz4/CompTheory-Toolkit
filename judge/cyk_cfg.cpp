#include "cfg.h"
#include <unordered_set>
using namespace std;

bool CNF::cyk(string_view s, std::unordered_map<char, int> const &terminals) const {
    unsigned int n = s.length();
    if (n==0) return this->accepts_empty;

    using NTSet = std::unordered_set<int>;
    std::vector<std::vector<NTSet>> dp(n, std::vector<NTSet>(n + 1));

    for (unsigned int i = 0; i < n; ++i) {
        auto it = terminals.find(s[i]);
        if (it != terminals.end())
            dp[i][1].insert(it->second);
        else
            return false;
    }

    for (unsigned int l = 2; l <= n; ++l) {
        for (unsigned int i = 0; i + l <= n; ++i) {
            for (unsigned int k = 1; k < l; ++k) {
                // dp[i][k] * dp[i+k][l-k]
                const NTSet &left  = dp[i][k];
                const NTSet &right = dp[i + k][l - k];
                if (left.empty() || right.empty()) continue;
                for (auto &rule : this->binary) {
                    if (left.count(rule.left) && right.count(rule.right))
                        dp[i][l].insert(rule.from);
                }
            }
        }
    }

    return dp[0][n].count(this->start) > 0;
}