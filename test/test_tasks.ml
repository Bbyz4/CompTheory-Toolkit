open Yojson.Basic.Util
open Test_support

let nfa_transition from_state to_state symbol =
  `Assoc
    [
      ("from", `String from_state);
      ("to", `String to_state);
      ( "symbol",
        match symbol with Some value -> `String value | None -> `Null );
    ]

let process_one_submission fixture =
  let worker_deps : Toolkit.Submission_worker.deps =
    {
      repo = fixture.repo;
      queue = fixture.submission_queue;
      clock = fixture.clock;
      judging_delay_seconds = (fun () -> 0.);
    }
  in
  Lwt_main.run (Toolkit.Submission_worker.process_next worker_deps) |> unwrap_ok

let test_delete_user_cascades_owned_tasks_and_submissions () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let author_response =
    register fixture "ola" "ola@example.com" "password123"
  in
  assert_status `Created author_response;
  let author_id = user_id_of_response author_response in
  let author_access = token_of_response author_response "access_token" in
  let task_response =
    create_task fixture admin_access ~author_id
      ~title:"Owned by ola" ~description:"Owned task" ()
  in
  assert_status `Created task_response;
  let task_id = task_id_of_response task_response in
  let task_slug = task_slug_of_response task_response in
  let solver_response =
    register fixture "solver2" "solver2@example.com" "password123"
  in
  assert_status `Created solver_response;
  let solver_access = token_of_response solver_response "access_token" in
  let submission_response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ solver_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_nfa_submission_data ()) ]))
      ()
  in
  assert_status `Created submission_response;
  let submission_id = submission_id_of_response submission_response in
  let delete_response =
    request fixture ~meth:`DELETE ~target:"/api/v1/me"
      ~headers:[ ("Authorization", "Bearer " ^ author_access) ]
      ()
  in
  assert_status `OK delete_response;
  let task_lookup =
    request fixture ~meth:`GET
      ~target:("/api/v1/tasks/slug/" ^ task_slug)
      ()
  in
  assert_status `Not_Found task_lookup;
  let stored_submission =
    Lwt_main.run (fixture.repo.find_submission_by_id submission_id)
    |> unwrap_repo_ok
  in
  assert_true
    (stored_submission = None)
    "Deleting a task author should cascade to submissions owned by that task"

let test_health_and_openapi () =
  let fixture = make_fixture () in
  let health = request fixture ~meth:`GET ~target:"/health" () in
  let openapi = request fixture ~meth:`GET ~target:"/openapi.json" () in
  assert_status `OK health;
  assert_status `OK openapi;
  assert_true
    (String.length (response_body openapi) > 0)
    "OpenAPI document should not be empty"

let test_admin_creates_task_and_public_list_exposes_it () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_json = response_json created_task |> member "task" in
  assert_true
    (task_json |> member "type" |> to_string = "MODEL_CONSTRUCTION")
    "Created task should expose the task type";
  let listed = request fixture ~meth:`GET ~target:"/api/v1/tasks" () in
  assert_status `OK listed;
  let tasks = response_json listed |> member "tasks" |> to_list in
  assert_true (List.length tasks = 1) "Public task list should include the new task"

let test_submission_is_created_pending_and_worker_judges_it () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "solver" "solver@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let created_submission =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ solver_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_nfa_submission_data ()) ]))
      ()
  in
  assert_status `Created created_submission;
  let created_submission_json =
    response_json created_submission |> member "submission"
  in
  assert_true
    (created_submission_json |> member "verdict" |> to_string = "PENDING")
    "New submission should start as pending";
  let submission_id = submission_id_of_response created_submission in
  let processed = process_one_submission fixture in
  assert_true processed "Worker should consume one queued submission";
  let stored_submission =
    Lwt_main.run (fixture.repo.find_submission_by_id submission_id)
    |> unwrap_repo_ok
  in
  match stored_submission with
  | Some submission ->
      assert_true
        (submission.verdict <> Toolkit.Domain.Pending)
        "Worker should replace the pending verdict with a mock result";
      assert_true
        (submission.run_data <> None)
        "Worker should persist mock run_data";
      begin
        match submission.run_data with
        | Some run_data ->
            assert_true
              (run_data |> member "worker" |> to_string = "mock-rabbitmq-http")
              "Mock task should be graded by the mock worker"
        | None -> fail "Worker should persist mock run_data"
      end
  | None -> fail "Stored submission should still be queryable"

let submit_nfa fixture access_token task_id data =
  request fixture ~meth:`POST
    ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
    ~headers:
      [
        ("Authorization", "Bearer " ^ access_token);
        ("Content-Type", "application/json");
      ]
    ~body:(Yojson.Basic.to_string (`Assoc [ ("data", data) ]))
    ()

let explicit_tests_config tests =
  model_construction_config
    ~grader:
      (`Assoc
        [
          ("kind", `String "explicit-tests");
          ("tests", `List (List.map (fun word -> `String word) tests));
        ])
    ()

let a_star_nfa () =
  valid_nfa_submission_data
    ~states:[ "q0" ]
    ~input_alphabet:[ "a" ]
    ~transitions:[ nfa_transition "q0" "q0" (Some "a") ]
    ~start_states:[ "q0" ] ~accept_states:[ "q0" ] ()

let test_explicit_tests_worker_accepts_when_all_words_are_accepted () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task =
    create_task fixture admin_access
      ~config:(explicit_tests_config [ ""; "a"; "aa" ])
      ()
  in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "explicitok" "explicitok@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let created_submission =
    submit_nfa fixture solver_access task_id (a_star_nfa ())
  in
  assert_status `Created created_submission;
  let submission_id = submission_id_of_response created_submission in
  assert_true (process_one_submission fixture) "Worker should process submission";
  let stored_submission =
    Lwt_main.run (fixture.repo.find_submission_by_id submission_id)
    |> unwrap_repo_ok
  in
  match stored_submission with
  | None -> fail "Stored submission should still be queryable"
  | Some submission -> (
      assert_true
        (submission.verdict = Toolkit.Domain.Accepted)
        "Explicit tests should accept when every word is accepted";
      match submission.run_data with
      | None -> fail "Explicit test worker should persist run_data"
      | Some run_data ->
          assert_true
            (run_data |> member "worker" |> to_string = "explicit-tests")
            "Explicit test task should be graded by the explicit-tests worker";
          assert_true
            (run_data |> member "strategy" |> to_string = "nfa-acceptance")
            "Explicit test worker should use the NFA acceptance primitive";
          assert_true
            (List.length (run_data |> member "tests" |> to_list) = 3)
            "Explicit test run_data should include each configured test")

let test_explicit_tests_worker_rejects_when_a_word_is_rejected () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task =
    create_task fixture admin_access
      ~config:(explicit_tests_config [ "a"; "b" ])
      ()
  in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "explicitbad" "explicitbad@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let created_submission =
    submit_nfa fixture solver_access task_id (a_star_nfa ())
  in
  assert_status `Created created_submission;
  let submission_id = submission_id_of_response created_submission in
  assert_true (process_one_submission fixture) "Worker should process submission";
  let stored_submission =
    Lwt_main.run (fixture.repo.find_submission_by_id submission_id)
    |> unwrap_repo_ok
  in
  match stored_submission with
  | None -> fail "Stored submission should still be queryable"
  | Some submission -> (
      assert_true
        (submission.verdict = Toolkit.Domain.Rejected)
        "Explicit tests should reject when any word is rejected";
      match submission.run_data with
      | None -> fail "Explicit test worker should persist run_data"
      | Some run_data ->
          let tests = run_data |> member "tests" |> to_list in
          assert_true
            (List.exists
               (fun test_json ->
                 test_json |> member "word" |> to_string = "b"
                 && not (test_json |> member "accepted" |> to_bool))
               tests)
            "Explicit test run_data should record the rejected word")

let test_task_config_template_endpoint () =
  let fixture = make_fixture () in
  let response =
    request fixture ~meth:`GET
      ~target:"/api/v1/task-types/MODEL_CONSTRUCTION/config-template"
      ()
  in
  assert_status `OK response;
  let json = response_json response in
  assert_true
    (json |> member "config_template" |> member "grader" |> member "kind"
   |> to_string
    = "mock")
    "Task config template endpoint should return the mock grader template";
  assert_true
    (json |> member "config_template" |> member "version" = `Null)
    "Task config template endpoint should not expose a legacy version field";
  assert_true
    (json |> member "config_template" |> member "requiredModelType" |> to_string
    = "NFA")
    "Task config template endpoint should expose the required model type";
  assert_true
    (json |> member "submission_template" |> member "type" |> to_string = "NFA")
    "Task config template endpoint should expose the default submission template"

let test_admin_scope_all_lists_private_and_draft_tasks () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let public_task = create_task fixture admin_access ~title:"Public task" () in
  let draft_task =
    create_task fixture admin_access ~title:"Draft task" ~status:"DRAFT"
      ~visibility:"PRIVATE" ()
  in
  assert_status `Created public_task;
  assert_status `Created draft_task;
  let public_list = request fixture ~meth:`GET ~target:"/api/v1/tasks" () in
  assert_status `OK public_list;
  assert_true
    (List.length (response_json public_list |> member "tasks" |> to_list) = 1)
    "Public task list should only expose published public tasks";
  let admin_list =
    request fixture ~meth:`GET ~target:"/api/v1/tasks?scope=all"
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `OK admin_list;
  assert_true
    (List.length (response_json admin_list |> member "tasks" |> to_list) = 2)
    "Admin scope=all should expose drafts and private tasks"

let test_admin_can_update_task_with_explicit_tests_grader () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task =
    create_task fixture admin_access ~title:"Needs review" ~status:"DRAFT"
      ~visibility:"PRIVATE" ()
  in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let response =
    request fixture ~meth:`PUT
      ~target:(Printf.sprintf "/api/v1/tasks/%d" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ admin_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc
             [
               ("title", `String "Needs review updated");
               ("description", `String "Updated task description");
               ("type", `String "MODEL_CONSTRUCTION");
               ("difficulty", `Int 6);
               ( "config",
                 model_construction_config
                   ~grader:
                     (`Assoc
                       [
                         ("kind", `String "explicit-tests");
                         ("tests", `List [ `String ""; `String "abba" ]);
                       ])
                   () );
               ("status", `String "PUBLISHED");
               ("visibility", `String "UNLISTED");
             ]))
      ()
  in
  assert_status `OK response;
  let task_json = response_json response |> member "task" in
  assert_true
    (task_json |> member "title" |> to_string = "Needs review updated")
    "Task update should persist the new title";
  assert_true
    (task_json |> member "status" |> to_string = "PUBLISHED")
    "Task update should persist the new status";
  assert_true
    (task_json |> member "visibility" |> to_string = "UNLISTED")
    "Task update should persist the new visibility";
  assert_true
    (task_json |> member "config" |> member "grader" |> member "kind"
   |> to_string
    = "explicit-tests")
    "Task update should accept the explicit-tests grader";
  assert_true
    (List.length
       (task_json |> member "config" |> member "grader" |> member "tests"
      |> to_list)
    = 2)
    "Task update should persist the configured explicit tests";
  assert_true
    (task_json |> member "published_at" <> `Null)
    "Publishing an updated draft should set published_at"

let test_task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task =
    create_task fixture admin_access ~title:"Regular Languages 101" ()
  in
  assert_status `Created created_task;
  let slug = task_slug_of_response created_task in
  assert_true
    (slug = "regular-languages-101")
    "Task creation should generate a slug from the title when missing";
  let fetched =
    request fixture ~meth:`GET
      ~target:("/api/v1/tasks/slug/" ^ slug)
      ()
  in
  assert_status `OK fetched;
  assert_true
    (response_json fetched |> member "task" |> member "title" |> to_string
    = "Regular Languages 101")
    "Task should be fetchable by generated slug"

let test_submissions_scope_mine_vs_all () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let alice = register fixture "queuealice" "queuealice@example.com" "password123" in
  let bob = register fixture "queuebob" "queuebob@example.com" "password123" in
  assert_status `Created alice;
  assert_status `Created bob;
  let alice_access = token_of_response alice "access_token" in
  let bob_access = token_of_response bob "access_token" in
  let post_submission access_token =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ access_token);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_nfa_submission_data ()) ]))
      ()
  in
  assert_status `Created (post_submission alice_access);
  assert_status `Created (post_submission bob_access);
  let mine =
    request fixture ~meth:`GET ~target:"/api/v1/submissions?scope=mine"
      ~headers:[ ("Authorization", "Bearer " ^ alice_access) ]
      ()
  in
  assert_status `OK mine;
  assert_true
    (List.length (response_json mine |> member "submissions" |> to_list) = 1)
    "Mine scope should only return the current user's submissions";
  let all_forbidden =
    request fixture ~meth:`GET ~target:"/api/v1/submissions?scope=all"
      ~headers:[ ("Authorization", "Bearer " ^ alice_access) ]
      ()
  in
  assert_status `Forbidden all_forbidden;
  let all_for_admin =
    request fixture ~meth:`GET ~target:"/api/v1/submissions?scope=all"
      ~headers:[ ("Authorization", "Bearer " ^ admin_access) ]
      ()
  in
  assert_status `OK all_for_admin;
  assert_true
    (List.length (response_json all_for_admin |> member "submissions" |> to_list) = 2)
    "Admin all scope should return every submission"

let tests : test_case list =
  [
    ( "delete_user_cascades_owned_tasks_and_submissions",
      test_delete_user_cascades_owned_tasks_and_submissions );
    ("health_and_openapi", test_health_and_openapi);
    ( "admin_creates_task_and_public_list_exposes_it",
      test_admin_creates_task_and_public_list_exposes_it );
    ( "submission_is_created_pending_and_worker_judges_it",
      test_submission_is_created_pending_and_worker_judges_it );
    ( "explicit_tests_worker_accepts_when_all_words_are_accepted",
      test_explicit_tests_worker_accepts_when_all_words_are_accepted );
    ( "explicit_tests_worker_rejects_when_a_word_is_rejected",
      test_explicit_tests_worker_rejects_when_a_word_is_rejected );
    ("task_config_template_endpoint", test_task_config_template_endpoint);
    ( "admin_scope_all_lists_private_and_draft_tasks",
      test_admin_scope_all_lists_private_and_draft_tasks );
    ( "admin_can_update_task_with_explicit_tests_grader",
      test_admin_can_update_task_with_explicit_tests_grader );
    ( "task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug",
      test_task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug );
    ("submissions_scope_mine_vs_all", test_submissions_scope_mine_vs_all);
  ]
