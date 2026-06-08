#include <bits/stdc++.h>
#include <string>
#include "parse.h"
#include "nfa.h"
#include "task.h"
using namespace std;

// test
/*int main() {
    char s[1000];
    scanf("%s", &s);
    NFA nfa;
    unique_ptr<TaskBase> t = parse_task(s);
    cout << (int) t->verdict(nfa);
    return 0;
}*/

int main() {
    char s[1000];
    scanf("%s", &s);
    unique_ptr<AutomatonBase> nfa = parse_automaton(s);
    string t[] = {"a", "ab", "b", "aaab", "ba"};

    for (string ss : t) {
        cout << ss << " " << nfa->accepts(ss);
    }

    return 0;
}