let ( let* ) = Lwt.bind

type with_repo =
  Dream.request -> (Repository.t -> Dream.response Lwt.t) -> Dream.response Lwt.t

type t = {
  config : Config.t;
  clock : Clock.t;
  rate_limiter : Rate_limiter.t;
  mailer : Verification_mailer.t;
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

let parse_body request =
  let* body = Dream.body request in
  match Json_utils.parse body with
  | Ok json -> Lwt.return (Ok json)
  | Error app_error -> Lwt.return (Error app_error)

let access_token_from_request request =
  match Dream.header request "authorization" with
  | Some value when Util.starts_with ~prefix:"Bearer " value ->
      Ok (String.sub value 7 (String.length value - 7))
  | _ -> Error (App_error.Unauthorized "Missing bearer access token")

let deps repo app : Auth_service.deps =
  { repo; clock = app.clock; config = app.config; mailer = app.mailer }

let with_deps app request fn = app.with_repo request (fun repo -> fn (deps repo app))

let ratelimit_headers (decision : Rate_limiter.decision) =
  [
    ("x-ratelimit-limit", string_of_int decision.limit);
    ("x-ratelimit-remaining", string_of_int decision.remaining);
    ("x-ratelimit-reset", Util.iso8601_of_unix_time decision.reset_at);
  ]

let client_key request =
  let client = Dream.client request in
  match Util.split_once ~on:':' client with Some (host, _port) -> host | None -> client

let rate_limit_middleware app inner request =
  let path = Dream.target request |> Util.strip_query in
  if path = "/health" || path = "/openapi.json" then
    inner request
  else
    let decision =
      Rate_limiter.check app.rate_limiter ~key:(client_key request) ~path
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
  Dream.router
    [
      Dream.get "/health" (fun _request ->
          json_response ~code:200 (status_json "ok" "healthy"));
      Dream.get "/openapi.json" (fun _request ->
          Dream.respond ~code:200 ~headers:json_headers openapi_spec);
      Dream.scope "/api/v1" [] [
        Dream.post "/auth/register" handle_register;
        Dream.post "/auth/login" handle_login;
        Dream.post "/auth/refresh" handle_refresh;
        Dream.post "/auth/logout" handle_logout;
        Dream.post "/auth/verify-email" handle_verify_email;
        Dream.get "/me" handle_me;
        Dream.get "/users" handle_users;
        Dream.post "/users/:id/ban" handle_ban;
        Dream.post "/users/:id/unban" handle_unban;
      ];
    ]
  |> rate_limit_middleware app
