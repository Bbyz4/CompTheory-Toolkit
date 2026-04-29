open Yojson.Basic.Util

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
  sent_emails : Toolkit.Verification_mailer.sent_mail list ref;
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
        with_repo = (fun _request handler -> handler repo);
      }
    in
    Toolkit.App.make app_config
  in
  let _ = clock_ref in
  { app; repo; sent_emails }

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

let unwrap_result map_error = function
  | Ok value -> value
  | Error error -> fail (map_error error)

let unwrap_ok result = unwrap_result (fun message -> message) result

let unwrap_repo_ok result =
  unwrap_result Toolkit.Repository.error_message result

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
  | Toolkit.Admin_cli.Users_listed _ | Toolkit.Admin_cli.User_banned _ ->
      fail "Admin CLI promote returned the wrong outcome variant"

let tests =
  [
    ("register_and_me", test_register_and_me);
    ( "register_sends_verification_email_and_verify_endpoint",
      test_register_sends_verification_email_and_verify_endpoint );
    ("login_and_logout", test_login_and_logout);
    ("refresh_rotates_tokens", test_refresh_rotates_tokens);
    ("admin_lists_and_moderates_users", test_admin_lists_and_moderates_users);
    ("non_admin_cannot_moderate", test_non_admin_cannot_moderate);
    ("rate_limit_blocks_auth_endpoint", test_rate_limit_blocks_auth_endpoint);
    ("health_and_openapi", test_health_and_openapi);
    ( "web_requires_access_code_for_html_and_proxy",
      test_web_requires_access_code_for_html_and_proxy );
    ( "web_access_gate_rejects_fake_cookie_and_accepts_real_one",
      test_web_access_gate_rejects_fake_cookie_and_accepts_real_one );
    ( "web_access_gate_supports_mailpit_return_and_internal_check",
      test_web_access_gate_supports_mailpit_return_and_internal_check );
    ("admin_cli_lists_users_with_emails", test_admin_cli_lists_users_with_emails);
    ("admin_cli_ban_revokes_sessions", test_admin_cli_ban_revokes_sessions);
    ("admin_cli_promotes_user_to_admin", test_admin_cli_promotes_user_to_admin);
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
  let results = List.map run_test tests in
  if List.for_all (fun passed -> passed) results then
    ()
  else
    exit 1
