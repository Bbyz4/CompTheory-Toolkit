let ( let* ) = Lwt.bind

type with_repo =
  Dream.request -> (Repository.t -> Dream.response Lwt.t) -> Dream.response Lwt.t

type t = {
  config : Config.t;
  clock : Clock.t;
  rate_limiter : Rate_limiter.t;
  mailer : Verification_mailer.t;
  submission_queue : Submission_queue.t;
  with_repo : with_repo;
}

let json_headers = [ ("content-type", "application/json; charset=utf-8") ]

let status_json status message =
  `Assoc [ ("status", `String status); ("message", `String message) ]

let error_json app_error =
  `Assoc
    [
      ( "error",
        `Assoc
          [
            ("status", `Int (App_error.status app_error));
            ("message", `String (App_error.message app_error));
          ] );
    ]

let json_response ?(headers = []) ~code payload =
  Dream.respond ~code ~headers:(json_headers @ headers)
    (Yojson.Basic.to_string payload)

let error_response ?(headers = []) app_error =
  json_response ~headers ~code:(App_error.status app_error) (error_json app_error)

let auth_response_json (response : Auth_service.auth_response) =
  `Assoc
    [
      ("user", Domain.public_user_to_yojson response.Auth_service.user);
      ("tokens", Domain.auth_tokens_to_yojson response.tokens);
    ]

let users_json users =
  `Assoc
    [
      ( "users",
        `List (List.map Domain.public_user_to_yojson users) );
    ]

let user_json user = `Assoc [ ("user", Domain.public_user_to_yojson user) ]

let tasks_json tasks =
  `Assoc [ ("tasks", `List (List.map Domain.task_to_yojson tasks)) ]

let task_payload_json task =
  let base_fields =
    match Domain.task_to_yojson task with
    | `Assoc fields -> fields
    | _ -> []
  in
  let fields =
    match Task_config.validate_task_config ~task_type:task.type_ task.config with
    | Ok normalized_config ->
        ( "submission_template",
          Task_config.submission_template_json ~task_type:task.type_
            ~config:normalized_config )
        :: ( "submission_example",
             Task_config.submission_example_json ~task_type:task.type_
               ~config:normalized_config )
        :: base_fields
    | Error _ -> base_fields
  in
  `Assoc fields

let task_json task = `Assoc [ ("task", task_payload_json task) ]

let submission_json submission =
  `Assoc [ ("submission", Domain.submission_to_yojson submission) ]

let submissions_json submissions =
  `Assoc
    [
      ( "submissions",
        `List (List.map Domain.submission_to_yojson submissions) );
    ]

let task_config_template_json task_type =
  let config_template = Task_config.config_template_json task_type in
  `Assoc
    [
      ("task_type", `String (Domain.task_type_to_string task_type));
      ("config_template", config_template);
      ( "submission_template",
        Task_config.submission_template_json ~task_type ~config:config_template );
      ( "submission_example",
        Task_config.submission_example_json ~task_type ~config:config_template );
    ]

let parse_body request =
  let* body = Dream.body request in
  match Json_utils.parse body with
  | Ok json -> Lwt.return (Ok json)
  | Error app_error -> Lwt.return (Error app_error)

let first_value = function [] -> None | value :: _ -> Some value

let query_value request name =
  match Dream.target request |> Uri.of_string |> Uri.query |> List.assoc_opt name with
  | Some values -> first_value values
  | None -> None

let access_token_from_request request =
  match Dream.header request "authorization" with
  | Some value when Util.starts_with ~prefix:"Bearer " value ->
      Ok (String.sub value 7 (String.length value - 7))
  | _ -> Error (App_error.Unauthorized "Missing bearer access token")

let deps repo app : Auth_service.deps =
  { repo; clock = app.clock; config = app.config; mailer = app.mailer }

let with_deps app request fn = app.with_repo request (fun repo -> fn (deps repo app))

let task_deps repo app : Task_service.deps =
  { repo; clock = app.clock; queue = app.submission_queue }

let with_task_deps app request fn =
  app.with_repo request (fun repo -> fn (task_deps repo app))

let optional_access_token_from_request request =
  match Dream.header request "authorization" with
  | Some value when Util.starts_with ~prefix:"Bearer " value ->
      Some (String.sub value 7 (String.length value - 7))
  | _ -> None

let optional_context auth_deps request =
  match optional_access_token_from_request request with
  | None -> Lwt.return (Ok None)
  | Some access_token ->
      let* result = Auth_service.authenticate_access_token auth_deps access_token in
      match result with
      | Ok context -> Lwt.return (Ok (Some context))
      | Error _ -> Lwt.return (Ok None)

let task_type_from_json json =
  match Json_utils.string_field json "type" with
  | Error app_error -> Error app_error
  | Ok value -> (
      match Domain.task_type_of_string value with
      | Some task_type -> Ok task_type
      | None -> Error (App_error.Bad_request "Unknown task type"))

let task_status_from_json json =
  match Json_utils.optional_string_field json "status" with
  | Error app_error -> Error app_error
  | Ok None -> Ok Domain.Draft
  | Ok (Some value) -> (
      match Domain.task_status_of_string value with
      | Some status -> Ok status
      | None -> Error (App_error.Bad_request "Unknown task status"))

let task_visibility_from_json json =
  match Json_utils.optional_string_field json "visibility" with
  | Error app_error -> Error app_error
  | Ok None -> Ok Domain.Private
  | Ok (Some value) -> (
      match Domain.task_visibility_of_string value with
      | Some visibility -> Ok visibility
      | None -> Error (App_error.Bad_request "Unknown task visibility"))

let submission_scope_from_request request =
  match query_value request "scope" with
  | Some "all" -> Task_service.All
  | Some "mine" | None -> Task_service.Mine
  | Some _ -> Task_service.Mine

let ratelimit_headers (decision : Rate_limiter.decision) =
  [
    ("x-ratelimit-limit", string_of_int decision.limit);
    ("x-ratelimit-remaining", string_of_int decision.remaining);
    ("x-ratelimit-reset", Util.iso8601_of_unix_time decision.reset_at);
  ]

let client_key app request =
  let client =
    match app.config.mode, Dream.header request "x-recognita-test-client" with
    | Runtime_mode.Local, Some value when String.trim value <> "" -> value
    | _ -> Dream.client request
  in
  match Util.split_once ~on:':' client with Some (host, _port) -> host | None -> client

let rate_limit_middleware app inner request =
  let path = Dream.target request |> Util.strip_query in
  if path = "/health" || path = "/openapi.json" then
    inner request
  else
    let decision =
      Rate_limiter.check app.rate_limiter ~key:(client_key app request) ~path
    in
    let headers = ratelimit_headers decision in
    if not decision.allowed then
      error_response ~headers
        (App_error.Too_many_requests "Rate limit exceeded, retry later")
    else
      let* response = inner request in
      List.iter
        (fun (name, value) -> Dream.set_header response name value)
        headers;
      Lwt.return response

let make app =
  let openapi_spec = Openapi.load app.config.openapi_path in
  let handle_register request =
    with_deps app request (fun deps ->
        let* json_result = parse_body request in
        match json_result with
        | Error app_error -> error_response app_error
        | Ok json -> (
            match
              Json_utils.assoc_list json,
              Json_utils.string_field json "username",
              Json_utils.string_field json "email",
              Json_utils.string_field json "password"
            with
            | Ok _, Ok username, Ok email, Ok password -> (
                let* result =
                  Auth_service.register deps ~username ~email ~password
                in
                match result with
                | Ok response ->
                    json_response ~code:201 (auth_response_json response)
                | Error app_error -> error_response app_error)
            | Error app_error, _, _, _
            | _, Error app_error, _, _
            | _, _, Error app_error, _
            | _, _, _, Error app_error ->
                error_response app_error))
  in
  let handle_login request =
    with_deps app request (fun deps ->
        let* json_result = parse_body request in
        match json_result with
        | Error app_error -> error_response app_error
        | Ok json -> (
            match
              Json_utils.assoc_list json,
              Json_utils.string_field json "username",
              Json_utils.string_field json "password"
            with
            | Ok _, Ok username, Ok password -> (
                let* result = Auth_service.login deps ~username ~password in
                match result with
                | Ok response -> json_response ~code:200 (auth_response_json response)
                | Error app_error -> error_response app_error)
            | Error app_error, _, _
            | _, Error app_error, _
            | _, _, Error app_error ->
                error_response app_error))
  in
  let handle_refresh request =
    with_deps app request (fun deps ->
        let* json_result = parse_body request in
        match json_result with
        | Error app_error -> error_response app_error
        | Ok json -> (
            match
              Json_utils.assoc_list json,
              Json_utils.string_field json "refresh_token"
            with
            | Ok _, Ok refresh_token -> (
                let* result = Auth_service.refresh deps ~refresh_token in
                match result with
                | Ok response -> json_response ~code:200 (auth_response_json response)
                | Error app_error -> error_response app_error)
            | Error app_error, _ | _, Error app_error -> error_response app_error))
  in
  let handle_logout request =
    with_deps app request (fun deps ->
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let* result = Auth_service.logout deps ~access_token in
            match result with
            | Ok () -> json_response ~code:200 (status_json "ok" "Logged out")
            | Error app_error -> error_response app_error))
  in
  let handle_verify_email request =
    with_deps app request (fun deps ->
        let* json_result = parse_body request in
        match json_result with
        | Error app_error -> error_response app_error
        | Ok json -> (
            match Json_utils.assoc_list json, Json_utils.string_field json "token" with
            | Ok _, Ok token -> (
                let* result = Auth_service.verify_email deps ~token in
                match result with
                | Ok user -> json_response ~code:200 (user_json user)
                | Error app_error -> error_response app_error)
            | Error app_error, _ | _, Error app_error ->
                error_response app_error))
  in
  let handle_me request =
    with_deps app request (fun deps ->
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let* result = Auth_service.current_user deps ~access_token in
            match result with
            | Ok user -> json_response ~code:200 (user_json user)
            | Error app_error -> error_response app_error))
  in
  let handle_delete_me request =
    with_deps app request (fun deps ->
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let* result =
              Auth_service.delete_current_user deps ~access_token
            in
            match result with
            | Ok user -> json_response ~code:200 (user_json user)
            | Error app_error -> error_response app_error))
  in
  let handle_users request =
    with_deps app request (fun deps ->
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let* result = Auth_service.list_users deps ~access_token in
            match result with
            | Ok users -> json_response ~code:200 (users_json users)
            | Error app_error -> error_response app_error))
  in
  let handle_ban request =
    with_deps app request (fun deps ->
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let user_id_result = int_of_string_opt (Dream.param request "id") in
            let* body = Dream.body request in
            let reason_result =
              match user_id_result, String.trim body with
              | None, _ -> Error (App_error.Bad_request "User id must be an integer")
              | Some _, "" -> Ok None
              | Some _, _ -> (
                  match Json_utils.parse body with
                  | Error app_error -> Error app_error
                  | Ok json -> Json_utils.optional_string_field json "reason")
            in
            match reason_result with
            | Error app_error -> error_response app_error
            | Ok _reason when user_id_result = None ->
                error_response (App_error.Bad_request "User id must be an integer")
            | Ok reason -> (
                let user_id =
                  match user_id_result with
                  | Some value -> value
                  | None -> failwith "validated above"
                in
                let* result =
                  Auth_service.set_ban deps ~access_token ~user_id ~is_banned:true
                    ~ban_reason:reason
                in
                match result with
                | Ok user -> json_response ~code:200 (user_json user)
                | Error app_error -> error_response app_error)))
  in
  let handle_unban request =
    with_deps app request (fun deps ->
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            match int_of_string_opt (Dream.param request "id") with
            | None -> error_response (App_error.Bad_request "User id must be an integer")
            | Some user_id -> (
                let* result =
                  Auth_service.set_ban deps ~access_token ~user_id
                    ~is_banned:false ~ban_reason:None
                in
                match result with
                | Ok user -> json_response ~code:200 (user_json user)
                | Error app_error -> error_response app_error)))
  in
  let handle_tasks request =
    with_task_deps app request (fun task_deps ->
        let* result = Task_service.list_public_tasks task_deps in
        match result with
        | Ok tasks -> json_response ~code:200 (tasks_json tasks)
        | Error app_error -> error_response app_error)
  in
  let handle_task request =
    app.with_repo request (fun repo ->
        let auth_deps = deps repo app in
        let current_task_deps = task_deps repo app in
        match int_of_string_opt (Dream.param request "id") with
        | None -> error_response (App_error.Bad_request "Task id must be an integer")
        | Some task_id ->
            let* viewer_result = optional_context auth_deps request in
            begin
              match viewer_result with
              | Error app_error -> error_response app_error
              | Ok viewer -> (
                  let* result =
                    Task_service.get_task current_task_deps ~viewer ~task_id
                  in
                  match result with
                  | Ok task -> json_response ~code:200 (task_json task)
                  | Error app_error -> error_response app_error)
            end)
  in
  let handle_task_by_slug request =
    app.with_repo request (fun repo ->
        let auth_deps = deps repo app in
        let current_task_deps = task_deps repo app in
        let* viewer_result = optional_context auth_deps request in
        begin
          match viewer_result with
          | Error app_error -> error_response app_error
          | Ok viewer -> (
              let* result =
                Task_service.get_task_by_slug current_task_deps ~viewer
                  ~slug:(Dream.param request "slug")
              in
              match result with
              | Ok task -> json_response ~code:200 (task_json task)
              | Error app_error -> error_response app_error)
        end)
  in
  let handle_create_task request =
    app.with_repo request (fun repo ->
        let auth_deps = deps repo app in
        let current_task_deps = task_deps repo app in
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let* admin_result = Auth_service.ensure_admin auth_deps ~access_token in
            match admin_result with
            | Error app_error -> error_response app_error
            | Ok admin_context ->
                let* json_result = parse_body request in
                match json_result with
                | Error app_error -> error_response app_error
                | Ok json -> (
                    match
                      Json_utils.assoc_list json,
                      Json_utils.string_field json "title",
                      Json_utils.optional_string_field json "slug",
                      Json_utils.optional_string_field json "short_description",
                      Json_utils.string_field json "description",
                      task_type_from_json json,
                      Json_utils.optional_int_field json "author_id",
                      Json_utils.int_field json "difficulty",
                      Json_utils.object_field json "config",
                      task_status_from_json json,
                      task_visibility_from_json json
                    with
                    | Ok _, Ok title, Ok slug, Ok short_description, Ok description, Ok type_, Ok author_id, Ok difficulty, Ok config, Ok status, Ok visibility -> (
                        let* result =
                          Task_service.create_task current_task_deps
                            ~admin_context ~title ~slug ~short_description
                            ~description ~type_ ?author_id ~difficulty ~config ~status
                            ~visibility ()
                        in
                        match result with
                        | Ok task -> json_response ~code:201 (task_json task)
                        | Error app_error -> error_response app_error)
                    | Error app_error, _, _, _, _, _, _, _, _, _, _
                    | _, Error app_error, _, _, _, _, _, _, _, _, _
                    | _, _, Error app_error, _, _, _, _, _, _, _, _
                    | _, _, _, Error app_error, _, _, _, _, _, _, _
                    | _, _, _, _, Error app_error, _, _, _, _, _, _
                    | _, _, _, _, _, Error app_error, _, _, _, _, _
                    | _, _, _, _, _, _, Error app_error, _, _, _, _
                    | _, _, _, _, _, _, _, Error app_error, _, _, _
                    | _, _, _, _, _, _, _, _, Error app_error, _, _
                    | _, _, _, _, _, _, _, _, _, Error app_error, _
                    | _, _, _, _, _, _, _, _, _, _, Error app_error ->
                        error_response app_error)))
  in
  let handle_task_config_template request =
    match Domain.task_type_of_string (Dream.param request "type") with
    | None -> error_response (App_error.Bad_request "Unknown task type")
    | Some task_type ->
        json_response ~code:200 (task_config_template_json task_type)
  in
  let handle_create_submission request =
    app.with_repo request (fun repo ->
        let auth_deps = deps repo app in
        let current_task_deps = task_deps repo app in
        match access_token_from_request request, int_of_string_opt (Dream.param request "id") with
        | Error app_error, _ -> error_response app_error
        | _, None ->
            error_response (App_error.Bad_request "Task id must be an integer")
        | Ok access_token, Some task_id -> (
            let* context_result =
              Auth_service.authenticate_access_token auth_deps access_token
            in
            match context_result with
            | Error app_error -> error_response app_error
            | Ok context ->
                let* json_result = parse_body request in
                match json_result with
                | Error app_error -> error_response app_error
                | Ok json -> (
                    match Json_utils.assoc_list json, Json_utils.object_field json "data" with
                    | Ok _, Ok data -> (
                        let* result =
                          Task_service.create_submission current_task_deps
                            ~context ~task_id ~data
                        in
                        match result with
                        | Ok submission ->
                            json_response ~code:201 (submission_json submission)
                        | Error app_error -> error_response app_error)
                    | Error app_error, _ | _, Error app_error ->
                        error_response app_error)))
  in
  let handle_submission request =
    app.with_repo request (fun repo ->
        let auth_deps = deps repo app in
        let current_task_deps = task_deps repo app in
        match access_token_from_request request, int_of_string_opt (Dream.param request "id") with
        | Error app_error, _ -> error_response app_error
        | _, None ->
            error_response
              (App_error.Bad_request "Submission id must be an integer")
        | Ok access_token, Some submission_id -> (
            let* context_result =
              Auth_service.authenticate_access_token auth_deps access_token
            in
            match context_result with
            | Error app_error -> error_response app_error
            | Ok context -> (
                let* result =
                  Task_service.get_submission current_task_deps ~context
                    ~submission_id
                in
                match result with
                | Ok submission ->
                    json_response ~code:200 (submission_json submission)
                | Error app_error -> error_response app_error)))
  in
  let handle_submissions request =
    app.with_repo request (fun repo ->
        let auth_deps = deps repo app in
        let current_task_deps = task_deps repo app in
        match access_token_from_request request with
        | Error app_error -> error_response app_error
        | Ok access_token -> (
            let* context_result =
              Auth_service.authenticate_access_token auth_deps access_token
            in
            match context_result with
            | Error app_error -> error_response app_error
            | Ok context -> (
                let* result =
                  Task_service.list_submissions current_task_deps ~context
                    ~scope:(submission_scope_from_request request)
                in
                match result with
                | Ok submissions ->
                    json_response ~code:200 (submissions_json submissions)
                | Error app_error -> error_response app_error)))
  in
  Dream.router
    [
      Dream.get "/health" (fun _request ->
          json_response ~code:200
            (`Assoc
              [
                ("status", `String "ok");
                ("message", `String "healthy");
                ( "mode",
                  `String (Runtime_mode.to_string app.config.mode) );
              ]));
      Dream.get "/openapi.json" (fun _request ->
          Dream.respond ~code:200 ~headers:json_headers openapi_spec);
      Dream.scope "/api/v1" [] [
        Dream.post "/auth/register" handle_register;
        Dream.post "/auth/login" handle_login;
        Dream.post "/auth/refresh" handle_refresh;
        Dream.post "/auth/logout" handle_logout;
        Dream.post "/auth/verify-email" handle_verify_email;
        Dream.get "/me" handle_me;
        Dream.delete "/me" handle_delete_me;
        Dream.get "/users" handle_users;
        Dream.post "/users/:id/ban" handle_ban;
        Dream.post "/users/:id/unban" handle_unban;
        Dream.get "/task-types/:type/config-template" handle_task_config_template;
        Dream.get "/tasks" handle_tasks;
        Dream.get "/tasks/:id" handle_task;
        Dream.get "/tasks/slug/:slug" handle_task_by_slug;
        Dream.post "/tasks" handle_create_task;
        Dream.post "/tasks/:id/submissions" handle_create_submission;
        Dream.get "/submissions" handle_submissions;
        Dream.get "/submissions/:id" handle_submission;
      ];
    ]
  |> rate_limit_middleware app
