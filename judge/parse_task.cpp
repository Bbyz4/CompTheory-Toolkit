#include "parse.h"
#include "mock_task.h"
#include "task.h"
#include <cstring>
#include <nlohmann/json.hpp>
#include <string>
#include "automaton_kind.h"
#include <unordered_map>
using namespace std;

std::unique_ptr<MockTask> parse_mock(nlohmann::json &j) {
    auto task = make_unique<MockTask>();
    return task;
}

unique_ptr<Task> parse_test_task(nlohmann::json &j) {
    auto task = make_unique<Task>();
    for (string const &s : j["grader"]["mustAccept"]) task->mustAccept.push_back(s);
    for (string const &s : j["grader"]["mustReject"]) task->mustReject.push_back(s);
    return task;
}

std::unique_ptr<TaskBase> parse_task(char* s) {
    unique_ptr<TaskBase> task = nullptr;
    auto j = nlohmann::json::parse(s);

    std::string kind = j["grader"]["kind"];
    string modelType = j["requiredModelType"];
    if (automationKindMap.find(modelType)==automationKindMap.end()) return nullptr;
    AutomatonKind automatonKind = automationKindMap.at(modelType);

    if (kind=="mock") {
        task = std::move(parse_mock(j));
    } else if (kind=="tests") {
        task = std::move(parse_test_task(j));
    } else return nullptr;

    task->acceptableKinds = vector<AutomatonKind>{automatonKind};
    return task;
}