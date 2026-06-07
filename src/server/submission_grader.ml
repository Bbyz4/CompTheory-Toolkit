type grade = {
  verdict : Domain.submission_verdict;
  run_data : Yojson.Basic.t;
}

let random_verdict () =
  match Random.int 4 with
  | 0 -> Domain.Accepted
  | 1 -> Domain.Rejected
  | 2 -> Domain.Invalid_format
  | _ -> Domain.Internal_error

let base_run_data ~worker ~submission_id ~strategy ~delay_seconds ~verdict
    ~judged_at extra_fields =
  `Assoc
    ([
       ("worker", `String worker);
       ("submission_id", `Int submission_id);
       ("strategy", `String strategy);
       ("delay_seconds", `Float delay_seconds);
       ("verdict", `String (Domain.submission_verdict_to_string verdict));
       ("judged_at", `String (Util.iso8601_of_unix_time judged_at));
     ]
    @ extra_fields)

let error_grade ~worker ~submission_id ~strategy ~delay_seconds ~verdict
    ~judged_at message =
  {
    verdict;
    run_data =
      base_run_data ~worker ~submission_id ~strategy ~delay_seconds ~verdict
        ~judged_at [ ("error", `String message) ];
  }

let mock_grade ~submission ~delay_seconds ~judged_at =
  let verdict = random_verdict () in
  {
    verdict;
    run_data =
      base_run_data ~worker:"mock-rabbitmq-http" ~submission_id:submission.Domain.id
        ~strategy:"random" ~delay_seconds ~verdict ~judged_at [];
  }

let explicit_test_json (word, accepted) =
  `Assoc [ ("word", `String word); ("accepted", `Bool accepted) ]

let explicit_tests_grade ~submission ~tests ~delay_seconds ~judged_at =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | word :: rest -> (
        match Nfa_acceptance.accepts_json submission.Domain.data ~word with
        | Ok accepted -> loop ((word, accepted) :: acc) rest
        | Error message -> Error message)
  in
  match loop [] tests with
  | Error message ->
      error_grade ~worker:"explicit-tests" ~submission_id:submission.id
        ~strategy:"nfa-acceptance" ~delay_seconds ~verdict:Domain.Invalid_format
        ~judged_at message
  | Ok results ->
      let verdict =
        if List.for_all (fun (_, accepted) -> accepted) results then
          Domain.Accepted
        else
          Domain.Rejected
      in
      {
        verdict;
        run_data =
          base_run_data ~worker:"explicit-tests" ~submission_id:submission.id
            ~strategy:"nfa-acceptance" ~delay_seconds ~verdict ~judged_at
            [ ("tests", `List (List.map explicit_test_json results)) ];
      }

let unsupported_explicit_tests_grade ~submission ~delay_seconds ~judged_at
    model_type =
  let message =
    Printf.sprintf "explicit-tests grading is not implemented for %s"
      (Domain.model_type_to_string model_type)
  in
  error_grade ~worker:"explicit-tests" ~submission_id:submission.Domain.id
    ~strategy:"unsupported-model-type" ~delay_seconds
    ~verdict:Domain.Internal_error ~judged_at message

let model_construction_grade ~config ~submission ~delay_seconds ~judged_at =
  match Task_config.model_construction_grader config with
  | Error message ->
      error_grade ~worker:"submission-grader" ~submission_id:submission.Domain.id
        ~strategy:"invalid-config" ~delay_seconds
        ~verdict:Domain.Internal_error ~judged_at message
  | Ok Task_config.Mock -> mock_grade ~submission ~delay_seconds ~judged_at
  | Ok (Task_config.Explicit_tests tests) -> (
      match Task_config.Model_construction.required_model_type config with
      | Some Domain.Nfa ->
          explicit_tests_grade ~submission ~tests ~delay_seconds ~judged_at
      | Some model_type ->
          unsupported_explicit_tests_grade ~submission ~delay_seconds ~judged_at
            model_type
      | None ->
          error_grade ~worker:"explicit-tests" ~submission_id:submission.id
            ~strategy:"invalid-config" ~delay_seconds
            ~verdict:Domain.Internal_error ~judged_at
            "config.requiredModelType is missing or unsupported")

let grade ~task ~submission ~delay_seconds ~judged_at =
  match Task_config.validate_task_config ~task_type:task.Domain.type_ task.config with
  | Error message ->
      error_grade ~worker:"submission-grader" ~submission_id:submission.Domain.id
        ~strategy:"invalid-config" ~delay_seconds
        ~verdict:Domain.Internal_error ~judged_at message
  | Ok config -> (
      match task.type_ with
      | Domain.Model_construction ->
          model_construction_grade ~config ~submission ~delay_seconds ~judged_at)

let missing_task_grade ~submission ~delay_seconds ~judged_at =
  error_grade ~worker:"submission-grader" ~submission_id:submission.Domain.id
    ~strategy:"load-task" ~delay_seconds ~verdict:Domain.Internal_error
    ~judged_at "Task not found for submission"
