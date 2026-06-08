open Yojson.Basic.Util

let ( let* ) = Lwt.bind

type deps = {
  repo : Repository.t;
  queue : Submission_queue.t;
  clock : Clock.t;
  judging_delay_seconds : unit -> float;
}

let ok value = Lwt.return (Ok value)

let error value = Lwt.return (Error value)

let map_repo_error = function
  | Repository.Conflict message -> message
  | Repository.Not_found message -> message
  | Repository.Storage message -> message

let random_verdict () =
  match Random.int 4 with
  | 0 -> Domain.Accepted
  | 1 -> Domain.Rejected
  | 2 -> Domain.Invalid_format
  | _ -> Domain.Internal_error

let run_data_base ~strategy ~submission_id ~delay_seconds ~verdict ~judged_at
    extra_fields =
  `Assoc
    ([
       ("worker", `String "rabbitmq-http");
       ("submission_id", `Int submission_id);
       ("strategy", `String strategy);
       ("delay_seconds", `Float delay_seconds);
       ("verdict", `String (Domain.submission_verdict_to_string verdict));
       ("judged_at", `String (Util.iso8601_of_unix_time judged_at));
     ]
    @ extra_fields)

let mock_run_data submission_id verdict delay_seconds judged_at =
  run_data_base ~strategy:"random" ~submission_id ~delay_seconds ~verdict
    ~judged_at []

let explicit_tests config =
  match config |> member "grader" |> member "tests" with
  | `List values ->
      List.map
        (function
          | `String value -> value
          | _ -> failwith "explicit-tests config contains a non-string test")
        values
  | _ -> []

let explicit_run_data (submission : Domain.submission) (task : Domain.task) tests
    delay_seconds judged_at bridge_result verdict =
  let result_fields =
    match bridge_result with
    | Judge_bridge.Accepted -> [ ("result", `String "accepted") ]
    | Judge_bridge.Rejected { index; word } ->
        [
          ("result", `String "rejected");
          ("failed_test_index", `Int index);
          ("failed_test", `String word);
        ]
    | Judge_bridge.Invalid_format message ->
        [
          ("result", `String "invalid_format");
          ("message", `String message);
        ]
    | Judge_bridge.Internal_error message ->
        [
          ("result", `String "internal_error");
          ("message", `String message);
        ]
  in
  run_data_base ~strategy:"explicit-tests-nfa" ~submission_id:submission.Domain.id
    ~delay_seconds ~verdict ~judged_at
    ([
       ("task_id", `Int task.Domain.id);
       ("test_count", `Int (List.length tests));
     ]
    @ result_fields)

let internal_run_data (submission : Domain.submission) delay_seconds judged_at
    message =
  run_data_base ~strategy:"internal-error" ~submission_id:submission.Domain.id
    ~delay_seconds ~verdict:Domain.Internal_error ~judged_at
    [ ("message", `String message) ]

let grade_explicit_tests (submission : Domain.submission) (task : Domain.task)
    config delay_seconds judged_at =
  let tests = explicit_tests config in
  let bridge_result =
    Judge_bridge.judge_nfa_explicit_tests ~submission_data:submission.Domain.data
      ~tests
  in
  let verdict =
    match bridge_result with
    | Judge_bridge.Accepted -> Domain.Accepted
    | Judge_bridge.Rejected _ -> Domain.Rejected
    | Judge_bridge.Invalid_format _ -> Domain.Invalid_format
    | Judge_bridge.Internal_error _ -> Domain.Internal_error
  in
  let run_data =
    explicit_run_data submission task tests delay_seconds judged_at bridge_result
      verdict
  in
  (verdict, run_data)

let grade_submission (submission : Domain.submission) (task : Domain.task) config
    delay_seconds judged_at =
  match config |> member "grader" |> member "kind" with
  | `String "explicit-tests" ->
      grade_explicit_tests submission task config delay_seconds judged_at
  | _ ->
      let verdict = random_verdict () in
      (verdict, mock_run_data submission.Domain.id verdict delay_seconds judged_at)

let sample_poisson_seconds ~mean =
  if mean <= 0.0 then
    0.
  else
    let limit = exp (-.mean) in
    let rec loop k product =
      if product <= limit then
        float_of_int (k - 1)
      else
        loop (k + 1) (product *. Random.float 1.0)
    in
    loop 0 1.0

let judge_submission deps submission_id =
  let* found = deps.repo.find_submission_by_id submission_id in
  match found with
  | Error repo_error -> error (map_repo_error repo_error)
  | Ok None -> ok ()
  | Ok (Some submission) ->
      if submission.verdict <> Domain.Pending then
        ok ()
      else
        let delay_seconds = deps.judging_delay_seconds () in
        let* () = Lwt_unix.sleep delay_seconds in
        let judged_at = deps.clock.now () in
        let* task_result = deps.repo.find_task_by_id submission.task_id in
        let verdict, run_data =
          match task_result with
          | Error repo_error ->
              ( Domain.Internal_error,
                internal_run_data submission delay_seconds judged_at
                  (map_repo_error repo_error) )
          | Ok None ->
              ( Domain.Internal_error,
                internal_run_data submission delay_seconds judged_at
                  "Task not found for submission" )
          | Ok (Some task) -> (
              match
                Task_config.validate_task_config ~task_type:task.type_
                  task.config
              with
              | Error message ->
                  ( Domain.Internal_error,
                    internal_run_data submission delay_seconds judged_at
                      ("Stored task config is invalid: " ^ message) )
              | Ok normalized_config ->
                  grade_submission submission task normalized_config delay_seconds
                    judged_at)
        in
        let* updated =
          deps.repo.update_submission_result ~submission_id:submission.id
            ~verdict ~run_data:(Some run_data) ~judged_at
        in
        match updated with
        | Ok _ -> ok ()
        | Error repo_error -> error (map_repo_error repo_error)

let process_next deps =
  let* pulled = deps.queue.pull_submission () in
  match pulled with
  | Error _ as queue_error -> Lwt.return queue_error
  | Ok None -> ok false
  | Ok (Some message) ->
      let* judged = judge_submission deps message.submission_id in
      begin
        match judged with
        | Ok () -> ok true
        | Error _ as error_message -> Lwt.return error_message
      end

let rec run_forever ?(poll_interval_seconds = 1.) deps =
  let rec loop () =
    let* processed = process_next deps in
    begin
      match processed with
      | Ok true -> loop ()
      | Ok false ->
          let* () = Lwt_unix.sleep poll_interval_seconds in
          loop ()
      | Error message ->
          prerr_endline ("Submission worker error: " ^ message);
          let* () = Lwt_unix.sleep poll_interval_seconds in
          loop ()
    end
  in
  let* ensured = deps.queue.ensure_ready () in
  match ensured with
  | Ok () -> loop ()
  | Error message ->
      prerr_endline ("Submission worker queue init failed: " ^ message);
      let* () = Lwt_unix.sleep poll_interval_seconds in
      run_forever ~poll_interval_seconds deps
