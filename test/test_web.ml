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

let test_web_renders_detail_routes () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let submission_detail =
    request_handler app ~meth:`GET ~target:"/submissions/123" ()
  in
  let student_profile =
    request_handler app ~meth:`GET ~target:"/students/123" ()
  in
  assert_status `OK submission_detail;
  assert_status `OK student_profile;
  assert_true
    (contains_substring ~needle:"<div id=\"root\">" (response_body submission_detail))
    "Submission detail URL should render the admin panel shell";
  assert_true
    (contains_substring ~needle:"<div id=\"root\">" (response_body student_profile))
    "Student profile URL should render the admin panel shell"

let test_web_admin_submission_detail_proxy_route_exists () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let response =
    request_handler app ~meth:`GET ~target:"/_admin_api/submissions/123" ()
  in
  assert_status `Bad_Gateway response

let tests : test_case list =
  [
    ( "web_renders_admin_panel_without_access_gate",
      test_web_renders_admin_panel_without_access_gate );
    ( "web_proxy_auth_endpoint_is_directly_available",
      test_web_proxy_auth_endpoint_is_directly_available );
    ("web_renders_detail_routes", test_web_renders_detail_routes);
    ( "web_admin_submission_detail_proxy_route_exists",
      test_web_admin_submission_detail_proxy_route_exists );
  ]
