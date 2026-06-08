open Test_support

let assert_bridge_accepted result message =
  match result with
  | Toolkit.Judge_bridge.Accepted -> ()
  | Toolkit.Judge_bridge.Rejected { index; word } ->
      fail
        (Printf.sprintf "%s: rejected at test %d (%S)" message index word)
  | Toolkit.Judge_bridge.Invalid_format detail ->
      fail (message ^ ": invalid format: " ^ detail)
  | Toolkit.Judge_bridge.Internal_error detail ->
      fail (message ^ ": internal error: " ^ detail)

let test_bridge_accepts_simple_nfa () =
  let result =
    Toolkit.Judge_bridge.judge_nfa_explicit_tests
      ~submission_data:(valid_nfa_submission_data ())
      ~tests:[ "a" ]
  in
  assert_bridge_accepted result "Simple NFA should accept configured word"

let test_bridge_rejects_first_failed_test () =
  let result =
    Toolkit.Judge_bridge.judge_nfa_explicit_tests
      ~submission_data:(valid_nfa_submission_data ())
      ~tests:[ "a"; "aa" ]
  in
  match result with
  | Toolkit.Judge_bridge.Rejected { index; word } ->
      assert_true
        (index = 1 && word = "aa")
        "Bridge should report the first rejected explicit test"
  | _ -> fail "Bridge should reject the first word not accepted by the NFA"

let test_bridge_accepts_empty_test_set () =
  let result =
    Toolkit.Judge_bridge.judge_nfa_explicit_tests
      ~submission_data:(valid_nfa_submission_data ())
      ~tests:[]
  in
  assert_bridge_accepted result "Empty explicit test set should accept vacuously"

let test_bridge_accepts_epsilon_from_nonzero_start_state () =
  let transitions =
    [
      `Assoc
        [
          ("from", `String "q1");
          ("to", `String "q2");
          ("symbol", `Null);
        ];
    ]
  in
  let submission_data =
    valid_nfa_submission_data
      ~states:[ "q0"; "q1"; "q2" ]
      ~input_alphabet:[ "a" ]
      ~transitions ~start_states:[ "q1" ] ~accept_states:[ "q2" ] ()
  in
  let result =
    Toolkit.Judge_bridge.judge_nfa_explicit_tests ~submission_data ~tests:[ "" ]
  in
  assert_bridge_accepted result
    "Bridge should follow epsilon transitions from the actual active state"

let tests : test_case list =
  [
    ("bridge_accepts_simple_nfa", test_bridge_accepts_simple_nfa);
    ("bridge_rejects_first_failed_test", test_bridge_rejects_first_failed_test);
    ("bridge_accepts_empty_test_set", test_bridge_accepts_empty_test_set);
    ( "bridge_accepts_epsilon_from_nonzero_start_state",
      test_bridge_accepts_epsilon_from_nonzero_start_state );
  ]
