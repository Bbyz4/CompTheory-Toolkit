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
  | Ok () -> ensure_mock_seed_data repo clock config

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
