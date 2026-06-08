#include "interface.h"
#include "rand.h"
#include <nlohmann/json.hpp>
#include "parse.h"
#include "verdict.h"
using namespace std;

extern "C" int judge_a_submission(char* task, char* submission) {
    // return losuj()%4;

    std::unique_ptr<TaskBase> task_obj;
    std::unique_ptr<AutomatonBase> automaton;

    try {
        task_obj = parse_task(task);
        if ((task_obj==nullptr)) return (int) Verdict::Invalid_format;
        automaton = parse_automaton(submission);
        if ((automaton==nullptr)) return (int) Verdict::Invalid_format;
    } catch (nlohmann::json::exception const &) {
        return (int) Verdict::Invalid_format;
    } catch (std::exception const &) {
        return (int) Verdict::Other_error;
    }

    return (int) task_obj->verdict(*automaton);
}