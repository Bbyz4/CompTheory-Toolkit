open Yojson.Basic.Util
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

let run_data_string submission field =
  match submission.Toolkit.Domain.run_data with
  | Some json -> json |> member field |> to_string
  | None -> fail "Expected submission run_data"

let run_data_has_field submission field =
  match submission.Toolkit.Domain.run_data with
  | Some json -> (
      match json |> member field with `Null -> false | _ -> true)
  | None -> false

let test_startup_json_equivalent_ignores_object_key_order () =
  assert_true
    (Toolkit.Startup.json_equivalent
       (`Assoc
         [
           ("b", `Int 1);
           ("a", `List [ `Assoc [ ("z", `String "z"); ("y", `String "y") ] ]);
         ])
       (`Assoc
         [
           ("a", `List [ `Assoc [ ("y", `String "y"); ("z", `String "z") ] ]);
           ("b", `Int 1);
         ]))
    "Startup JSON matching should ignore object key order";
  assert_true
    (not
       (Toolkit.Startup.json_equivalent
          (`List [ `Int 1; `Int 2 ])
          (`List [ `Int 2; `Int 1 ])))
    "Startup JSON matching should preserve list order"

let test_startup_seeds_handmade_pilot_data () =
  let repo = Toolkit.In_memory_repo.make () in
  let clock = Toolkit.Clock.make (fun () -> 1_700_000_000.) in
  let prepared = Lwt_main.run (repo.init_schema ()) |> unwrap_repo_ok in
  ignore prepared;
  let result =
    Lwt_main.run (Toolkit.Startup.run_startup_steps repo clock (base_config ()))
    |> unwrap_result Toolkit.App_error.message
  in
  ignore result;
  let user =
    Lwt_main.run
      (repo.find_user_by_username Toolkit.Startup.handmade_pilot_username)
    |> unwrap_repo_ok
  in
  let task =
    Lwt_main.run
      (repo.find_task_by_slug Toolkit.Startup.handmade_pilot_problem_slug)
    |> unwrap_repo_ok
  in
  match user, task with
  | Some user, Some task ->
      assert_true
        (user.email = Toolkit.Startup.handmade_pilot_email)
        "Handmade pilot user should use the requested email";
      assert_true user.verified "Handmade pilot user should be verified";
      assert_true
        (task.title = Toolkit.Startup.handmade_pilot_problem_title)
        "Handmade pilot task should use the requested title";
      assert_true
        (task.config |> member "grader" |> member "kind" |> to_string
        = "explicit-tests")
        "Handmade pilot task should use explicit tests";
      let submissions =
        Lwt_main.run (repo.list_submissions ()) |> unwrap_repo_ok
        |> List.filter
             (fun (submission : Toolkit.Domain.submission) ->
               submission.task_id = task.id && submission.user_id = user.id)
      in
      assert_true
        (List.length submissions = 3)
        "Handmade pilot data should create one submission per tested verdict";
      let find_submission case_name data =
        match
          List.find_opt
            (fun (submission : Toolkit.Domain.submission) ->
              submission.data = data)
            submissions
        with
        | Some submission -> submission
        | None -> fail ("Missing handmade submission case " ^ case_name)
      in
      let assert_no_handmade_run_data_fields submission =
        List.iter
          (fun field ->
            assert_true
              (not (run_data_has_field submission field))
              ("Handmade submission run_data should not include " ^ field))
          [ "source"; "case"; "expected_verdict"; "worker_run_data" ]
      in
      let assert_case case_name data expected_verdict =
        let submission = find_submission case_name data in
        assert_true
          (submission.verdict = expected_verdict)
          ("Handmade submission " ^ case_name
         ^ " should produce the expected verdict");
        assert_true
          (run_data_string submission "strategy" = "explicit-tests-nfa")
          "Handmade submission should be judged through explicit NFA tests";
        assert_no_handmade_run_data_fields submission;
        submission
      in
      ignore
        (assert_case "accepted" Toolkit.Startup.handmade_pilot_accepted_data
           Toolkit.Domain.Accepted);
      let rejected_submission =
        assert_case "rejected" Toolkit.Startup.handmade_pilot_rejected_data
          Toolkit.Domain.Rejected
      in
      let invalid_submission =
        assert_case "invalid_format"
          Toolkit.Startup.handmade_pilot_invalid_format_data
          Toolkit.Domain.Invalid_format
      in
      assert_true
        (run_data_string rejected_submission "failed_test" = "ababab")
        "Rejected handmade NFA should fail specifically on ababab";
      assert_true
        (run_data_string invalid_submission "message"
        |> contains_substring ~needle:"declared state")
        "Invalid-format handmade NFA should fail because of a small bad state reference";
      let second_result =
        Lwt_main.run
          (Toolkit.Startup.run_startup_steps repo clock (base_config ()))
        |> unwrap_result Toolkit.App_error.message
      in
      ignore second_result;
      let submissions_after =
        Lwt_main.run (repo.list_submissions ()) |> unwrap_repo_ok
        |> List.filter
             (fun (submission : Toolkit.Domain.submission) ->
               submission.task_id = task.id && submission.user_id = user.id)
      in
      assert_true
        (List.length submissions_after = List.length submissions)
        "Handmade pilot submissions should not duplicate on rerun"
  | None, _ -> fail "Expected handmade pilot user to be created"
  | _, None -> fail "Expected handmade pilot problem to be created"

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
    ( "startup_json_equivalent_ignores_object_key_order",
      test_startup_json_equivalent_ignores_object_key_order );
    ( "startup_seeds_handmade_pilot_data",
      test_startup_seeds_handmade_pilot_data );
    ( "startup_seeds_mock_data_idempotently",
      test_startup_seeds_mock_data_idempotently );
  ]
