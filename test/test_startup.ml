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

let test_startup_seeds_mock_data_idempotently () =
  let config =
    {
      (base_config ()) with
      Toolkit.Config.recognita_mock_user_count = 10;
      recognita_mock_problem_count = 20;
      recognita_mock_submission_count = 1000;
    }
  in
  let repo = Toolkit.In_memory_repo.make () in
  let clock = Toolkit.Clock.make (fun () -> 1_700_000_000.) in
  let prepared = Lwt_main.run (repo.init_schema ()) |> unwrap_repo_ok in
  ignore prepared;
  let result =
    Lwt_main.run (Toolkit.Startup.ensure_mock_seed_data repo clock config)
    |> unwrap_result Toolkit.App_error.message
  in
  ignore result;
  let users = Lwt_main.run (repo.list_users ()) |> unwrap_repo_ok in
  let tasks = Lwt_main.run (repo.list_tasks ()) |> unwrap_repo_ok in
  let submissions =
    Lwt_main.run (repo.list_submissions ()) |> unwrap_repo_ok
  in
  assert_true (List.length users = 10) "Expected 10 startup mock users";
  assert_true (List.length tasks = 20) "Expected 20 startup mock problems";
  assert_true
    (List.length submissions = 1000)
    "Expected 1000 startup mock submissions";
  assert_true
    (List.for_all (fun (user : Toolkit.Domain.public_user) -> user.verified) users)
    "Startup mock users should be verified";
  assert_true
    (List.for_all
       (fun (task : Toolkit.Domain.task) ->
         task.status = Toolkit.Domain.Published
         && task.visibility = Toolkit.Domain.Public
         &&
         match task.slug with
         | Some slug ->
             Toolkit.Util.starts_with ~prefix:"startup-mock-problem-" slug
         | None -> false)
       tasks)
    "Startup mock problems should be public published problems with stable slugs";
  let user_ids = List.map (fun (user : Toolkit.Domain.public_user) -> user.id) users in
  let task_ids = List.map (fun (task : Toolkit.Domain.task) -> task.id) tasks in
  assert_true
    (List.for_all
       (fun (submission : Toolkit.Domain.submission) ->
         List.mem submission.user_id user_ids
         && List.mem submission.task_id task_ids
         && submission.verdict <> Toolkit.Domain.Pending
         && submission.run_data <> None
         && submission.judged_at <> None)
       submissions)
    "Startup mock submissions should belong to seeded users/problems and be judged";
  let second_result =
    Lwt_main.run (Toolkit.Startup.ensure_mock_seed_data repo clock config)
    |> unwrap_result Toolkit.App_error.message
  in
  ignore second_result;
  let users_after = Lwt_main.run (repo.list_users ()) |> unwrap_repo_ok in
  let tasks_after = Lwt_main.run (repo.list_tasks ()) |> unwrap_repo_ok in
  let submissions_after =
    Lwt_main.run (repo.list_submissions ()) |> unwrap_repo_ok
  in
  assert_true
    (List.length users_after = List.length users)
    "Startup mock users should not duplicate on rerun";
  assert_true
    (List.length tasks_after = List.length tasks)
    "Startup mock problems should not duplicate on rerun";
  assert_true
    (List.length submissions_after = List.length submissions)
    "Startup mock submissions should not duplicate on rerun"

let tests : test_case list =
  [
    ("startup_bootstraps_admin_user", test_startup_bootstraps_admin_user);
    ( "startup_refreshes_existing_bootstrap_admin",
      test_startup_refreshes_existing_bootstrap_admin );
    ( "startup_seeds_mock_data_idempotently",
      test_startup_seeds_mock_data_idempotently );
  ]
