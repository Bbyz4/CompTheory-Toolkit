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

let mock_run_data clock submission_id verdict delay_seconds =
  `Assoc
    [
      ("worker", `String "mock-rabbitmq-http");
      ("submission_id", `Int submission_id);
      ("strategy", `String "random");
      ("delay_seconds", `Float delay_seconds);
      ("verdict", `String (Domain.submission_verdict_to_string verdict));
      ("judged_at", `String (Util.iso8601_of_unix_time (clock.Clock.now ())));
    ]

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
        let verdict = random_verdict () in
        let judged_at = deps.clock.now () in
        let run_data =
          mock_run_data deps.clock submission.id verdict delay_seconds
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
