open Test_support

let test_web_requires_access_code_for_html_and_proxy () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let home = request_handler app ~meth:`GET ~target:"/" () in
  assert_status `OK home;
  let home_body = response_body home in
  assert_true
    (contains_substring
       ~needle:"Enter the super secret recognita codeword"
       home_body)
    "Home page should render the access code gate before entry";
  let proxy =
    request_handler app ~meth:`GET ~target:"/proxy/me" ()
  in
  assert_status `Forbidden proxy

let test_web_access_gate_rejects_fake_cookie_and_accepts_real_one () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let fake_cookie =
    request_handler app ~meth:`GET ~target:"/proxy/me"
      ~headers:[ ("Cookie", "recognita_gate=fakevalue") ]
      ()
  in
  assert_true
    (Dream.status fake_cookie = `Forbidden)
    "Fake gate cookie should not unlock proxy access";
  let granted =
    request_handler app ~meth:`POST ~target:"/access"
      ~headers:[ ("Content-Type", "application/x-www-form-urlencoded") ]
      ~body:"code=pezarski&return_to=%2Fverify%3Ftoken%3Dabc"
      ()
  in
  assert_true
    (Dream.status granted = `See_Other)
    "Valid gate code should produce a redirect response";
  assert_true
    (Dream.header granted "location" = Some "/verify?token=abc")
    "Access gate should preserve the requested verification return target";
  let gate_cookie = web_cookie_from_response granted in
  let dashboard =
    request_handler app ~meth:`GET ~target:"/dashboard"
      ~headers:[ ("Cookie", gate_cookie) ]
      ()
  in
  assert_true
    (Dream.status dashboard = `OK)
    "Gate cookie should unlock the admin panel shell";
  let dashboard_body = response_body dashboard in
  assert_true
    (contains_substring ~needle:"Recognita Admin Panel" dashboard_body)
    "Verified access should unlock the admin panel shell"

let test_web_access_gate_supports_mailpit_return_and_internal_check () =
  let app = Toolkit.Web_app.make (web_config ()) in
  let denied_check =
    request_handler app ~meth:`GET ~target:"/_recognita/access-check" ()
  in
  assert_status `Unauthorized denied_check;
  let mailpit_gate =
    request_handler app ~meth:`GET ~target:"/_recognita/access-gate"
      ~headers:[ ("X-Recognita-Return-To", "/mailpit/messages") ]
      ()
  in
  assert_status `OK mailpit_gate;
  let mailpit_gate_body = response_body mailpit_gate in
  assert_true
    (contains_substring
       ~needle:"name=\"return_to\" value=\"/mailpit/messages\""
       mailpit_gate_body)
    "Internal gate page should preserve the Mailpit return path";
  let granted =
    request_handler app ~meth:`POST ~target:"/access"
      ~headers:[ ("Content-Type", "application/x-www-form-urlencoded") ]
      ~body:"code=pezarski&return_to=%2Fmailpit%2Fmessages"
      ()
  in
  assert_status `See_Other granted;
  assert_true
    (Dream.header granted "location" = Some "/mailpit/messages")
    "Access gate should return to the requested Mailpit subpage";
  let gate_cookie = web_cookie_from_response granted in
  let allowed_check =
    request_handler app ~meth:`GET ~target:"/_recognita/access-check"
      ~headers:[ ("Cookie", gate_cookie) ]
      ()
  in
  assert_status `No_Content allowed_check

let tests : test_case list =
  [
    ( "web_requires_access_code_for_html_and_proxy",
      test_web_requires_access_code_for_html_and_proxy );
    ( "web_access_gate_rejects_fake_cookie_and_accepts_real_one",
      test_web_access_gate_rejects_fake_cookie_and_accepts_real_one );
    ( "web_access_gate_supports_mailpit_return_and_internal_check",
      test_web_access_gate_supports_mailpit_return_and_internal_check );
  ]
