let ( let* ) = Lwt.bind

let json_headers = [ ("content-type", "application/json; charset=utf-8") ]

let gate_cookie_name = "recognita_gate"

let first_value = function [] -> None | value :: _ -> Some value

let constant_time_equal left right =
  let left_length = String.length left in
  let right_length = String.length right in
  let mismatch = ref (left_length lxor right_length) in
  let limit = min left_length right_length in
  for index = 0 to limit - 1 do
    mismatch := !mismatch lor (Char.code left.[index] lxor Char.code right.[index])
  done;
  !mismatch = 0

let has_suffix ~suffix value =
  let suffix_length = String.length suffix in
  let value_length = String.length value in
  value_length >= suffix_length
  && String.sub value (value_length - suffix_length) suffix_length = suffix

let expected_gate_cookie config =
  Digest.string (config.Web_config.access_code ^ "|" ^ config.access_cookie_secret)
  |> Digest.to_hex

let cookie_value request name =
  let trim = String.trim in
  let parse part =
    match String.split_on_char '=' part with
    | [] -> None
    | [ key ] when trim key = name -> Some ""
    | key :: value_parts when trim key = name ->
        Some (String.concat "=" value_parts |> trim)
    | _ -> None
  in
  match Dream.header request "cookie" with
  | None -> None
  | Some raw ->
      raw |> String.split_on_char ';' |> List.find_map (fun part -> parse (trim part))

let request_path request = Uri.path (Uri.of_string (Dream.target request))

let query_value request name =
  match Dream.target request |> Uri.of_string |> Uri.query |> List.assoc_opt name with
  | Some values -> first_value values
  | None -> None

let is_safe_return_target value =
  let path = Uri.path (Uri.of_string value) in
  String.length value > 0
  && value.[0] = '/'
  && (String.length value = 1 || value.[1] <> '/')
  && path <> "/access"
  && path <> "/health"
  && path <> "/_recognita/access-check"
  && path <> "/_recognita/access-gate"
  && not (Util.starts_with ~prefix:"/_recognita/" path)
  && not (Util.starts_with ~prefix:"/proxy/" path)
  && not (Util.starts_with ~prefix:"/_admin_api/" path)
  && not (Util.starts_with ~prefix:"/admin-assets/" path)

let normalize_return_target value = if is_safe_return_target value then value else "/"

let cookie_header config =
  let secure =
    match config.Web_config.mode with
    | Runtime_mode.Deployment -> "; Secure"
    | Runtime_mode.Local -> ""
  in
  Printf.sprintf
    "%s=%s; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000%s"
    gate_cookie_name (expected_gate_cookie config) secure

let html_response ?(code = 200) html =
  Dream.respond ~code ~headers:[ ("content-type", "text/html; charset=utf-8") ] html

let gate_return_target request =
  match query_value request "return_to" with
  | Some value -> normalize_return_target value
  | None -> (
      match Dream.header request "x-recognita-return-to" with
      | Some value -> normalize_return_target value
      | None -> normalize_return_target (Dream.target request))

let gate_page ?(code = 200) ?(message = "") ?return_to config request =
  Access_gate_page.render ~site_name:config.Web_config.site_name
    ~return_to:
      (match return_to with
      | Some value -> normalize_return_target value
      | None -> gate_return_target request)
    ~message ()
  |> html_response ~code

let deny_json_access message =
  Dream.respond ~code:403 ~headers:json_headers
    (Yojson.Basic.to_string
       (`Assoc
         [
           ( "error",
             `Assoc [ ("status", `Int 403); ("message", `String message) ] );
         ]))

let access_granted config request =
  match cookie_value request gate_cookie_name with
  | Some value -> constant_time_equal value (expected_gate_cookie config)
  | None -> false

let access_check config request =
  let status = if access_granted config request then 204 else 401 in
  Dream.respond ~code:status ""

let bearer_token request =
  match Dream.header request "authorization" with
  | Some value when Util.starts_with ~prefix:"Bearer " value ->
      Some (String.sub value 7 (String.length value - 7))
  | _ -> None

let proxy_request config ?access_token ?body ?(headers = []) ~meth path =
  Lwt_preemptive.detach
    (fun () ->
      Http_client.request ?access_token ?body ~headers
        ~base_url:config.Web_config.api_base_url ~meth path)
    ()

let respond_proxy response =
  let content_type =
    match List.assoc_opt "content-type" response.Http_client.headers with
    | Some value -> value
    | None -> "application/json; charset=utf-8"
  in
  Dream.respond ~code:response.status_code
    ~headers:[ ("content-type", content_type) ]
    response.body

let proxy_public config ~meth path =
  Lwt.catch
    (fun () ->
      let* response = proxy_request config ~meth path in
      respond_proxy response)
    (fun exn ->
      Dream.respond ~code:502 ~headers:json_headers
        (Yojson.Basic.to_string
           (`Assoc
             [
               ( "error",
                 `Assoc
                   [
                     ("status", `Int 502);
                     ("message", `String ("Proxy error: " ^ Printexc.to_string exn));
                   ] );
             ])))

let proxy_json config request ~meth path =
  let* body = Dream.body request in
  let content_type =
    match Dream.header request "content-type" with
    | Some value -> value
    | None -> "application/json"
  in
  Lwt.catch
    (fun () ->
      let* response =
        proxy_request config ~meth path ~body
          ~headers:[ ("Content-Type", content_type) ]
      in
      respond_proxy response)
    (fun exn ->
      Dream.respond ~code:502 ~headers:json_headers
        (Yojson.Basic.to_string
           (`Assoc
             [
               ( "error",
                 `Assoc
                   [
                     ("status", `Int 502);
                     ("message", `String ("Proxy error: " ^ Printexc.to_string exn));
                   ] );
             ])))

let proxy_authed config request ~meth path =
  let access_token = bearer_token request in
  let content_type =
    match Dream.header request "content-type" with
    | Some value -> value
    | None -> "application/json"
  in
  let* body = if meth = "GET" then Lwt.return "" else Dream.body request in
  Lwt.catch
    (fun () ->
      let* response =
        proxy_request config ?access_token ~meth path
          ~headers:[ ("Content-Type", content_type) ]
          ?body:(if meth = "GET" then None else Some body)
      in
      respond_proxy response)
    (fun exn ->
      Dream.respond ~code:502 ~headers:json_headers
        (Yojson.Basic.to_string
           (`Assoc
             [
               ( "error",
                 `Assoc
                   [
                     ("status", `Int 502);
                     ("message", `String ("Proxy error: " ^ Printexc.to_string exn));
                   ] );
             ])))

let admin_credentials config =
  match
    ( config.Web_config.recognita_admin_username,
      config.recognita_admin_password )
  with
  | Some username, Some password -> Ok (username, password)
  | _ ->
      Error
        "Bootstrap admin credentials are not configured for the web service."

let admin_access_token config =
  match admin_credentials config with
  | Error message -> Lwt.return (Error message)
  | Ok (username, password) ->
      let body =
        Yojson.Basic.to_string
          (`Assoc
            [
              ("username", `String username);
              ("password", `String password);
            ])
      in
      Lwt.catch
        (fun () ->
          let* response =
            proxy_request config ~meth:"POST" "/api/v1/auth/login" ~body
              ~headers:[ ("Content-Type", "application/json") ]
          in
          if response.status_code <> 200 then
            Lwt.return
              (Error
                 (Printf.sprintf "Admin login failed with status %d."
                    response.status_code))
          else
            try
              let json = Yojson.Basic.from_string response.body in
              match Yojson.Basic.Util.(json |> member "tokens" |> member "access_token") with
              | `String token when String.trim token <> "" -> Lwt.return (Ok token)
              | _ ->
                  Lwt.return
                    (Error
                       "Admin login succeeded but the API did not return an access token.")
            with Yojson.Json_error message ->
              Lwt.return
                (Error
                   ("Admin login returned invalid JSON: " ^ message)))
        (fun exn ->
          Lwt.return
            (Error ("Admin login proxy error: " ^ Printexc.to_string exn)))

let proxy_admin config request ~meth path =
  let content_type =
    match Dream.header request "content-type" with
    | Some value -> value
    | None -> "application/json"
  in
  let* body = if meth = "GET" then Lwt.return "" else Dream.body request in
  let* token_result = admin_access_token config in
  match token_result with
  | Error message -> Dream.respond ~code:503 ~headers:json_headers
      (Yojson.Basic.to_string
         (`Assoc
           [
             ( "error",
               `Assoc [ ("status", `Int 503); ("message", `String message) ] );
           ]))
  | Ok access_token ->
      Lwt.catch
        (fun () ->
          let* response =
            proxy_request config ~access_token ~meth path
              ~headers:[ ("Content-Type", content_type) ]
              ?body:(if meth = "GET" then None else Some body)
          in
          respond_proxy response)
        (fun exn ->
          Dream.respond ~code:502 ~headers:json_headers
            (Yojson.Basic.to_string
               (`Assoc
                 [
                   ( "error",
                     `Assoc
                       [
                         ("status", `Int 502);
                         ("message", `String ("Proxy error: " ^ Printexc.to_string exn));
                       ] );
                 ])))

let handle_access_submission config request =
  let* body = Dream.body request in
  let params = Uri.query_of_encoded body in
  let code =
    Option.value ~default:""
      (Option.bind (List.assoc_opt "code" params) first_value)
  in
  let return_to =
    Option.value ~default:"/"
      (Option.bind (List.assoc_opt "return_to" params) first_value)
    |> normalize_return_target
  in
  if constant_time_equal code config.Web_config.access_code then
    Dream.respond ~code:303
      ~headers:
        [ ("location", return_to); ("set-cookie", cookie_header config) ]
      ""
  else
    gate_page ~code:401 ~message:"Wrong codeword." config request

let regular_file_exists path =
  Sys.file_exists path
  && (try not (Sys.is_directory path) with Sys_error _ -> false)

let safe_segment segment =
  segment <> ""
  && segment <> "."
  && segment <> ".."
  && not (String.contains segment '/')
  && not (String.contains segment '\000')

let static_file_path config segments =
  if List.for_all safe_segment segments then
    Some (List.fold_left Filename.concat config.Web_config.admin_panel_dist_dir segments)
  else
    None

let content_type path =
  if has_suffix ~suffix:".html" path then
    "text/html; charset=utf-8"
  else if has_suffix ~suffix:".css" path then
    "text/css; charset=utf-8"
  else if has_suffix ~suffix:".js" path then
    "text/javascript; charset=utf-8"
  else if has_suffix ~suffix:".svg" path then
    "image/svg+xml"
  else if has_suffix ~suffix:".json" path then
    "application/json; charset=utf-8"
  else if has_suffix ~suffix:".ico" path then
    "image/x-icon"
  else
    "application/octet-stream"

let serve_file ?cache_control path =
  if regular_file_exists path then
    Lwt.catch
      (fun () ->
        let headers =
          ("content-type", content_type path)
          ::
          (match cache_control with
          | Some value -> [ ("cache-control", value) ]
          | None -> [])
        in
        Dream.respond
          ~headers
          (Util.read_file path))
      (fun _exn -> Dream.respond ~code:500 "Could not read file")
  else
    Dream.respond ~code:404 "Not found"

let render_admin_panel config =
  let index_path =
    Filename.concat config.Web_config.admin_panel_dist_dir "index.html"
  in
  if regular_file_exists index_path then
    serve_file index_path
  else
    html_response
      "<!DOCTYPE html><html><head><title>Recognita Admin Panel</title></head><body><div id=\"root\">Admin panel build is missing.</div></body></html>"

let serve_admin_asset config segments =
  match static_file_path config segments with
  | None -> Dream.respond ~code:404 "Not found"
  | Some path ->
      serve_file ~cache_control:"public, max-age=31536000, immutable" path

let require_access config handler request =
  let path = request_path request in
  if
    path = "/health"
    || path = "/access"
    || path = "/_recognita/access-check"
    || path = "/_recognita/access-gate"
    || access_granted config request
  then
    handler request
  else if Util.starts_with ~prefix:"/proxy/" path then
    deny_json_access "Access code required"
  else if Util.starts_with ~prefix:"/_admin_api/" path then
    deny_json_access "Access code required"
  else
    gate_page config request

let make config =
  let render_page _request = render_admin_panel config in
  let router =
    Dream.router
      [
        Dream.get "/health" (fun _request ->
            Dream.respond ~code:200 ~headers:json_headers
              (Yojson.Basic.to_string
                 (`Assoc
                   [
                     ("status", `String "ok");
                     ("service", `String "webapp");
                     ( "mode",
                       `String
                         (Runtime_mode.to_string config.Web_config.mode) );
                     ("api_base_url", `String config.Web_config.api_base_url);
                   ])));
        Dream.get "/access" (gate_page config);
        Dream.post "/access" (handle_access_submission config);
        Dream.get "/_recognita/access-check" (access_check config);
        Dream.get "/_recognita/access-gate" (gate_page config);
        Dream.get "/admin-assets/:file" (fun request ->
            serve_admin_asset config [ Dream.param request "file" ]);
        Dream.get "/admin-assets/:folder/:file" (fun request ->
            serve_admin_asset config
              [ Dream.param request "folder"; Dream.param request "file" ]);
        Dream.get "/_admin_api/tasks" (fun _request ->
            proxy_public config ~meth:"GET" "/api/v1/tasks");
        Dream.get "/_admin_api/task-types/:type/config-template" (fun request ->
            proxy_public config ~meth:"GET"
              ("/api/v1/task-types/"
              ^ Uri.pct_encode (Dream.param request "type")
              ^ "/config-template"));
        Dream.post "/_admin_api/tasks" (fun request ->
            proxy_admin config request ~meth:"POST" "/api/v1/tasks");
        Dream.get "/_admin_api/users" (fun request ->
            proxy_admin config request ~meth:"GET" "/api/v1/users");
        Dream.post "/_admin_api/users/:id/ban" (fun request ->
            proxy_admin config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/ban"));
        Dream.post "/_admin_api/users/:id/unban" (fun request ->
            proxy_admin config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/unban"));
        Dream.get "/_admin_api/submissions" (fun request ->
            proxy_admin config request ~meth:"GET"
              "/api/v1/submissions?scope=all");
        Dream.post "/proxy/auth/register" (fun request ->
            proxy_json config request ~meth:"POST" "/api/v1/auth/register");
        Dream.post "/proxy/auth/login" (fun request ->
            proxy_json config request ~meth:"POST" "/api/v1/auth/login");
        Dream.post "/proxy/auth/refresh" (fun request ->
            proxy_json config request ~meth:"POST" "/api/v1/auth/refresh");
        Dream.post "/proxy/auth/verify-email" (fun request ->
            proxy_json config request ~meth:"POST" "/api/v1/auth/verify-email");
        Dream.post "/proxy/auth/logout" (fun request ->
            proxy_authed config request ~meth:"POST" "/api/v1/auth/logout");
        Dream.get "/proxy/me" (fun request ->
            proxy_authed config request ~meth:"GET" "/api/v1/me");
        Dream.get "/proxy/tasks" (fun request ->
            let query =
              match Uri.of_string (Dream.target request) |> Uri.verbatim_query with
              | None -> ""
              | Some value -> "?" ^ value
            in
            proxy_json config request ~meth:"GET" ("/api/v1/tasks" ^ query));
        Dream.get "/proxy/tasks/:slug" (fun request ->
            proxy_json config request ~meth:"GET"
              ("/api/v1/tasks/slug/" ^ Uri.pct_encode (Dream.param request "slug")));
        Dream.post "/proxy/tasks/:id/submissions" (fun request ->
            let task_id = Dream.param request "id" in
            proxy_authed config request ~meth:"POST"
              ("/api/v1/tasks/" ^ task_id ^ "/submissions"));
        Dream.get "/proxy/submissions" (fun request ->
            let query =
              match Uri.of_string (Dream.target request) |> Uri.verbatim_query with
              | None -> ""
              | Some value -> "?" ^ value
            in
            proxy_authed config request ~meth:"GET" ("/api/v1/submissions" ^ query));
        Dream.get "/proxy/submissions/:id" (fun request ->
            proxy_authed config request ~meth:"GET"
              ("/api/v1/submissions/" ^ Dream.param request "id"));
        Dream.get "/proxy/users" (fun request ->
            proxy_authed config request ~meth:"GET" "/api/v1/users");
        Dream.post "/proxy/users/:id/ban" (fun request ->
            proxy_authed config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/ban"));
        Dream.post "/proxy/users/:id/unban" (fun request ->
            proxy_authed config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/unban"));
        Dream.get "/" render_page;
        Dream.get "/dashboard" render_page;
        Dream.get "/tasks" render_page;
        Dream.get "/submissions" render_page;
        Dream.get "/students" render_page;
        Dream.get "/settings" render_page;
        Dream.get "/verify" render_page;
      ]
  in
  require_access config router
