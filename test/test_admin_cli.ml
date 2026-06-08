open Test_support

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
  let users = users_json |> Yojson.Basic.Util.member "users" |> Yojson.Basic.Util.to_list in
  assert_true
    (List.length users >= 2)
    "Admin user list is missing expected users";
  let dave =
    List.find
      (fun user ->
        user |> Yojson.Basic.Util.member "username" |> Yojson.Basic.Util.to_string
        = "dave")
      users
  in
  assert_true
    (dave |> Yojson.Basic.Util.member "email" |> Yojson.Basic.Util.to_string
    = "dave@example.com")
    "Admin user list should include user emails";
  assert_true
    (not (dave |> Yojson.Basic.Util.member "verified" |> Yojson.Basic.Util.to_bool))
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

let test_admin_gets_user_by_id () =
  let fixture = make_fixture () in
  let user_response =
    register fixture "profiledave" "profiledave@example.com" "password123"
  in
  assert_status `Created user_response;
  let user_id = user_id_of_response user_response in
  let admin_access = login_admin fixture in
  let response =
    request fixture ~meth:`GET
      ~target:(Printf.sprintf "/api/v1/users/%d" user_id)
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `OK response;
  let user = response_json response |> Yojson.Basic.Util.member "user" in
  assert_true
    (user |> Yojson.Basic.Util.member "username" |> Yojson.Basic.Util.to_string
    = "profiledave")
    "Admin user detail should return the requested username";
  assert_true
    (user |> Yojson.Basic.Util.member "email" |> Yojson.Basic.Util.to_string
    = "profiledave@example.com")
    "Admin user detail should return the requested email";
  let invalid =
    request fixture ~meth:`GET ~target:"/api/v1/users/not-an-integer"
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `Bad_Request invalid;
  let missing =
    request fixture ~meth:`GET ~target:"/api/v1/users/999999"
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `Not_Found missing

let test_non_admin_cannot_get_user_by_id () =
  let fixture = make_fixture () in
  let alice = register fixture "profileerin" "profileerin@example.com" "password123" in
  let bob = register fixture "profilefrank" "profilefrank@example.com" "password123" in
  assert_status `Created alice;
  assert_status `Created bob;
  let alice_access = token_of_response alice "access_token" in
  let bob_id = user_id_of_response bob in
  let response =
    request fixture ~meth:`GET
      ~target:(Printf.sprintf "/api/v1/users/%d" bob_id)
      ~headers:[ ("Authorization", "Bearer " ^ alice_access) ]
      ()
  in
  assert_status `Forbidden response

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

let tests : test_case list =
  [
    ("admin_lists_and_moderates_users", test_admin_lists_and_moderates_users);
    ("non_admin_cannot_moderate", test_non_admin_cannot_moderate);
    ("admin_gets_user_by_id", test_admin_gets_user_by_id);
    ("non_admin_cannot_get_user_by_id", test_non_admin_cannot_get_user_by_id);
    ("admin_cli_lists_users_with_emails", test_admin_cli_lists_users_with_emails);
    ("admin_cli_ban_revokes_sessions", test_admin_cli_ban_revokes_sessions);
    ("admin_cli_promotes_user_to_admin", test_admin_cli_promotes_user_to_admin);
  ]
