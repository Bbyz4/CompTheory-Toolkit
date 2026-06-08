open Test_support

let tests : test_case list =
  List.concat
    [
      Test_auth.tests;
      Test_tasks.tests;
      Judge_bridge_tests.tests;
      Nfa_validation_tests.tests;
      Cfg_validation_tests.tests;
      Test_web.tests;
      Test_admin_cli.tests;
      Test_startup.tests;
    ]

let integration_tests : test_case list = Test_repository_integration.tests

let () =
  if not (db_integration_enabled ()) then
    Printf.printf "SKIP db integration tests (set RUN_DB_INTEGRATION_TESTS=1)\n%!";
  let selected_tests =
    if db_integration_enabled () then tests @ integration_tests else tests
  in
  let results = List.map run_test selected_tests in
  if List.for_all (fun passed -> passed) results then
    ()
  else
    exit 1
