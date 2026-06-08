#include "rand.h"
#include <cstdlib>
using namespace std;

static bool RAND_UNINITIALIZED=true;

int losuj() {
    if (RAND_UNINITIALIZED) {
        srand(2137);
        RAND_UNINITIALIZED = false;
    }
    return rand();
}