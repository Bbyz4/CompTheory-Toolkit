#ifndef VERDICT_H
#define VERDICT_H

enum class Verdict {
    Accepted=1,
    Rejected=2,
    Invalid_format=3,
    
    // Internal error
    Timeout=101,
    Other_error=100
};

#endif