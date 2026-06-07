open Test_support

let transition from_state to_state symbol =
  `Assoc
    [
      ("from", `String from_state);
      ("to", `String to_state);
      ( "symbol",
        match symbol with Some value -> `String value | None -> `Null );
    ]

let assert_nfa_accepts nfa word expected =
  match Toolkit.Nfa_acceptance.accepts_json nfa ~word with
  | Error message -> fail ("NFA acceptance failed to parse model: " ^ message)
  | Ok actual ->
      assert_true
        (actual = expected)
        (Printf.sprintf "Expected NFA acceptance for %S to be %b" word expected)

let test_nfa_acceptance_handles_epsilon_and_words () =
  let nfa =
    valid_nfa_submission_data
      ~states:[ "q0"; "q1"; "q2" ]
      ~input_alphabet:[ "a"; "b" ]
      ~transitions:
        [
          transition "q0" "q1" None;
          transition "q1" "q1" (Some "a");
          transition "q1" "q2" (Some "b");
        ]
      ~start_states:[ "q0" ] ~accept_states:[ "q2" ] ()
  in
  assert_nfa_accepts nfa "b" true;
  assert_nfa_accepts nfa "aaab" true;
  assert_nfa_accepts nfa "" false;
  assert_nfa_accepts nfa "a" false

let test_nfa_acceptance_handles_epsilon_cycles () =
  let nfa =
    valid_nfa_submission_data
      ~states:[ "q0"; "q1" ]
      ~input_alphabet:[ "a" ]
      ~transitions:
        [
          transition "q0" "q1" None;
          transition "q1" "q0" None;
        ]
      ~start_states:[ "q0" ] ~accept_states:[ "q1" ] ()
  in
  assert_nfa_accepts nfa "" true

let test_nfa_acceptance_handles_nondeterminism () =
  let nfa =
    valid_nfa_submission_data
      ~states:[ "q0"; "q1" ]
      ~input_alphabet:[ "a" ]
      ~transitions:
        [
          transition "q0" "q0" (Some "a");
          transition "q0" "q1" (Some "a");
        ]
      ~start_states:[ "q0" ] ~accept_states:[ "q1" ] ()
  in
  assert_nfa_accepts nfa "a" true;
  assert_nfa_accepts nfa "aaa" true;
  assert_nfa_accepts nfa "" false

let tests : test_case list =
  [
    ( "nfa_acceptance_handles_epsilon_and_words",
      test_nfa_acceptance_handles_epsilon_and_words );
    ( "nfa_acceptance_handles_epsilon_cycles",
      test_nfa_acceptance_handles_epsilon_cycles );
    ( "nfa_acceptance_handles_nondeterminism",
      test_nfa_acceptance_handles_nondeterminism );
  ]
