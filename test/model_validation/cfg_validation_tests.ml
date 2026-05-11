open Test_support

let test_submission_accepts_valid_cfg_payload () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task =
    create_task fixture admin_access
      ~config:(model_construction_config ~required_model_type:"CFG" ()) ()
  in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "solver_cfg" "solver_cfg@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let response =
    request fixture ~meth:`POST
      ~target:(Printf.sprintf "/api/v1/tasks/%d/submissions" task_id)
      ~headers:
        [
          ("Authorization", "Bearer " ^ solver_access);
          ("Content-Type", "application/json");
        ]
      ~body:
        (Yojson.Basic.to_string
           (`Assoc [ ("data", valid_cfg_submission_data ()) ]))
      ()
  in
  assert_status `Created response

let test_model_json_rejects_cfg_symbol_overlap () =
  let invalid_cfg =
    valid_cfg_submission_data ~non_terminals:[ "S"; "A" ]
      ~terminals:[ "a"; "S" ] ()
  in
  match Toolkit.Model_json.validate invalid_cfg with
  | Ok _ -> fail "CFG with overlapping terminal/non-terminal symbols should fail"
  | Error message ->
      assert_true
        (contains_substring ~needle:"model.terminals" message)
        "CFG overlap error should mention model.terminals"

let tests : test_case list =
  [
    ("submission_accepts_valid_cfg_payload", test_submission_accepts_valid_cfg_payload);
    ( "model_json_rejects_cfg_symbol_overlap",
      test_model_json_rejects_cfg_symbol_overlap );
  ]
