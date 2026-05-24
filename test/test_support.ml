open Yojson.Basic.Util

let ( let* ) = Lwt.bind

exception Test_failure of string

type test_case = string * (unit -> unit)

type fixture = {
  app : Dream.handler;
  repo : Toolkit.Repository.t;
  clock : Toolkit.Clock.t;
  sent_emails : Toolkit.Verification_mailer.sent_mail list ref;
  submission_queue : Toolkit.Submission_queue.t;
}

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

let unwrap_result map_error = function
  | Ok value -> value
  | Error error -> fail (map_error error)

let unwrap_ok result = unwrap_result (fun message -> message) result

let unwrap_repo_ok result =
  unwrap_result Toolkit.Repository.error_message result

let model_construction_config ?(required_model_type = "NFA")
    ?(grader = `Assoc [ ("kind", `String "mock") ]) () =
  `Assoc
    [
      ("grader", grader);
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

let valid_cfg_submission_data
    ?(non_terminals = [ "S"; "A" ])
    ?(terminals = [ "a"; "b" ])
    ?(transitions =
      [
        `Assoc
          [
            ("from", `String "S");
            ("to", `List [ `String "A"; `String "b" ]);
          ];
        `Assoc [ ("from", `String "A"); ("to", `List [ `String "a" ]) ];
        `Assoc [ ("from", `String "A"); ("to", `List []) ];
      ])
    ?(start_symbol = "S") () =
  `Assoc
    [
      ("type", `String "CFG");
      ( "model",
        `Assoc
          [
            ( "nonTerminals",
              `List (List.map (fun value -> `String value) non_terminals) );
            ("terminals", `List (List.map (fun value -> `String value) terminals));
            ("transitions", `List transitions);
            ("startSymbol", `String start_symbol);
          ] );
    ]

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
    ?(config = model_construction_config ())
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
  match
    Uri.get_query_param
      (Uri.of_string mail.Toolkit.Verification_mailer.verification_url)
      "token"
  with
  | Some token -> token
  | None -> fail "Verification email is missing the token query parameter"

let web_config () : Toolkit.Web_config.t =
  {
    mode = Toolkit.Runtime_mode.Local;
    host = "127.0.0.1";
    port = 8081;
    api_base_url = "http://127.0.0.1:8080";
    site_name = "Recognita";
    admin_panel_dist_dir = "src/admin-panel/dist";
  }

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
