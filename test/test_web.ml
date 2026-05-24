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

let tests : test_case list =
  [
    ( "web_renders_admin_panel_without_access_gate",
      test_web_renders_admin_panel_without_access_gate );
    ( "web_proxy_auth_endpoint_is_directly_available",
      test_web_proxy_auth_endpoint_is_directly_available );
  ]
