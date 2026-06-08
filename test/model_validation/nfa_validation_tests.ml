open Yojson.Basic.Util
open Test_support

let test_submission_records_invalid_nfa_payload_run_data () =
  let fixture = make_fixture () in
  let admin_access = login_admin fixture in
  let created_task = create_task fixture admin_access () in
  assert_status `Created created_task;
  let task_id = task_id_of_response created_task in
  let registered =
    register fixture "solver_bad" "solver_bad@example.com" "password123"
  in
  assert_status `Created registered;
  let solver_access = token_of_response registered "access_token" in
  let invalid_duplicate_transition =
    `Assoc
      [
        ("type", `String "NFA");
        ( "model",
          `Assoc
            [
              ("states", `List [ `String "q0"; `String "q1" ]);
              ("inputAlphabet", `List [ `String "a" ]);
              ( "transitions",
                `List
                  [
                    `Assoc
                      [
                        ("from", `String "q0");
                        ("to", `String "q1");
                        ("symbol", `String "a");
                      ];
                    `Assoc
                      [
                        ("from", `String "q0");
                        ("to", `String "q1");
                        ("symbol", `String "a");
                      ];
                  ] );
              ("startStates", `List [ `String "q0" ]);
              ("acceptStates", `List [ `String "q1" ]);
            ] );
      ]
  in
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
           (`Assoc [ ("data", invalid_duplicate_transition) ]))
      ()
  in
  assert_status `Created response;
  let submission_json = response_json response |> member "submission" in
  assert_true
    (submission_json |> member "verdict" |> to_string = "INVALID_FORMAT")
    "Invalid payload should create an INVALID_FORMAT submission";
  assert_true
    (submission_json |> member "run_data" |> member "strategy" |> to_string
    = "invalid-format")
    "Invalid payload run_data should record the invalid-format strategy";
  assert_true
    (submission_json |> member "run_data" |> member "message" |> to_string
    |> contains_substring ~needle:"duplicate transitions")
    "Invalid payload run_data should record the validation failure"

let test_model_json_accepts_valid_nfa () =
  match Toolkit.Model_json.validate (valid_nfa_submission_data ()) with
  | Ok _ -> ()
  | Error message -> fail ("Valid NFA should pass validation: " ^ message)

let tests : test_case list =
  [
    ( "submission_records_invalid_nfa_payload_run_data",
      test_submission_records_invalid_nfa_payload_run_data );
    ("model_json_accepts_valid_nfa", test_model_json_accepts_valid_nfa);
  ]
