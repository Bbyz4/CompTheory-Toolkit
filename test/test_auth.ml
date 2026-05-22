open Yojson.Basic.Util
open Test_support

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

let test_rate_limit_blocks_auth_endpoint () =
  let fixture = make_fixture ~auth_rate_limit_max_requests:2 () in
  let first = login fixture "ghost" "badpass123" in
  let second = login fixture "ghost" "badpass123" in
  let third = login fixture "ghost" "badpass123" in
  assert_status `Unauthorized first;
  assert_status `Unauthorized second;
  assert_status `Too_Many_Requests third

let tests : test_case list =
  [
    ("register_and_me", test_register_and_me);
    ( "register_sends_verification_email_and_verify_endpoint",
      test_register_sends_verification_email_and_verify_endpoint );
    ("login_and_logout", test_login_and_logout);
    ("delete_own_account", test_user_can_delete_own_account);
    ("refresh_rotates_tokens", test_refresh_rotates_tokens);
    ("rate_limit_blocks_auth_endpoint", test_rate_limit_blocks_auth_endpoint);
  ]
