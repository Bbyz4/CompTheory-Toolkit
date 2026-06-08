let ( let* ) = Lwt.bind

let json_headers = [ ("content-type", "application/json; charset=utf-8") ]

let has_suffix ~suffix value =
  let suffix_length = String.length suffix in
  let value_length = String.length value in
  value_length >= suffix_length
  && String.sub value (value_length - suffix_length) suffix_length = suffix

let html_response ?(code = 200) html =
  Dream.respond ~code ~headers:[ ("content-type", "text/html; charset=utf-8") ] html

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

let proxy_admin config request ~meth path =
  proxy_authed config request ~meth path

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
        Dream.get "/admin-assets/:file" (fun request ->
            serve_admin_asset config [ Dream.param request "file" ]);
        Dream.get "/admin-assets/:folder/:file" (fun request ->
            serve_admin_asset config
              [ Dream.param request "folder"; Dream.param request "file" ]);
        Dream.get "/_admin_api/tasks" (fun request ->
            proxy_admin config request ~meth:"GET" "/api/v1/tasks?scope=all");
        Dream.get "/_admin_api/task-types/:type/config-template" (fun request ->
            proxy_admin config request ~meth:"GET"
              ("/api/v1/task-types/"
              ^ Uri.pct_encode (Dream.param request "type")
              ^ "/config-template"));
        Dream.post "/_admin_api/tasks" (fun request ->
            proxy_admin config request ~meth:"POST" "/api/v1/tasks");
        Dream.put "/_admin_api/tasks/:id" (fun request ->
            proxy_admin config request ~meth:"PUT"
              ("/api/v1/tasks/" ^ Dream.param request "id"));
        Dream.get "/_admin_api/users" (fun request ->
            proxy_admin config request ~meth:"GET" "/api/v1/users");
        Dream.get "/_admin_api/users/:id" (fun request ->
            proxy_admin config request ~meth:"GET"
              ("/api/v1/users/" ^ Dream.param request "id"));
        Dream.post "/_admin_api/users/:id/ban" (fun request ->
            proxy_admin config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/ban"));
        Dream.post "/_admin_api/users/:id/unban" (fun request ->
            proxy_admin config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/unban"));
        Dream.get "/_admin_api/submissions" (fun request ->
            proxy_admin config request ~meth:"GET"
              "/api/v1/submissions?scope=all");
        Dream.get "/_admin_api/submissions/:id" (fun request ->
            proxy_admin config request ~meth:"GET"
              ("/api/v1/submissions/" ^ Dream.param request "id"));
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
        Dream.get "/proxy/users/:id" (fun request ->
            proxy_authed config request ~meth:"GET"
              ("/api/v1/users/" ^ Dream.param request "id"));
        Dream.post "/proxy/users/:id/ban" (fun request ->
            proxy_authed config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/ban"));
        Dream.post "/proxy/users/:id/unban" (fun request ->
            proxy_authed config request ~meth:"POST"
              ("/api/v1/users/" ^ Dream.param request "id" ^ "/unban"));
        Dream.get "/" render_page;
        Dream.get "/dashboard" render_page;
        Dream.get "/tasks" render_page;
        Dream.get "/tasks/:slug" render_page;
        Dream.get "/tasks/:slug/edit" render_page;
        Dream.get "/submissions" render_page;
        Dream.get "/submissions/:id" render_page;
        Dream.get "/students" render_page;
        Dream.get "/students/:id" render_page;
        Dream.get "/settings" render_page;
        Dream.get "/verify" render_page;
      ]
  in
  router
