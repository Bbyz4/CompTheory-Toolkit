let ( let* ) = Lwt.bind

let json_headers = [ ("content-type", "application/json; charset=utf-8") ]

let bearer_token request =
  match Dream.header request "authorization" with
  | Some value when Toolkit.Util.starts_with ~prefix:"Bearer " value ->
      Some (String.sub value 7 (String.length value - 7))
  | _ -> None

let proxy_request config ?access_token ?body ?(headers = []) ~meth path =
  Lwt_preemptive.detach
    (fun () ->
      Toolkit.Http_client.request ?access_token ?body ~headers
        ~base_url:config.Toolkit.Web_config.api_base_url ~meth path)
    ()

let respond_proxy response =
  let content_type =
    match List.assoc_opt "content-type" response.Toolkit.Http_client.headers with
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

let () =
  let config = Toolkit.Web_config.load () in
  let app =
    Dream.router
      [
        Dream.get "/" (fun _request ->
            Dream.html (Toolkit.Web_page.render ~site_name:config.site_name));
        Dream.get "/verify" (fun _request ->
            Dream.html (Toolkit.Web_page.render ~site_name:config.site_name));
        Dream.get "/health" (fun _request ->
            Dream.respond ~code:200 ~headers:json_headers
              (Yojson.Basic.to_string
                 (`Assoc
                   [
                     ("status", `String "ok");
                     ("service", `String "webapp");
                     ("api_base_url", `String config.api_base_url);
                   ])));
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
        Dream.get "/proxy/users" (fun request ->
            proxy_authed config request ~meth:"GET" "/api/v1/users");
        Dream.post "/proxy/users/:id/ban" (fun request ->
            let user_id = Dream.param request "id" in
            proxy_authed config request ~meth:"POST"
              ("/api/v1/users/" ^ user_id ^ "/ban"));
        Dream.post "/proxy/users/:id/unban" (fun request ->
            let user_id = Dream.param request "id" in
            proxy_authed config request ~meth:"POST"
              ("/api/v1/users/" ^ user_id ^ "/unban"));
      ]
  in
  Dream.run ~interface:config.host ~port:config.port
  @@ Dream.logger
  @@ app
