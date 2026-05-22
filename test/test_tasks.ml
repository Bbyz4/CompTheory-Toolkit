open Yojson.Basic.Util
open Test_support

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
  let worker_deps : Toolkit.Submission_worker.deps =
    {
      repo = fixture.repo;
      queue = fixture.submission_queue;
      clock = fixture.clock;
      judging_delay_seconds = (fun () -> 0.);
    }
  in
  let processed =
    Lwt_main.run (Toolkit.Submission_worker.process_next worker_deps)
    |> unwrap_ok
  in
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
        "Worker should persist mock run_data"
  | None -> fail "Stored submission should still be queryable"

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
    (json |> member "config_template" |> member "requiredModelType" |> to_string
    = "NFA")
    "Task config template endpoint should expose the required model type";
  assert_true
    (json |> member "submission_template" |> member "type" |> to_string = "NFA")
    "Task config template endpoint should expose the default submission template"

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
    ("task_config_template_endpoint", test_task_config_template_endpoint);
    ( "task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug",
      test_task_without_slug_gets_generated_slug_and_can_be_loaded_by_slug );
    ("submissions_scope_mine_vs_all", test_submissions_scope_mine_vs_all);
  ]
