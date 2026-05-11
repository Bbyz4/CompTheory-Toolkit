open Yojson.Basic.Util

let ( let* ) = Lwt.bind

exception Test_failure of string

let fail message = raise (Test_failure message)

let assert_true condition message = if not condition then fail message

let contains_substring ~needle haystack =
  let needle_length = String.length needle in
  let haystack_length = String.length haystack in
  let rec loop index =
    if index + needle_length > haystack_length then
      false
    else if String.sub haystack index needle_length = needle then
      true
    else
      loop (index + 1)
  in
  needle_length = 0 || loop 0

let assert_status expected response =
  let actual = Dream.status response in
  if actual <> expected then fail "Unexpected HTTP status"

let response_body response = Lwt_main.run (Dream.body response)

let response_json response = response |> response_body |> Yojson.Basic.from_string

let json_headers = [ ("Content-Type", "application/json") ]

type fixture = {
  app : Dream.handler;
  repo : Toolkit.Repository.t;
  clock : Toolkit.Clock.t;
  sent_emails : Toolkit.Verification_mailer.sent_mail list ref;
  submission_queue : Toolkit.Submission_queue.t;
}

let base_config ?(auth_rate_limit_max_requests = 10) ?(rate_limit_max_requests = 100)
    () : Toolkit.Config.t =
  {
    Toolkit.Config.mode = Toolkit.Runtime_mode.Local;
    host = "127.0.0.1";
    port = 8080;
    base_url = "http://127.0.0.1:8080";
    public_web_base_url = "http://127.0.0.1:8081";
    db_url = "postgresql://toolkit:toolkit@db:5432/toolkit";
    schema_path = "sql/schema.sql";
    openapi_path = "openapi/openapi.json";
    access_token_ttl_seconds = 60.;
    refresh_token_ttl_seconds = 3600.;
    verification_token_ttl_seconds = 7200.;
    rate_limit_window_seconds = 60.;
    rate_limit_max_requests;
    auth_rate_limit_window_seconds = 60.;
    auth_rate_limit_max_requests;
    smtp_host = "127.0.0.1";
    smtp_port = 1025;
    mail_from = "no-reply@recognita.xyz";
    recognita_admin_username = None;
    recognita_admin_password = None;
    rabbitmq_api_base_url = "http://rabbitmq:15672";
    rabbitmq_user = "recognita";
    rabbitmq_password = "recognita";
    rabbitmq_vhost = "/";
    rabbitmq_submission_queue = "submissions.pending";
    submission_worker_poll_interval_seconds = 0.01;
  }

let make_fixture ?(auth_rate_limit_max_requests = 10)
    ?(rate_limit_max_requests = 100) () =
  let config =
    base_config ~auth_rate_limit_max_requests ~rate_limit_max_requests ()
  in
  let repo = Toolkit.In_memory_repo.make () in
  let clock_ref = ref 1_700_000_000. in
  let clock = Toolkit.Clock.make (fun () -> !clock_ref) in
  let mailer, sent_emails =
    Toolkit.Verification_mailer.make_memory ~from_address:config.mail_from
      ~site_name:"Recognita" ()
  in
  let submission_queue = Toolkit.Submission_queue.make_memory () in
  let rate_limiter =
    Toolkit.Rate_limiter.make ~clock
      ~auth_rule:
        {
          max_requests = auth_rate_limit_max_requests;
          window_seconds = 60.;
        }
      ~default_rule:
        {
          max_requests = rate_limit_max_requests;
          window_seconds = 60.;
        }
  in
  let app =
    let app_config : Toolkit.App.t =
      {
        config;
        clock;
        rate_limiter;
        mailer;
        submission_queue;
        with_repo = (fun _request handler -> handler repo);
      }
    in
    Toolkit.App.make app_config
  in
  let _ = clock_ref in
  { app; repo; clock; sent_emails; submission_queue }

let request fixture ?(client = "127.0.0.1:55000") ?(headers = []) ?(body = "")
    ~meth ~target () =
  let request = Dream.request ~method_:meth ~target ~headers body in
  Dream.set_client request client;
  Dream.test fixture.app request

let request_handler handler ?(client = "127.0.0.1:55000") ?(headers = [])
    ?(body = "") ~meth ~target () =
  let request = Dream.request ~method_:meth ~target ~headers body in
  Dream.set_client request client;
  Dream.test handler request

let token_of_response response field =
  let json = response_json response in
  json |> member "tokens" |> member field |> to_string

let user_id_of_response response =
  let json = response_json response in
  json |> member "user" |> member "id" |> to_int

let task_id_of_response response =
  let json = response_json response in
  json |> member "task" |> member "id" |> to_int

let task_slug_of_response response =
  let json = response_json response in
  json |> member "task" |> member "slug" |> to_string

let submission_id_of_response response =
  let json = response_json response in
  json |> member "submission" |> member "id" |> to_int

let model_construction_config ?(required_model_type = "NFA") () =
  `Assoc
    [
      ("version", `Int 1);
      ("grader", `Assoc [ ("kind", `String "mock") ]);
      ("requiredModelType", `String required_model_type);
    ]

let valid_nfa_submission_data
    ?(states = [ "q0"; "q1" ])
    ?(input_alphabet = [ "a" ])
    ?(transitions =
      [
        `Assoc
          [
            ("from", `String "q0");
            ("to", `String "q1");
            ("symbol", `String "a");
          ];
      ])
    ?(start_states = [ "q0" ])
    ?(accept_states = [ "q1" ]) () =
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

let unwrap_result map_error = function
  | Ok value -> value
  | Error error -> fail (map_error error)

let unwrap_ok result = unwrap_result (fun message -> message) result

let unwrap_repo_ok result =
  unwrap_result Toolkit.Repository.error_message result

let db_integration_enabled () =
  match Sys.getenv_opt "RUN_DB_INTEGRATION_TESTS" with
  | Some ("1" | "true" | "TRUE" | "yes" | "YES") -> true
  | _ -> false

let integration_database_url () =
  match Sys.getenv_opt "DATABASE_URL" with
  | Some value -> value
  | None -> "postgresql://toolkit:toolkit@127.0.0.1:5432/toolkit"

let integration_admin_database_url () =
  match Sys.getenv_opt "TEST_DATABASE_ADMIN_URL" with
  | Some value -> value
  | None ->
      let uri = Uri.of_string (integration_database_url ()) in
      Uri.with_path uri "/postgres" |> Uri.to_string

let sql_identifier value =
  let valid_char = function
    | 'a' .. 'z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  if String.length value = 0 || not (String.for_all valid_char value) then
    fail ("Unsafe SQL identifier: " ^ value)
  else
    value

let connect_or_fail db_url handler =
  let connected = Lwt_main.run (Caqti_lwt.connect (Uri.of_string db_url)) in
  match connected with
  | Error error ->
      fail ("Failed to connect to test database: " ^ Caqti_error.show error)
  | Ok connection -> Lwt_main.run (handler connection)

let exec_sql_or_fail connection sql =
  let module Db = (val connection : Caqti_lwt.CONNECTION) in
  let open Caqti_request.Infix in
  let request = Caqti_type.(unit ->. unit) sql in
  let* result = Db.exec request () in
  match result with
  | Ok () -> Lwt.return_unit
  | Error error -> fail ("SQL execution failed: " ^ Caqti_error.show error)

let with_postgres_repo test_fn =
  let admin_url = integration_admin_database_url () in
  let template_uri = Uri.of_string (integration_database_url ()) in
  let db_name =
    sql_identifier
      (Printf.sprintf "recognita_test_%d_%d" (Unix.getpid ())
         (Random.bits () land 0x3fffffff))
  in
  let db_url = Uri.with_path template_uri ("/" ^ db_name) |> Uri.to_string in
  connect_or_fail admin_url (fun admin_connection ->
      exec_sql_or_fail admin_connection ("CREATE DATABASE " ^ db_name));
  Fun.protect
    ~finally:(fun () ->
      connect_or_fail admin_url (fun admin_connection ->
          exec_sql_or_fail admin_connection
            ("DROP DATABASE IF EXISTS " ^ db_name ^ " WITH (FORCE)")))
    (fun () ->
      let clock_ref = ref 1_700_000_000. in
      let clock = Toolkit.Clock.make (fun () -> !clock_ref) in
      connect_or_fail db_url (fun connection ->
          let repo = Toolkit.Caqti_repo.make connection in
          let* init_result = repo.init_schema () in
          ignore (unwrap_repo_ok init_result);
          test_fn repo clock))

let register fixture username email password =
  request fixture ~meth:`POST ~target:"/api/v1/auth/register"
    ~headers:json_headers
    ~body:
      (Yojson.Basic.to_string
         (`Assoc
           [
             ("username", `String username);
             ("email", `String email);
             ("password", `String password);
           ]))
    ()

let login fixture username password =
  request fixture ~meth:`POST ~target:"/api/v1/auth/login" ~headers:json_headers
    ~body:
      (Yojson.Basic.to_string
         (`Assoc
           [ ("username", `String username); ("password", `String password) ]))
    ()

let latest_email fixture =
  match !(fixture.sent_emails) with
  | mail :: _ -> mail
  | [] -> fail "Expected verification email to be sent"

let create_admin_user fixture ?(username = "admin")
    ?(email = "admin@recognita.xyz") ?(password = "change-me-now") () =
  Lwt_main.run
    (fixture.repo.create_user ~username ~email
       ~password_hash:(Toolkit.Password.make password)
       ~role:Toolkit.Domain.Admin ~created_at:1_700_000_000.)
  |> unwrap_repo_ok

let login_admin fixture =
  ignore (create_admin_user fixture ());
  let response = login fixture "admin" "change-me-now" in
  assert_status `OK response;
  token_of_response response "access_token"

let create_task fixture access_token
    ?(title = "Mock task")
    ?(description = "Task description")
    ?author_id
    ?(difficulty = 3)
    ?(status = "PUBLISHED")
    ?(visibility = "PUBLIC")
    ?(config =
      model_construction_config ())
    () =
  let fields =
    [
      ("title", `String title);
      ("description", `String description);
      ("type", `String "MODEL_CONSTRUCTION");
      ("difficulty", `Int difficulty);
      ("config", config);
      ("status", `String status);
      ("visibility", `String visibility);
    ]
  in
  let fields =
    match author_id with
    | Some value -> ("author_id", `Int value) :: fields
    | None -> fields
  in
  request fixture ~meth:`POST ~target:"/api/v1/tasks"
    ~headers:
      [
        ("Authorization", "Bearer " ^ access_token);
        ("Content-Type", "application/json");
      ]
    ~body:(Yojson.Basic.to_string (`Assoc fields))
    ()

let verification_token_from_mail mail =
  match Uri.get_query_param (Uri.of_string mail.Toolkit.Verification_mailer.verification_url) "token" with
  | Some token -> token
  | None -> fail "Verification email is missing the token query parameter"

let test_register_and_me () =
  let fixture = make_fixture () in
  let register_response =
    register fixture "alice" "alice@example.com" "password123"
  in
  assert_status `Created register_response;
  let access_token = token_of_response register_response "access_token" in
  let me_response =
    request fixture ~meth:`GET ~target:"/api/v1/me"
      ~headers:[ ("Authorization", "Bearer " ^ access_token) ]
      ()
  in
  assert_status `OK me_response;
  let me_json = response_json me_response in
  assert_true
    ((me_json |> member "user" |> member "username" |> to_string) = "alice")
    "Current user endpoint returned wrong username";
  assert_true
    ((me_json |> member "user" |> member "email" |> to_string)
    = "alice@example.com")
    "Current user endpoint returned wrong email";
  assert_true
    (not (me_json |> member "user" |> member "verified" |> to_bool))
    "Newly registered user should not start as verified"

let test_register_sends_verification_email_and_verify_endpoint () =
  let fixture = make_fixture () in
  let register_response =
    register fixture "violet" "violet@example.com" "password123"
  in
  assert_status `Created register_response;
  let mail = latest_email fixture in
  assert_true
    (mail.Toolkit.Verification_mailer.from_address = "no-reply@recognita.xyz")
    "Verification email should use the configured from address";
  assert_true
    (mail.to_address = "violet@example.com")
    "Verification email should target the registered email address";
  let verify_response =
    request fixture ~meth:`POST ~target:"/api/v1/auth/verify-email"
      ~headers:json_headers
      ~body:
        (Yojson.Basic.to_string
           (`Assoc
             [
               ("token", `String (verification_token_from_mail mail));
             ]))
      ()
  in
  assert_status `OK verify_response;
  let verify_json = response_json verify_response in
  assert_true
    (verify_json |> member "user" |> member "verified" |> to_bool)
    "Verify endpoint should mark the user as verified"

let test_login_and_logout () =
  let fixture = make_fixture () in
  let register_response =
    register fixture "bob" "bob@example.com" "password123"
  in
  assert_status `Created register_response;
  let access_token = token_of_response register_response "access_token" in
  let logout_response =
    request fixture ~meth:`POST ~target:"/api/v1/auth/logout"
      ~headers:[ ("Authorization", "Bearer " ^ access_token) ]
      ()
  in
  assert_status `OK logout_response;
  let me_response =
    request fixture ~meth:`GET ~target:"/api/v1/me"
      ~headers:[ ("Authorization", "Bearer " ^ access_token) ]
      ()
  in
  assert_status `Unauthorized me_response

let test_user_can_delete_own_account () =
  let fixture = make_fixture () in
  let register_response =
    register fixture "bruno" "bruno@example.com" "password123"
  in
  assert_status `Created register_response;
  let access_token = token_of_response register_response "access_token" in
  let delete_response =
    request fixture ~meth:`DELETE ~target:"/api/v1/me"
      ~headers:[ ("Authorization", "Bearer " ^ access_token) ]
      ()
  in
  assert_status `OK delete_response;
  let me_response =
    request fixture ~meth:`GET ~target:"/api/v1/me"
      ~headers:[ ("Authorization", "Bearer " ^ access_token) ]
      ()
  in
  assert_status `Unauthorized me_response;
  let relogin = login fixture "bruno" "password123" in
  assert_status `Unauthorized relogin

let test_delete_user_cascades_owned_tasks_and_submissions () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let author_response =
    register fixture "ola" "ola@example.com" "password123"
  in
  assert_status `Created author_response;
  let author_id = user_id_of_response author_response in
  let author_access = token_of_response author_response "access_token" in
  let task_response =
    create_task fixture admin_access ~author_id
      ~title:"Owned by ola" ~description:"Owned task" ()
  in
  assert_status `Created task_response;
  let task_id = task_id_of_response task_response in
  let task_slug = task_slug_of_response task_response in
  let solver_response =
    register fixture "solver2" "solver2@example.com" "password123"
  in
  assert_status `Created solver_response;
  let solver_access = token_of_response solver_response "access_token" in
  let submission_response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ solver_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_nfa_submission_data ()) ]))
      ()
  in
  assert_status `Created submission_response;
  let submission_id = submission_id_of_response submission_response in
  let delete_response =
    request fixture ~meth:`DELETE ~target:"/api/v1/me"
      ~headers:[ ("Authorization", "Bearer " ^ author_access) ]
      ()
  in
  assert_status `OK delete_response;
  let task_lookup =
    request fixture ~meth:`GET
      ~target:("/api/v1/tasks/slug/" ^ task_slug)
      ()
  in
  assert_status `Not_Found task_lookup;
  let stored_submission =
    Lwt_main.run (fixture.repo.find_submission_by_id submission_id)
    |> unwrap_repo_ok
  in
  assert_true
    (stored_submission = None)
    "Deleting a task author should cascade to submissions owned by that task"

let test_refresh_rotates_tokens () =
  let fixture = make_fixture () in
  let register_response =
    register fixture "carol" "carol@example.com" "password123"
  in
  assert_status `Created register_response;
  let old_access = token_of_response register_response "access_token" in
  let old_refresh = token_of_response register_response "refresh_token" in
  let refresh_response =
    request fixture ~meth:`POST ~target:"/api/v1/auth/refresh"
      ~headers:json_headers
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("refresh_token", `String old_refresh) ]))
      ()
  in
  assert_status `OK refresh_response;
  let new_access = token_of_response refresh_response "access_token" in
  let new_refresh = token_of_response refresh_response "refresh_token" in
  assert_true (old_access <> new_access) "Access token was not rotated";
  assert_true (old_refresh <> new_refresh) "Refresh token was not rotated"

let test_admin_lists_and_moderates_users () =
  let fixture = make_fixture () in
  ignore (create_admin_user fixture ());
  let user_response =
    register fixture "dave" "dave@example.com" "password123"
  in
  assert_status `Created user_response;
  let user_id = user_id_of_response user_response in
  let admin_login = login fixture "admin" "change-me-now" in
  assert_status `OK admin_login;
  let admin_access = token_of_response admin_login "access_token" in
  let users_response =
    request fixture ~meth:`GET ~target:"/api/v1/users"
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `OK users_response;
  let users_json = response_json users_response in
  let users = users_json |> member "users" |> to_list in
  assert_true
    (List.length users >= 2)
    "Admin user list is missing expected users";
  let dave =
    List.find
      (fun user -> user |> member "username" |> to_string = "dave")
      users
  in
  assert_true
    (dave |> member "email" |> to_string = "dave@example.com")
    "Admin user list should include user emails";
  assert_true
    (not (dave |> member "verified" |> to_bool))
    "User should still be unverified before confirming email";
  let ban_response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/users/%d/ban" user_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ admin_access);
          ("Content-Type", "application/json");
        ]
      ~body:(Yojson.Basic.to_string (`Assoc [ ("reason", `String "spam") ]))
      ()
  in
  assert_status `OK ban_response;
  let banned_login = login fixture "dave" "password123" in
  assert_status `Forbidden banned_login;
  let unban_response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/users/%d/unban" user_id)
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `OK unban_response;
  let relogin = login fixture "dave" "password123" in
  assert_status `OK relogin

let test_non_admin_cannot_moderate () =
  let fixture = make_fixture () in
  let alice = register fixture "erin" "erin@example.com" "password123" in
  let bob = register fixture "frank" "frank@example.com" "password123" in
  assert_status `Created alice;
  assert_status `Created bob;
  let alice_access = token_of_response alice "access_token" in
  let bob_id = user_id_of_response bob in
  let response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/users/%d/ban" bob_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ alice_access);
          ("Content-Type", "application/json");
        ]
      ~body:(Yojson.Basic.to_string (`Assoc [ ("reason", `String "abuse") ]))
      ()
  in
  assert_status `Forbidden response

let test_rate_limit_blocks_auth_endpoint () =
  let fixture = make_fixture ~auth_rate_limit_max_requests:2 () in
  let first = login fixture "ghost" "badpass123" in
  let second = login fixture "ghost" "badpass123" in
  let third = login fixture "ghost" "badpass123" in
  assert_status `Unauthorized first;
  assert_status `Unauthorized second;
  assert_status `Too_Many_Requests third

let test_health_and_openapi () =
  let fixture = make_fixture () in
  let health = request fixture ~meth:`GET ~target:"/health" () in
  let openapi = request fixture ~meth:`GET ~target:"/openapi.json" () in
  assert_status `OK health;
  assert_status `OK openapi;
  assert_true
    (String.length (response_body openapi) > 0)
    "OpenAPI document should not be empty"

let test_admin_creates_task_and_public_list_exposes_it () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_json = response_json created_task |> member "task" in
  assert_true
    (task_json |> member "type" |> to_string = "MODEL_CONSTRUCTION")
    "Created task should expose the task type";
  let listed = request fixture ~meth:`GET ~target:"/api/v1/tasks" () in
  assert_status `OK listed;
  let tasks = response_json listed |> member "tasks" |> to_list in
  assert_true (List.length tasks = 1) "Public task list should include the new task"

let test_submission_is_created_pending_and_worker_judges_it () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "solver" "solver@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let created_submission =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ solver_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_nfa_submission_data ()) ]))
      ()
  in
  assert_status `Created created_submission;
  let created_submission_json =
    response_json created_submission |> member "submission"
  in
  assert_true
    (created_submission_json |> member "verdict" |> to_string = "PENDING")
    "New submission should start as pending";
  let submission_id = submission_id_of_response created_submission in
  let worker_deps : Toolkit.Submission_worker.deps =
    {
      repo = fixture.repo;
      queue = fixture.submission_queue;
      clock = fixture.clock;
      judging_delay_seconds = (fun () -> 0.);
    }
  in
  let processed =
    Lwt_main.run (Toolkit.Submission_worker.process_next worker_deps)
    |> unwrap_ok
  in
  assert_true processed "Worker should consume one queued submission";
  let stored_submission =
    Lwt_main.run (fixture.repo.find_submission_by_id submission_id)
    |> unwrap_repo_ok
  in
  match stored_submission with
  | Some submission ->
      assert_true
        (submission.verdict <> Toolkit.Domain.Pending)
        "Worker should replace the pending verdict with a mock result";
      assert_true
        (submission.run_data <> None)
        "Worker should persist mock run_data"
  | None -> fail "Stored submission should still be queryable"

let test_submission_rejects_invalid_nfa_payload () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "solver_bad" "solver_bad@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let invalid_duplicate_transition =
    `Assoc
      [
        ("type", `String "NFA");
        ( "model",
          `Assoc
            [
              ("states", `List [ `String "q0"; `String "q1" ]);
              ("inputAlphabet", `List [ `String "a" ]);
              ( "transitions",
                `List
                  [
                    `Assoc
                      [
                        ("from", `String "q0");
                        ("to", `String "q1");
                        ("symbol", `String "a");
                      ];
                    `Assoc
                      [
                        ("from", `String "q0");
                        ("to", `String "q1");
                        ("symbol", `String "a");
                      ];
                  ] );
              ("startStates", `List [ `String "q0" ]);
              ("acceptStates", `List [ `String "q1" ]);
            ] );
      ]
  in
  let response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ solver_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", invalid_duplicate_transition) ]))
      ()
  in
  assert_status `Bad_Request response

let test_task_config_template_endpoint () =
  let fixture = make_fixture () in
  let response =
    request fixture ~meth:`GET
      ~target:"/api/v1/task-types/MODEL_CONSTRUCTION/config-template"
      ()
  in
  assert_status `OK response;
  let json = response_json response in
  assert_true
    (json |> member "config_template" |> member "grader" |> member "kind"
   |> to_string
    = "mock")
    "Task config template endpoint should return the mock grader template"
  ;
  assert_true
    (json |> member "config_template" |> member "requiredModelType" |> to_string
    = "NFA")
    "Task config template endpoint should expose the required model type";
  assert_true
    (json |> member "submission_template" |> member "type" |> to_string = "NFA")
    "Task config template endpoint should expose the default submission template"

let test_task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task =
    create_task fixture admin_access ~title:"Regular Languages 101" ()
  in
  assert_status `Created created_task;
  let slug = task_slug_of_response created_task in
  assert_true
    (slug = "regular-languages-101")
    "Task creation should generate a slug from the title when missing";
  let fetched =
    request fixture ~meth:`GET
      ~target:("/api/v1/tasks/slug/" ^ slug)
      ()
  in
  assert_status `OK fetched;
  assert_true
    (response_json fetched |> member "task" |> member "title" |> to_string
    = "Regular Languages 101")
    "Task should be fetchable by generated slug"

let test_submissions_scope_mine_vs_all () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let alice = register fixture "queuealice" "queuealice@example.com" "password123" in
  let bob = register fixture "queuebob" "queuebob@example.com" "password123" in
  assert_status `Created alice;
  assert_status `Created bob;
  let alice_access = token_of_response alice "access_token" in
  let bob_access = token_of_response bob "access_token" in
  let post_submission access_token _answer =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ access_token);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_nfa_submission_data ()) ]))
      ()
  in
  assert_status `Created (post_submission alice_access "a");
  assert_status `Created (post_submission bob_access "b");
  let mine =
    request fixture ~meth:`GET ~target:"/api/v1/submissions?scope=mine"
      ~headers:[ ("Authorization", "Bearer " ^ alice_access) ]
      ()
  in
  assert_status `OK mine;
  assert_true
    (List.length (response_json mine |> member "submissions" |> to_list) = 1)
    "Mine scope should only return the current user's submissions";
  let all_forbidden =
    request fixture ~meth:`GET ~target:"/api/v1/submissions?scope=all"
      ~headers:[ ("Authorization", "Bearer " ^ alice_access) ]
      ()
  in
  assert_status `Forbidden all_forbidden;
  let all_for_admin =
    request fixture ~meth:`GET ~target:"/api/v1/submissions?scope=all"
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `OK all_for_admin;
  assert_true
    (List.length (response_json all_for_admin |> member "submissions" |> to_list) = 2)
    "Admin all scope should return every submission"

let web_config () : Toolkit.Web_config.t =
  {
    mode = Toolkit.Runtime_mode.Local;
    host = "127.0.0.1";
    port = 8081;
    api_base_url = "http://127.0.0.1:8080";
    site_name = "Recognita";
    access_code = "pezarski";
    access_cookie_secret = "test-gate-secret";
  }

let web_cookie_from_response response =
  match Dream.header response "set-cookie" with
  | Some cookie -> List.hd (String.split_on_char ';' cookie)
  | None -> fail "Expected access gate to set a cookie"

let test_web_requires_access_code_for_html_and_proxy () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let home = request_handler app ~meth:`GET ~target:"/" () in
  assert_status `OK home;
  let home_body = response_body home in
  assert_true
    (contains_substring
       ~needle:"Enter the super secret recognita codeword"
       home_body)
    "Home page should render the access code gate before entry";
  let proxy =
    request_handler app ~meth:`GET ~target:"/proxy/me" ()
  in
  assert_status `Forbidden proxy

let test_web_access_gate_rejects_fake_cookie_and_accepts_real_one () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let fake_cookie =
    request_handler app ~meth:`GET ~target:"/proxy/me"
      ~headers:[ ("Cookie", "recognita_gate=fakevalue") ]
      ()
  in
  assert_status `Forbidden fake_cookie;
  let granted =
    request_handler app ~meth:`POST ~target:"/access"
      ~headers:[ ("Content-Type", "application/x-www-form-urlencoded") ]
      ~body:"code=pezarski&return_to=%2Fverify%3Ftoken%3Dabc"
      ()
  in
  assert_status `See_Other granted;
  let gate_cookie = web_cookie_from_response granted in
  let verify =
    request_handler app ~meth:`GET ~target:"/verify?token=abc"
      ~headers:[ ("Cookie", gate_cookie) ]
      ()
  in
  assert_status `OK verify;
  let verify_body = response_body verify in
  assert_true
    (contains_substring ~needle:"Verify your email" verify_body)
    "Verified access should unlock the main application page"

let test_web_access_gate_supports_mailpit_return_and_internal_check () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let denied_check =
    request_handler app ~meth:`GET ~target:"/_recognita/access-check" ()
  in
  assert_status `Unauthorized denied_check;
  let mailpit_gate =
    request_handler app ~meth:`GET ~target:"/_recognita/access-gate"
      ~headers:[ ("X-Recognita-Return-To", "/mailpit/messages") ]
      ()
  in
  assert_status `OK mailpit_gate;
  let mailpit_gate_body = response_body mailpit_gate in
  assert_true
    (contains_substring
       ~needle:"name=\"return_to\" value=\"/mailpit/messages\""
       mailpit_gate_body)
    "Internal gate page should preserve the Mailpit return path";
  let granted =
    request_handler app ~meth:`POST ~target:"/access"
      ~headers:[ ("Content-Type", "application/x-www-form-urlencoded") ]
      ~body:"code=pezarski&return_to=%2Fmailpit%2Fmessages"
      ()
  in
  assert_status `See_Other granted;
  assert_true
    (Dream.header granted "location" = Some "/mailpit/messages")
    "Access gate should return to the requested Mailpit subpage";
  let gate_cookie = web_cookie_from_response granted in
  let allowed_check =
    request_handler app ~meth:`GET ~target:"/_recognita/access-check"
      ~headers:[ ("Cookie", gate_cookie) ]
      ()
  in
  assert_status `No_Content allowed_check

let make_admin_cli_fixture () =
  let config = base_config () in
  let repo = Toolkit.In_memory_repo.make () in
  let clock_ref = ref 1_700_000_000. in
  let clock = Toolkit.Clock.make (fun () -> !clock_ref) in
  let prepared =
    Lwt_main.run (Toolkit.Admin_cli.prepare ~repo ~clock ~config)
  in
  ignore (unwrap_ok prepared);
  (repo, clock)

let test_admin_cli_lists_users_with_emails () =
  let repo, clock = make_admin_cli_fixture () in
  let created =
    Lwt_main.run
      (repo.create_user ~username:"zoe"
         ~email:"zoe@example.com"
         ~password_hash:(Toolkit.Password.make "password123")
         ~role:Toolkit.Domain.User ~created_at:(clock.now ()))
  in
  ignore (unwrap_repo_ok created);
  let outcome =
    Lwt_main.run
      (Toolkit.Admin_cli.perform ~repo ~clock Toolkit.Admin_cli.List_users)
    |> unwrap_ok
  in
  let rendered = Toolkit.Admin_cli.render outcome in
  assert_true
    (String.contains rendered '@')
    "Rendered admin CLI user list should include email addresses";
  match outcome with
  | Toolkit.Admin_cli.Users_listed users ->
      assert_true
        (List.exists
           (fun (user : Toolkit.Domain.public_user) ->
             user.username = "zoe" && user.email = "zoe@example.com")
           users)
        "Admin CLI list should include the created user with email"
  | Toolkit.Admin_cli.User_banned _
  | Toolkit.Admin_cli.Recent_submissions_listed _
  | Toolkit.Admin_cli.User_promoted_to_admin _ ->
      fail "Admin CLI list returned the wrong outcome variant"

let test_admin_cli_ban_revokes_sessions () =
  let repo, clock = make_admin_cli_fixture () in
  let created_user =
    Lwt_main.run
      (repo.create_user ~username:"mia"
         ~email:"mia@example.com"
         ~password_hash:(Toolkit.Password.make "password123")
         ~role:Toolkit.Domain.User ~created_at:(clock.now ()))
    |> unwrap_repo_ok
  in
  let created_session =
    Lwt_main.run
      (repo.create_session ~user_id:created_user.id
         ~access_token:"access-token" ~refresh_token:"refresh-token"
         ~access_expires_at:(clock.now () +. 300.)
         ~refresh_expires_at:(clock.now () +. 600.) ~created_at:(clock.now ()))
    |> unwrap_repo_ok
  in
  ignore created_session;
  let outcome =
    Lwt_main.run
      (Toolkit.Admin_cli.perform ~repo ~clock
         (Toolkit.Admin_cli.Ban_user
            {
              user_id = created_user.id;
              reason = Some "manual moderation";
            }))
    |> unwrap_ok
  in
  begin
    match outcome with
    | Toolkit.Admin_cli.User_banned user ->
        assert_true user.is_banned "Admin CLI should mark the user as banned";
        assert_true
          (user.ban_reason = Some "manual moderation")
          "Admin CLI should persist the ban reason"
    | Toolkit.Admin_cli.Users_listed _
    | Toolkit.Admin_cli.Recent_submissions_listed _
    | Toolkit.Admin_cli.User_promoted_to_admin _ ->
        fail "Admin CLI ban returned the wrong outcome variant"
  end;
  let stored_session =
    Lwt_main.run
      (repo.find_session_by_access_token "access-token")
    |> unwrap_repo_ok
  in
  match stored_session with
  | Some session ->
      assert_true
        (session.revoked_at <> None)
        "Admin CLI ban should revoke active sessions"
  | None -> fail "Expected session to remain queryable after revocation"

let test_admin_cli_promotes_user_to_admin () =
  let repo, clock = make_admin_cli_fixture () in
  let created_user =
    Lwt_main.run
      (repo.create_user ~username:"nina"
         ~email:"nina@example.com"
         ~password_hash:(Toolkit.Password.make "password123")
         ~role:Toolkit.Domain.User ~created_at:(clock.now ()))
    |> unwrap_repo_ok
  in
  let outcome =
    Lwt_main.run
      (Toolkit.Admin_cli.perform ~repo ~clock
         (Toolkit.Admin_cli.Promote_admin { user_id = created_user.id }))
    |> unwrap_ok
  in
  match outcome with
  | Toolkit.Admin_cli.User_promoted_to_admin user ->
      assert_true
        (user.role = Toolkit.Domain.Admin)
        "Admin CLI should set the admin role";
      assert_true user.verified "Promoted admin should be marked verified"
  | Toolkit.Admin_cli.Users_listed _
  | Toolkit.Admin_cli.Recent_submissions_listed _
  | Toolkit.Admin_cli.User_banned _ ->
      fail "Admin CLI promote returned the wrong outcome variant"

let test_caqti_repo_user_roundtrip () =
  with_postgres_repo (fun repo clock ->
      let now = clock.now () in
      let created_user =
        repo.create_user ~username:"db_zoe" ~email:"db_zoe@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.User ~created_at:now
      in
      let created_user = Lwt.map unwrap_repo_ok created_user in
      let* created_user = created_user in
      let* found_by_username = repo.find_user_by_username "db_zoe" in
      let found_by_username = unwrap_repo_ok found_by_username in
      let* found_by_email = repo.find_user_by_email "db_zoe@example.com" in
      let found_by_email = unwrap_repo_ok found_by_email in
      let* created_session =
        repo.create_session ~user_id:created_user.id ~access_token:"db-access"
          ~refresh_token:"db-refresh" ~access_expires_at:(now +. 300.)
          ~refresh_expires_at:(now +. 600.) ~created_at:now
      in
      let created_session = unwrap_repo_ok created_session in
      let* found_session = repo.find_session_by_access_token "db-access" in
      let found_session = unwrap_repo_ok found_session in
      assert_true
        (Option.map
           (fun (user : Toolkit.Domain.user) -> user.id)
           found_by_username
        = Some created_user.id)
        "Caqti repo should find the created user by username";
      assert_true
        (Option.map
           (fun (user : Toolkit.Domain.user) -> user.id)
           found_by_email
        = Some created_user.id)
        "Caqti repo should find the created user by email";
      assert_true
        (Option.map
           (fun (session : Toolkit.Domain.session) -> session.id)
           found_session
        = Some created_session.id)
        "Caqti repo should find the created session by access token";
      Lwt.return_unit)

let test_caqti_repo_task_and_submission_roundtrip () =
  with_postgres_repo (fun repo clock ->
      let now = clock.now () in
      let* author =
        repo.create_user ~username:"db_author"
          ~email:"db_author@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.Admin ~created_at:now
      in
      let author = unwrap_repo_ok author in
      let* submitter =
        repo.create_user ~username:"db_submitter"
          ~email:"db_submitter@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.User ~created_at:(now +. 1.)
      in
      let submitter = unwrap_repo_ok submitter in
      let config =
        model_construction_config ()
      in
      let* task =
        repo.create_task ~title:"Database task" ~slug:(Some "database-task")
          ~short_description:(Some "Short description")
          ~description:"Task body"
          ~type_:Toolkit.Domain.Model_construction ~author_id:author.id
          ~difficulty:4 ~config ~status:Toolkit.Domain.Published
          ~visibility:Toolkit.Domain.Public ~published_at:(Some now)
          ~created_at:now ~updated_at:now
      in
      let task = unwrap_repo_ok task in
      let* found_task = repo.find_task_by_slug "database-task" in
      let found_task = unwrap_repo_ok found_task in
      let* listed_tasks = repo.list_tasks () in
      let listed_tasks = unwrap_repo_ok listed_tasks in
      let* submission =
        repo.create_submission ~task_id:task.id ~user_id:submitter.id
          ~data:(valid_nfa_submission_data ())
          ~created_at:(now +. 2.)
      in
      let submission = unwrap_repo_ok submission in
      let* listed_submissions = repo.list_submissions_by_user ~user_id:submitter.id in
      let listed_submissions = unwrap_repo_ok listed_submissions in
      let* updated_submission =
        repo.update_submission_result ~submission_id:submission.id
          ~verdict:Toolkit.Domain.Accepted
          ~run_data:
            (Some (`Assoc [ ("score", `Int 100); ("worker", `String "test") ]))
          ~judged_at:(now +. 3.)
      in
      let updated_submission = unwrap_repo_ok updated_submission in
      assert_true
        (Option.map
           (fun (current : Toolkit.Domain.task) -> current.id)
           found_task
        = Some task.id)
        "Caqti repo should find the created task by slug";
      assert_true
        (List.exists
           (fun (current : Toolkit.Domain.task) -> current.id = task.id)
           listed_tasks)
        "Caqti repo should list the created task";
      assert_true
        (List.exists
           (fun (current : Toolkit.Domain.submission) -> current.id = submission.id)
           listed_submissions)
        "Caqti repo should list the created submission for the user";
      begin
        match updated_submission with
        | Some current ->
            assert_true
              (current.verdict = Toolkit.Domain.Accepted)
              "Caqti repo should update the submission verdict";
            assert_true
              (current.judged_at <> None)
              "Caqti repo should set judged_at on updated submissions"
        | None -> fail "Expected updated submission to be returned"
      end;
      Lwt.return_unit)

let test_caqti_repo_delete_user_cascades () =
  with_postgres_repo (fun repo clock ->
      let now = clock.now () in
      let* author =
        repo.create_user ~username:"db_cascade_author"
          ~email:"db_cascade_author@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.Admin ~created_at:now
      in
      let author = unwrap_repo_ok author in
      let* submitter =
        repo.create_user ~username:"db_cascade_submitter"
          ~email:"db_cascade_submitter@example.com"
          ~password_hash:(Toolkit.Password.make "password123")
          ~role:Toolkit.Domain.User ~created_at:(now +. 1.)
      in
      let submitter = unwrap_repo_ok submitter in
      let* task =
        repo.create_task ~title:"Cascade task" ~slug:(Some "cascade-task")
          ~short_description:None ~description:"Cascade task body"
          ~type_:Toolkit.Domain.Model_construction ~author_id:author.id
          ~difficulty:2
          ~config:(model_construction_config ())
          ~status:Toolkit.Domain.Published ~visibility:Toolkit.Domain.Public
          ~published_at:(Some now) ~created_at:now ~updated_at:now
      in
      let task = unwrap_repo_ok task in
      let* submission =
        repo.create_submission ~task_id:task.id ~user_id:submitter.id
          ~data:(valid_nfa_submission_data ()) ~created_at:(now +. 2.)
      in
      let submission = unwrap_repo_ok submission in
      let* deleted_user = repo.delete_user ~user_id:author.id in
      let deleted_user = unwrap_repo_ok deleted_user in
      let* found_task = repo.find_task_by_id task.id in
      let found_task = unwrap_repo_ok found_task in
      let* found_submission = repo.find_submission_by_id submission.id in
      let found_submission = unwrap_repo_ok found_submission in
      assert_true
        (Option.map
           (fun (user : Toolkit.Domain.user) -> user.id)
           deleted_user
        = Some author.id)
        "Caqti repo should return the deleted author";
      assert_true
        (found_task = None)
        "Deleting the task author should cascade-delete owned tasks";
      assert_true
        (found_submission = None)
        "Deleting the task author should cascade-delete submissions under owned tasks";
      Lwt.return_unit)

let test_startup_bootstraps_admin_user () =
  let config =
    {
      (base_config ()) with
      Toolkit.Config.recognita_admin_username = Some "recognita_admin";
      recognita_admin_password = Some "RecognitaAdmin123!";
    }
  in
  let repo = Toolkit.In_memory_repo.make () in
  let clock = Toolkit.Clock.make (fun () -> 1_700_000_000.) in
  let prepared = Lwt_main.run (repo.init_schema ()) |> unwrap_repo_ok in
  ignore prepared;
  let result =
    Lwt_main.run (Toolkit.Startup.ensure_bootstrap_admin repo clock config)
    |> unwrap_result Toolkit.App_error.message
  in
  ignore result;
  let created =
    Lwt_main.run (repo.find_user_by_username "recognita_admin") |> unwrap_repo_ok
  in
  match created with
  | Some user ->
      assert_true
        (user.role = Toolkit.Domain.Admin)
        "Bootstrap admin should be an admin";
      assert_true user.verified "Bootstrap admin should be verified";
      assert_true
        (user.email = "no-reply@recognita.xyz")
        "Bootstrap admin should use the no-reply email";
      assert_true
        (Toolkit.Password.verify ~expected:user.password_hash "RecognitaAdmin123!")
        "Bootstrap admin password hash should match the configured secret"
  | None -> fail "Expected bootstrap admin to be created"

let test_startup_refreshes_existing_bootstrap_admin () =
  let config =
    {
      (base_config ()) with
      Toolkit.Config.recognita_admin_username = Some "recognita_admin";
      recognita_admin_password = Some "RecognitaAdmin456!";
      mail_from = "no-reply@bootstrap.test";
    }
  in
  let repo = Toolkit.In_memory_repo.make () in
  let clock = Toolkit.Clock.make (fun () -> 1_700_000_100.) in
  let prepared = Lwt_main.run (repo.init_schema ()) |> unwrap_repo_ok in
  ignore prepared;
  let existing =
    Lwt_main.run
      (repo.create_user ~username:"recognita_admin"
         ~email:"old@example.com"
         ~password_hash:(Toolkit.Password.make "old-password")
         ~role:Toolkit.Domain.User ~created_at:1_700_000_000.)
    |> unwrap_repo_ok
  in
  let banned =
    Lwt_main.run
      (repo.update_ban ~user_id:existing.id ~is_banned:true
         ~ban_reason:(Some "old state") ~updated_at:1_700_000_050.)
    |> unwrap_repo_ok
  in
  ignore banned;
  let result =
    Lwt_main.run (Toolkit.Startup.ensure_bootstrap_admin repo clock config)
    |> unwrap_result Toolkit.App_error.message
  in
  ignore result;
  let refreshed =
    Lwt_main.run (repo.find_user_by_username "recognita_admin") |> unwrap_repo_ok
  in
  match refreshed with
  | Some user ->
      assert_true
        (user.role = Toolkit.Domain.Admin)
        "Existing bootstrap admin should be promoted to admin";
      assert_true user.verified "Existing bootstrap admin should be verified";
      assert_true
        (not user.is_banned)
        "Existing bootstrap admin should be unbanned";
      assert_true
        (user.email = "no-reply@bootstrap.test")
        "Existing bootstrap admin email should be refreshed from MAIL_FROM";
      assert_true
        (Toolkit.Password.verify ~expected:user.password_hash "RecognitaAdmin456!")
        "Existing bootstrap admin password hash should be refreshed"
  | None -> fail "Expected bootstrap admin to remain present"

let tests =
  [
    ("register_and_me", test_register_and_me);
    ( "register_sends_verification_email_and_verify_endpoint",
      test_register_sends_verification_email_and_verify_endpoint );
    ("login_and_logout", test_login_and_logout);
    ("delete_own_account", test_user_can_delete_own_account);
    ( "delete_user_cascades_owned_tasks_and_submissions",
      test_delete_user_cascades_owned_tasks_and_submissions );
    ("refresh_rotates_tokens", test_refresh_rotates_tokens);
    ("admin_lists_and_moderates_users", test_admin_lists_and_moderates_users);
    ("non_admin_cannot_moderate", test_non_admin_cannot_moderate);
    ("rate_limit_blocks_auth_endpoint", test_rate_limit_blocks_auth_endpoint);
    ("health_and_openapi", test_health_and_openapi);
    ( "admin_creates_task_and_public_list_exposes_it",
      test_admin_creates_task_and_public_list_exposes_it );
    ( "submission_is_created_pending_and_worker_judges_it",
      test_submission_is_created_pending_and_worker_judges_it );
    ( "submission_rejects_invalid_nfa_payload",
      test_submission_rejects_invalid_nfa_payload );
    ("task_config_template_endpoint", test_task_config_template_endpoint);
    ( "task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug",
      test_task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug );
    ("submissions_scope_mine_vs_all", test_submissions_scope_mine_vs_all);
    ( "web_requires_access_code_for_html_and_proxy",
      test_web_requires_access_code_for_html_and_proxy );
    ( "web_access_gate_rejects_fake_cookie_and_accepts_real_one",
      test_web_access_gate_rejects_fake_cookie_and_accepts_real_one );
    ( "web_access_gate_supports_mailpit_return_and_internal_check",
      test_web_access_gate_supports_mailpit_return_and_internal_check );
    ("admin_cli_lists_users_with_emails", test_admin_cli_lists_users_with_emails);
    ("admin_cli_ban_revokes_sessions", test_admin_cli_ban_revokes_sessions);
    ("admin_cli_promotes_user_to_admin", test_admin_cli_promotes_user_to_admin);
    ("startup_bootstraps_admin_user", test_startup_bootstraps_admin_user);
    ( "startup_refreshes_existing_bootstrap_admin",
      test_startup_refreshes_existing_bootstrap_admin );
  ]

let integration_tests =
  [
    ("caqti_repo_user_roundtrip", test_caqti_repo_user_roundtrip);
    ( "caqti_repo_task_and_submission_roundtrip",
      test_caqti_repo_task_and_submission_roundtrip );
    ("caqti_repo_delete_user_cascades", test_caqti_repo_delete_user_cascades);
  ]

let run_test (name, fn) =
  try
    fn ();
    Printf.printf "PASS %s\n%!" name;
    true
  with
  | Test_failure message ->
      Printf.printf "FAIL %s: %s\n%!" name message;
      false
  | exn ->
      Printf.printf "FAIL %s: unexpected exception: %s\n%!" name
        (Printexc.to_string exn);
      false

let () =
  if not (db_integration_enabled ()) then
    Printf.printf "SKIP db integration tests (set RUN_DB_INTEGRATION_TESTS=1)\n%!";
  let selected_tests =
    if db_integration_enabled () then tests @ integration_tests else tests
  in
  let results = List.map run_test selected_tests in
  if List.for_all (fun passed -> passed) results then
    ()
  else
    exit 1
