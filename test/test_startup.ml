open Test_support

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

let tests : test_case list =
  [
    ("startup_bootstraps_admin_user", test_startup_bootstraps_admin_user);
    ( "startup_refreshes_existing_bootstrap_admin",
      test_startup_refreshes_existing_bootstrap_admin );
  ]
