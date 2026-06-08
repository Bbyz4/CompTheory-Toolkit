open Test_support

let test_web_renders_admin_panel_without_access_gate () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let home = request_handler app ~meth:`GET ~target:"/" () in
  assert_status `OK home;
  let home_body = response_body home in
  assert_true
    (contains_substring ~needle:"<div id=\"root\">" home_body)
    "Home page should render the admin panel shell immediately"

let test_web_proxy_auth_endpoint_is_directly_available () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let me =
    request_handler app ~meth:`GET ~target:"/proxy/me" ()
  in
  assert_status `Bad_Gateway me

let test_web_admin_submission_detail_proxy_is_available () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let submission =
    request_handler app ~meth:`GET ~target:"/_admin_api/submissions/123" ()
  in
  assert_status `Bad_Gateway submission

let test_web_renders_detail_deep_links () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let assert_shell target =
    let response = request_handler app ~meth:`GET ~target () in
    assert_status `OK response;
    assert_true
      (contains_substring ~needle:"<div id=\"root\">" (response_body response))
      (target ^ " should render the admin panel shell")
  in
  assert_shell "/submissions/123";
  assert_shell "/students/42";
  assert_shell "/tasks/example-task";
  assert_shell "/tasks/example-task/edit"

let tests : test_case list =
  [
    ( "web_renders_admin_panel_without_access_gate",
      test_web_renders_admin_panel_without_access_gate );
    ( "web_proxy_auth_endpoint_is_directly_available",
      test_web_proxy_auth_endpoint_is_directly_available );
    ( "web_admin_submission_detail_proxy_is_available",
      test_web_admin_submission_detail_proxy_is_available );
    ("web_renders_detail_deep_links", test_web_renders_detail_deep_links);
  ]
