let ( let* ) = Lwt.bind

module Q = Caqti_repo_query.Q

let run_with_connection db_url handler =
  let uri = Uri.of_string db_url in
  let* connected = Caqti_lwt.connect uri in
  match connected with
  | Error error ->
      Lwt.return
        (Error
           (App_error.Internal
              ("Failed to connect to database: " ^ Caqti_error.show error)))
  | Ok connection -> handler connection

let internal_error message = Error (App_error.Internal message)

let repo_internal_error action repo_error =
  internal_error (action ^ ": " ^ Repository.error_message repo_error)

let mock_problem_slug index =
  Printf.sprintf "startup-mock-problem-%05d" index

let mock_problem_title index (spec : Mock_task.spec) =
  Printf.sprintf "Mock Problem %02d: %s" index spec.title

(* Handmade startup data lives next to the generated mock batch, but stays
   deterministic and human-authored so more fixtures can be added here later. *)
let handmade_pilot_username = "Krzysztof-Potepa"

let handmade_pilot_email = "teapot@solana.xchg"

let handmade_pilot_password = "teapot-solana-xchg"

let handmade_pilot_problem_slug = "pilot-problem"

let handmade_pilot_problem_title = "Pilot problem"

let handmade_pilot_tests = [ ""; "ab"; "abab"; "ababab" ]

let handmade_pilot_config =
  `Assoc
    [
      ( "grader",
        `Assoc
          [
            ("kind", `String "explicit-tests");
            ( "tests",
              `List (List.map (fun value -> `String value) handmade_pilot_tests)
            );
          ] );
      ("requiredModelType", `String "NFA");
    ]

let nfa_transition ~from_state ~to_state ?symbol () =
  `Assoc
    [
      ("from", `String from_state);
      ("to", `String to_state);
      ( "symbol",
        match symbol with Some value -> `String value | None -> `Null );
    ]

let nfa_submission_data ~states ~input_alphabet ~transitions ~start_states
    ~accept_states =
  `Assoc
    [
      ("type", `String "NFA");
      ( "model",
        `Assoc
          [
            ("states", `List (List.map (fun value -> `String value) states));
            ( "inputAlphabet",
              `List (List.map (fun value -> `String value) input_alphabet) );
            ("transitions", `List transitions);
            ( "startStates",
              `List (List.map (fun value -> `String value) start_states) );
            ( "acceptStates",
              `List (List.map (fun value -> `String value) accept_states) );
          ] );
    ]

let handmade_pilot_accepted_data =
  nfa_submission_data ~states:[ "q0"; "q1" ] ~input_alphabet:[ "a"; "b" ]
    ~transitions:
      [
        nfa_transition ~from_state:"q0" ~to_state:"q1" ~symbol:"a" ();
        nfa_transition ~from_state:"q1" ~to_state:"q0" ~symbol:"b" ();
      ]
    ~start_states:[ "q0" ] ~accept_states:[ "q0" ]

let handmade_pilot_rejected_data =
  nfa_submission_data
    ~states:[ "q0"; "q1"; "q2"; "q3"; "q4" ]
    ~input_alphabet:[ "a"; "b" ]
    ~transitions:
      [
        nfa_transition ~from_state:"q0" ~to_state:"q1" ~symbol:"a" ();
        nfa_transition ~from_state:"q1" ~to_state:"q2" ~symbol:"b" ();
        nfa_transition ~from_state:"q2" ~to_state:"q3" ~symbol:"a" ();
        nfa_transition ~from_state:"q3" ~to_state:"q4" ~symbol:"b" ();
      ]
    ~start_states:[ "q0" ] ~accept_states:[ "q0"; "q2"; "q4" ]

let handmade_pilot_invalid_format_data =
  nfa_submission_data ~states:[ "q0"; "q1" ] ~input_alphabet:[ "a"; "b" ]
    ~transitions:
      [
        nfa_transition ~from_state:"q0" ~to_state:"q1" ~symbol:"a" ();
        nfa_transition ~from_state:"q1" ~to_state:"missing" ~symbol:"b" ();
      ]
    ~start_states:[ "q0" ] ~accept_states:[ "q0" ]

type handmade_submission_case = {
  key : string;
  expected_verdict : Domain.submission_verdict;
  data : Yojson.Basic.t;
}

let handmade_pilot_submission_cases =
  [
    {
      key = "accepted";
      expected_verdict = Domain.Accepted;
      data = handmade_pilot_accepted_data;
    };
    {
      key = "rejected";
      expected_verdict = Domain.Rejected;
      data = handmade_pilot_rejected_data;
    };
    {
      key = "invalid_format";
      expected_verdict = Domain.Invalid_format;
      data = handmade_pilot_invalid_format_data;
    };
  ]

let handmade_run_data_metadata_field = function
  | "source" | "case" | "expected_verdict" -> true
  | _ -> false

let rec canonical_json = function
  | `Assoc fields ->
      `Assoc
        (fields
        |> List.map (fun (name, value) -> (name, canonical_json value))
        |> List.sort (fun (left_name, _) (right_name, _) ->
               String.compare left_name right_name))
  | `List values -> `List (List.map canonical_json values)
  | (`Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `Floatlit _ | `String _)
    as value ->
      value

let json_equivalent left right = canonical_json left = canonical_json right

let clamp_count value = max 0 value

let seeded_verdict index =
  match index mod 4 with
  | 0 -> Domain.Accepted
  | 1 -> Domain.Rejected
  | 2 -> Domain.Invalid_format
  | _ -> Domain.Internal_error

let seeded_run_data ~submission_id ~seed_index ~verdict ~judged_at =
  `Assoc
    [
      ("worker", `String "mock-startup");
      ("submission_id", `Int submission_id);
      ("seed_index", `Int seed_index);
      ("strategy", `String "deterministic");
      ("verdict", `String (Domain.submission_verdict_to_string verdict));
      ("judged_at", `String (Util.iso8601_of_unix_time judged_at));
    ]

let with_preserved_random_state fn =
  let state = Random.get_state () in
  Lwt.finalize fn (fun () ->
      Random.set_state state;
      Lwt.return_unit)

let bootstrap_admin_email config =
  match Auth_service.validate_email config.Config.mail_from with
  | Ok email -> email
  | Error _ -> "noreply@recognita.local"

let ensure_bootstrap_admin (repo : Repository.t) clock config =
  match config.Config.recognita_admin_username, config.recognita_admin_password with
  | None, None -> Lwt.return (Ok ())
  | Some _, None | None, Some _ ->
      Lwt.return
        (Error
           (App_error.Internal
              "RECOGNITA_ADMIN_USERNAME and RECOGNITA_ADMIN_PASSWORD must be set together"))
  | Some username, Some password -> (
      match Auth_service.validate_username username, Auth_service.validate_password password with
      | Error app_error, _ | _, Error app_error ->
          Lwt.return
            (Error
               (App_error.Internal
                  ("Invalid bootstrap admin credentials: "
                  ^ App_error.message app_error)))
      | Ok (), Ok () ->
          let now = clock.Clock.now () in
          let password_hash = Password.make password in
          let email = bootstrap_admin_email config in
          let* found = repo.find_user_by_username username in
          match found with
          | Error repo_error ->
              Lwt.return
                (Error
                   (App_error.Internal
                      ("Failed to load bootstrap admin: "
                      ^ Repository.error_message repo_error)))
          | Ok None ->
              let* created =
                repo.create_user ~username ~email ~password_hash
                  ~role:Domain.Admin ~created_at:now
              in
              begin
                match created with
                | Error repo_error ->
                    Lwt.return
                      (Error
                         (App_error.Internal
                            ("Failed to create bootstrap admin: "
                            ^ Repository.error_message repo_error)))
                | Ok user ->
                    let* verified =
                      repo.mark_user_verified ~user_id:user.Domain.id ~updated_at:now
                    in
                    begin
                      match verified with
                      | Ok _ -> Lwt.return (Ok ())
                      | Error repo_error ->
                          Lwt.return
                            (Error
                               (App_error.Internal
                                  ("Failed to verify bootstrap admin: "
                                  ^ Repository.error_message repo_error)))
                    end
              end
          | Ok (Some user) ->
              let* updated =
                repo.update_bootstrap_admin ~user_id:user.Domain.id ~email
                  ~password_hash ~updated_at:now
              in
              begin
                match updated with
                | Ok _ -> Lwt.return (Ok ())
                | Error repo_error ->
                    Lwt.return
                      (Error
                         (App_error.Internal
                            ("Failed to refresh bootstrap admin: "
                            ^ Repository.error_message repo_error)))
              end)

let normalize_mock_identity (identity : Mock_identity.person) =
  match
    ( Auth_service.validate_username identity.username,
      Auth_service.validate_email identity.email,
      Auth_service.validate_password identity.password )
  with
  | Error app_error, _, _ | _, Error app_error, _ | _, _, Error app_error ->
      Error
        (App_error.Internal
           ("Invalid generated mock identity for " ^ identity.username ^ ": "
          ^ App_error.message app_error))
  | Ok (), Ok email, Ok () -> Ok (identity.username, email, identity.password)

let ensure_mock_user repo clock index identity =
  match normalize_mock_identity identity with
  | Error _ as error -> Lwt.return error
  | Ok (username, email, password) ->
      let ensure_verified (user : Domain.user) =
        if user.Domain.verified then
          Lwt.return (Ok user)
        else
          let* marked =
            repo.Repository.mark_user_verified ~user_id:user.Domain.id
              ~updated_at:(clock.Clock.now ())
          in
          match marked with
          | Ok (Some user) -> Lwt.return (Ok user)
          | Ok None ->
              Lwt.return
                (internal_error
                   ("Generated mock user disappeared before verification: "
                  ^ username))
          | Error repo_error ->
              Lwt.return
                (repo_internal_error "Failed to verify generated mock user"
                   repo_error)
      in
      let find_existing () =
        let* by_username = repo.find_user_by_username username in
        match by_username with
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to load generated mock user"
                 repo_error)
        | Ok (Some user) -> ensure_verified user
        | Ok None ->
            let* by_email = repo.find_user_by_email email in
            begin
              match by_email with
              | Error repo_error ->
                  Lwt.return
                    (repo_internal_error
                       "Failed to load generated mock user by email" repo_error)
              | Ok (Some user) -> ensure_verified user
              | Ok None ->
                  Lwt.return
                    (internal_error
                       ("Generated mock user conflict could not be resolved at \
                         index "
                      ^ string_of_int index))
            end
      in
      let* existing = repo.find_user_by_username username in
      begin
        match existing with
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to load generated mock user"
                 repo_error)
        | Ok (Some user) -> ensure_verified user
        | Ok None ->
            let* created =
              repo.create_user ~username ~email
                ~password_hash:(Password.make password) ~role:Domain.User
                ~created_at:(clock.Clock.now ())
            in
            begin
              match created with
              | Ok user -> ensure_verified user
              | Error (Repository.Conflict _) -> find_existing ()
              | Error repo_error ->
                  Lwt.return
                    (repo_internal_error "Failed to create generated mock user"
                       repo_error)
            end
      end

let ensure_mock_users repo clock ~seed ~count =
  if count = 0 then
    Lwt.return (Ok [])
  else
    let identities = Mock_identity.generate ~seed ~start_index:1 ~count in
    let rec loop acc = function
      | [] -> Lwt.return (Ok (List.rev acc))
      | (index, identity) :: rest -> (
          let* ensured = ensure_mock_user repo clock index identity in
          match ensured with
          | Error _ as error -> Lwt.return error
          | Ok user -> loop (user :: acc) rest)
    in
    identities
    |> List.mapi (fun offset identity -> (offset + 1, identity))
    |> loop []

let ensure_mock_problem repo clock (users : Domain.user list) ~seed:_ index spec =
  match users with
  | [] ->
      Lwt.return
        (internal_error
           "Cannot create startup mock problems without startup mock users")
  | _ ->
      let slug = mock_problem_slug index in
      let* existing = repo.Repository.find_task_by_slug slug in
      begin
        match existing with
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to load startup mock problem"
                 repo_error)
        | Ok (Some task) -> Lwt.return (Ok task)
        | Ok None ->
            let users_array = Array.of_list users in
            let author =
              users_array.((index - 1) mod Array.length users_array)
            in
            let now = clock.Clock.now () in
            let* created =
              repo.create_task
                ~title:(mock_problem_title index spec)
                ~slug:(Some slug) ~short_description:None
                ~description:spec.Mock_task.description
                ~type_:Domain.Model_construction ~author_id:author.Domain.id
                ~difficulty:spec.difficulty
                ~config:(Task_config.config_template_json Domain.Model_construction)
                ~status:Domain.Published ~visibility:Domain.Public
                ~published_at:(Some now) ~created_at:now ~updated_at:now
            in
            begin
              match created with
              | Ok task -> Lwt.return (Ok task)
              | Error (Repository.Conflict _) -> (
                  let* found = repo.find_task_by_slug slug in
                  match found with
                  | Ok (Some task) -> Lwt.return (Ok task)
                  | Ok None ->
                      Lwt.return
                        (internal_error
                           ("Startup mock problem conflict could not be \
                             resolved for slug "
                          ^ slug))
                  | Error repo_error ->
                      Lwt.return
                        (repo_internal_error
                           "Failed to reload startup mock problem" repo_error))
              | Error repo_error ->
                  Lwt.return
                    (repo_internal_error "Failed to create startup mock problem"
                       repo_error)
            end
      end

let ensure_mock_problems repo clock (users : Domain.user list) ~seed ~count =
  if count = 0 then
    Lwt.return (Ok [])
  else if users = [] then
    Lwt.return
      (internal_error
         "RECOGNITA_BOOTSTRAP_MOCK_PROBLEMS requires \
          RECOGNITA_BOOTSTRAP_MOCK_USERS to be greater than 0")
  else
    let specs = Mock_task.generate ~seed ~start_index:1 ~count in
    let rec loop acc = function
      | [] -> Lwt.return (Ok (List.rev acc))
      | (index, spec) :: rest -> (
          let* ensured =
            ensure_mock_problem repo clock users ~seed index spec
          in
          match ensured with
          | Error _ as error -> Lwt.return error
          | Ok task -> loop (task :: acc) rest)
    in
    specs
    |> List.mapi (fun offset spec -> (offset + 1, spec))
    |> loop []

let submission_belongs_to_seeded_data (user_ids : int list) (task_ids : int list)
    (submission : Domain.submission) =
  List.mem submission.Domain.user_id user_ids
  && List.mem submission.task_id task_ids

let create_mock_submission repo clock (users : Domain.user list)
    (tasks : Domain.task list) ~seed ~total_count index =
  let users_array = Array.of_list users in
  let tasks_array = Array.of_list tasks in
  let user = users_array.((index - 1) mod Array.length users_array) in
  let task = tasks_array.((index - 1) mod Array.length tasks_array) in
  Random.init (seed + (index * 7919));
  match
    Mock_model.generate_for_task
      ~task_type:(Domain.task_type_to_string task.Domain.type_)
      ~config:task.config
  with
  | Error message ->
      Lwt.return
        (internal_error
           ("Failed to generate startup mock submission data: " ^ message))
  | Ok data ->
      let now = clock.Clock.now () in
      let created_at = now -. float_of_int (max 0 (total_count - index)) in
      let* created =
        repo.Repository.create_submission ~task_id:task.Domain.id
          ~user_id:user.Domain.id ~data ~created_at
      in
      begin
        match created with
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to create startup mock submission"
                 repo_error)
        | Ok submission -> (
            let verdict = seeded_verdict index in
            let judged_at = created_at +. 1. in
            let run_data =
              seeded_run_data ~submission_id:submission.Domain.id
                ~seed_index:index ~verdict ~judged_at
            in
            let* updated =
              repo.update_submission_result ~submission_id:submission.id
                ~verdict ~run_data:(Some run_data) ~judged_at
            in
            match updated with
            | Ok _ -> Lwt.return (Ok ())
            | Error repo_error ->
                Lwt.return
                  (repo_internal_error
                     "Failed to judge startup mock submission" repo_error))
      end

let ensure_mock_submissions repo clock (users : Domain.user list)
    (tasks : Domain.task list) ~seed ~count =
  if count = 0 then
    Lwt.return (Ok ())
  else if users = [] || tasks = [] then
    Lwt.return
      (internal_error
         "RECOGNITA_BOOTSTRAP_MOCK_SUBMISSIONS requires startup mock users and \
          problems")
  else
    let user_ids = List.map (fun (user : Domain.user) -> user.id) users in
    let task_ids = List.map (fun (task : Domain.task) -> task.id) tasks in
    let* listed = repo.Repository.list_submissions () in
    match listed with
    | Error repo_error ->
        Lwt.return
          (repo_internal_error "Failed to list startup mock submissions"
             repo_error)
    | Ok submissions ->
        let existing_count =
          submissions
          |> List.filter (submission_belongs_to_seeded_data user_ids task_ids)
          |> List.length
        in
        let rec loop index =
          if index > count then
            Lwt.return (Ok ())
          else
            let* created =
              create_mock_submission repo clock users tasks ~seed
                ~total_count:count index
            in
            match created with
            | Error _ as error -> Lwt.return error
            | Ok () -> loop (index + 1)
        in
        with_preserved_random_state (fun () -> loop (existing_count + 1))

let ensure_verified_user repo clock (user : Domain.user) =
  if user.Domain.verified then
    Lwt.return (Ok user)
  else
    let* marked =
      repo.Repository.mark_user_verified ~user_id:user.Domain.id
        ~updated_at:(clock.Clock.now ())
    in
    match marked with
    | Ok (Some user) -> Lwt.return (Ok user)
    | Ok None ->
        Lwt.return
          (internal_error
             ("Handmade user disappeared before verification: "
            ^ user.username))
    | Error repo_error ->
        Lwt.return
          (repo_internal_error "Failed to verify handmade user" repo_error)

let ensure_handmade_pilot_user repo clock =
  match
    ( Auth_service.validate_username handmade_pilot_username,
      Auth_service.validate_email handmade_pilot_email,
      Auth_service.validate_password handmade_pilot_password )
  with
  | Error app_error, _, _ | _, Error app_error, _ | _, _, Error app_error ->
      Lwt.return
        (Error
           (App_error.Internal
              ("Invalid handmade pilot user: " ^ App_error.message app_error)))
  | Ok (), Ok email, Ok () ->
      let rec find_by_email () =
        let* found = repo.Repository.find_user_by_email email in
        match found with
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to load handmade pilot user by email"
                 repo_error)
        | Ok (Some user) -> ensure_verified_user repo clock user
        | Ok None ->
            let* created =
              repo.create_user ~username:handmade_pilot_username ~email
                ~password_hash:(Password.make handmade_pilot_password)
                ~role:Domain.User ~created_at:(clock.Clock.now ())
            in
            begin
              match created with
              | Ok user -> ensure_verified_user repo clock user
              | Error (Repository.Conflict _) -> find_by_email ()
              | Error repo_error ->
                  Lwt.return
                    (repo_internal_error "Failed to create handmade pilot user"
                       repo_error)
            end
      in
      let* found = repo.find_user_by_username handmade_pilot_username in
      begin
        match found with
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to load handmade pilot user"
                 repo_error)
        | Ok (Some user) -> ensure_verified_user repo clock user
        | Ok None -> find_by_email ()
      end

let ensure_handmade_pilot_problem repo clock (author : Domain.user) =
  let* found = repo.Repository.find_task_by_slug handmade_pilot_problem_slug in
  match found with
  | Error repo_error ->
      Lwt.return
        (repo_internal_error "Failed to load handmade pilot problem" repo_error)
  | Ok (Some task) -> Lwt.return (Ok task)
  | Ok None ->
      let now = clock.Clock.now () in
      let* created =
        repo.create_task ~title:handmade_pilot_problem_title
          ~slug:(Some handmade_pilot_problem_slug)
          ~short_description:(Some "Build an NFA for strings in (ab)*.")
          ~description:
            "Build an NFA over the alphabet {a,b} that accepts exactly the \
             empty string and strings formed by repeating ab, such as ab, abab \
             and ababab."
          ~type_:Domain.Model_construction ~author_id:author.Domain.id
          ~difficulty:1 ~config:handmade_pilot_config ~status:Domain.Published
          ~visibility:Domain.Public ~published_at:(Some now) ~created_at:now
          ~updated_at:now
      in
      begin
        match created with
        | Ok task -> Lwt.return (Ok task)
        | Error (Repository.Conflict _) -> (
            let* reloaded =
              repo.find_task_by_slug handmade_pilot_problem_slug
            in
            match reloaded with
            | Ok (Some task) -> Lwt.return (Ok task)
            | Ok None ->
                Lwt.return
                  (internal_error
                     "Handmade pilot problem conflict could not be resolved")
            | Error repo_error ->
                Lwt.return
                  (repo_internal_error
                     "Failed to reload handmade pilot problem" repo_error))
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to create handmade pilot problem"
                 repo_error)
      end

let handmade_submission_matches (task : Domain.task) (user : Domain.user)
    (case : handmade_submission_case) (submission : Domain.submission) =
  submission.task_id = task.id
  && submission.user_id = user.id
  && json_equivalent submission.data case.data

let strip_handmade_run_data_metadata = function
  | Some (`Assoc fields)
    when List.exists
           (fun (name, _) -> handmade_run_data_metadata_field name)
           fields ->
      let fields =
        List.filter
          (fun (name, _) -> not (handmade_run_data_metadata_field name))
          fields
      in
      begin
        match fields with
        | [ ("worker_run_data", `Assoc worker_fields) ] -> Some (`Assoc worker_fields)
        | _ ->
            Some
              (`Assoc
                (List.filter (fun (name, _) -> name <> "worker_run_data") fields))
      end
  | _ -> None

let clean_handmade_run_data repo clock (submission : Domain.submission) =
  match strip_handmade_run_data_metadata submission.run_data with
  | None -> Lwt.return (Ok ())
  | Some run_data ->
      let judged_at =
        match submission.judged_at with
        | Some value -> value
        | None -> clock.Clock.now ()
      in
      let* updated =
        repo.Repository.update_submission_result ~submission_id:submission.id
          ~verdict:submission.verdict ~run_data:(Some run_data) ~judged_at
      in
      begin
        match updated with
        | Ok _ -> Lwt.return (Ok ())
        | Error repo_error ->
            Lwt.return
              (repo_internal_error "Failed to clean handmade pilot submission"
                 repo_error)
      end

let verify_handmade_submission repo clock (case : handmade_submission_case)
    submission_id =
  let worker_deps : Submission_worker.deps =
    {
      repo;
      queue = Submission_queue.make_memory ();
      clock;
      judging_delay_seconds = (fun () -> 0.);
    }
  in
  let* judged = Submission_worker.judge_submission worker_deps submission_id in
  match judged with
  | Error message ->
      Lwt.return
        (internal_error
           ("Failed to judge handmade pilot submission " ^ case.key ^ ": "
          ^ message))
  | Ok () -> (
      let* found = repo.Repository.find_submission_by_id submission_id in
      match found with
      | Error repo_error ->
          Lwt.return
            (repo_internal_error "Failed to reload handmade pilot submission"
               repo_error)
      | Ok None ->
          Lwt.return
            (internal_error "Handmade pilot submission disappeared after judging")
      | Ok (Some submission) ->
          if submission.verdict <> case.expected_verdict then
            Lwt.return
              (internal_error
                 (Printf.sprintf
                    "Handmade pilot submission %s produced %s, expected %s"
                    case.key
                    (Domain.submission_verdict_to_string submission.verdict)
                    (Domain.submission_verdict_to_string
                       case.expected_verdict)))
          else
            clean_handmade_run_data repo clock submission)

let ensure_handmade_pilot_submission repo clock (user : Domain.user)
    (task : Domain.task) (case : handmade_submission_case) =
  let* listed = repo.Repository.list_submissions () in
  match listed with
  | Error repo_error ->
      Lwt.return
        (repo_internal_error "Failed to list handmade pilot submissions"
           repo_error)
  | Ok submissions -> (
      match
        List.find_opt
          (handmade_submission_matches task user case)
          submissions
      with
      | Some submission ->
          verify_handmade_submission repo clock case submission.id
      | None ->
          let* created =
            repo.create_submission ~task_id:task.id ~user_id:user.id
              ~data:case.data ~created_at:(clock.Clock.now ())
          in
          begin
            match created with
            | Error repo_error ->
                Lwt.return
                  (repo_internal_error
                     "Failed to create handmade pilot submission" repo_error)
            | Ok submission ->
                verify_handmade_submission repo clock case submission.id
          end)

let ensure_handmade_seed_data repo clock =
  Lwt.catch
    (fun () ->
      let* user = ensure_handmade_pilot_user repo clock in
      match user with
      | Error _ as error -> Lwt.return error
      | Ok user ->
          let* task = ensure_handmade_pilot_problem repo clock user in
          begin
            match task with
            | Error _ as error -> Lwt.return error
            | Ok task ->
                let rec loop = function
                  | [] -> Lwt.return (Ok ())
                  | case :: rest -> (
                      let* ensured =
                        ensure_handmade_pilot_submission repo clock user task
                          case
                      in
                      match ensured with
                      | Error _ as error -> Lwt.return error
                      | Ok () -> loop rest)
                in
                loop handmade_pilot_submission_cases
          end)
    (fun exn ->
      Lwt.return
        (internal_error
           ("Failed to generate handmade startup data: "
          ^ Printexc.to_string exn)))

let ensure_mock_seed_data repo clock config =
  let user_count = clamp_count config.Config.recognita_mock_user_count in
  let problem_count = clamp_count config.recognita_mock_problem_count in
  let submission_count = clamp_count config.recognita_mock_submission_count in
  if user_count = 0 && problem_count = 0 && submission_count = 0 then
    Lwt.return (Ok ())
  else
    Lwt.catch
      (fun () ->
        let seed = config.Config.recognita_mock_seed in
        let* users = ensure_mock_users repo clock ~seed ~count:user_count in
        match users with
        | Error _ as error -> Lwt.return error
        | Ok users ->
            let* tasks =
              ensure_mock_problems repo clock users ~seed ~count:problem_count
            in
            begin
              match tasks with
              | Error _ as error -> Lwt.return error
              | Ok tasks ->
                  ensure_mock_submissions repo clock users tasks ~seed
                    ~count:submission_count
            end)
      (fun exn ->
        Lwt.return
          (internal_error
             ("Failed to generate startup mock data: " ^ Printexc.to_string exn)))

let run_startup_steps repo clock config =
  let* admin_result = ensure_bootstrap_admin repo clock config in
  match admin_result with
  | Error _ as error -> Lwt.return error
  | Ok () ->
      let* handmade_result = ensure_handmade_seed_data repo clock in
      begin
        match handmade_result with
        | Error _ as error -> Lwt.return error
        | Ok () -> ensure_mock_seed_data repo clock config
      end

let with_startup_lock connection handler =
  let module Db = (val connection : Caqti_lwt.CONNECTION) in
  let exec query =
    let* result = Db.exec query () in
    match result with
    | Ok () -> Lwt.return (Ok ())
    | Error error ->
        Lwt.return
          (internal_error
             ("Failed to manage startup database lock: "
            ^ Caqti_error.show error))
  in
  let* acquired = exec Q.acquire_schema_lock in
  match acquired with
  | Error _ as error -> Lwt.return error
  | Ok () ->
      let* handler_result =
        Lwt.catch handler (fun exn ->
            Lwt.return
              (internal_error
                 ("Startup failed: " ^ Printexc.to_string exn)))
      in
      let* released = exec Q.release_schema_lock in
      begin
        match handler_result, released with
        | Error _ as error, _ -> Lwt.return error
        | Ok (), (Error _ as error) -> Lwt.return error
        | Ok (), Ok () -> Lwt.return (Ok ())
      end

let run config clock =
  run_with_connection config.Config.db_url (fun connection ->
      with_startup_lock connection (fun () ->
        let repo = Caqti_repo.make connection in
        let* init_result = repo.init_schema () in
        match init_result with
        | Error repo_error ->
            Lwt.return
              (Error
                 (App_error.Internal
                    ("Failed to initialize schema: "
                    ^ Repository.error_message repo_error)))
        | Ok () -> run_startup_steps repo clock config))
