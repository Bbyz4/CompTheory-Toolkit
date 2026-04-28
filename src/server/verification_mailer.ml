type sent_mail = {
  from_address : string;
  to_address : string;
  subject : string;
  body : string;
  verification_url : string;
}

type t = {
  send_verification_email :
    to_email:string ->
    username:string ->
    verification_url:string ->
    (unit, string) result Lwt.t;
}

let noop =
  {
    send_verification_email =
      (fun ~to_email:_ ~username:_ ~verification_url:_ -> Lwt.return (Ok ()));
  }

let smtp_multiline_body body =
  body |> String.split_on_char '\n'
  |> List.map (fun line ->
         if String.length line > 0 && line.[0] = '.' then
           "." ^ line ^ "\r\n"
         else
           line ^ "\r\n")
  |> String.concat ""

let read_smtp_response ic =
  let rec loop lines =
    let line = input_line ic in
    let next = line :: lines in
    if String.length line >= 4 && line.[3] = ' ' then
      List.rev next
    else
      loop next
  in
  loop []

let expect_code ic expected =
  match read_smtp_response ic with
  | [] -> Error "SMTP server closed the connection unexpectedly"
  | line :: _ as lines ->
      let code =
        if String.length line >= 3 then
          int_of_string_opt (String.sub line 0 3)
        else
          None
      in
      if code = Some expected then
        Ok ()
      else
        Error (String.concat "\n" lines)

let smtp_send ~host ~port ~from_address ~to_address ~subject ~body =
  let sockaddr =
    match Unix.getaddrinfo host (string_of_int port) [ Unix.AI_SOCKTYPE Unix.SOCK_STREAM ] with
    | [] -> Error ("Could not resolve SMTP host: " ^ host)
    | entry :: _ -> Ok entry.Unix.ai_addr
  in
  match sockaddr with
  | Error _ as error -> error
  | Ok sockaddr ->
      let ic, oc = Unix.open_connection sockaddr in
      Fun.protect
        ~finally:(fun () ->
          close_in_noerr ic;
          close_out_noerr oc)
        (fun () ->
          let send_line line =
            output_string oc line;
            output_string oc "\r\n";
            flush oc
          in
          let ( let* ) result f = match result with Ok value -> f value | Error _ as error -> error in
          let* () = expect_code ic 220 in
          send_line "EHLO recognita.xyz";
          let* () = expect_code ic 250 in
          send_line ("MAIL FROM:<" ^ from_address ^ ">");
          let* () = expect_code ic 250 in
          send_line ("RCPT TO:<" ^ to_address ^ ">");
          let* () = expect_code ic 250 in
          send_line "DATA";
          let* () = expect_code ic 354 in
          output_string oc ("From: " ^ from_address ^ "\r\n");
          output_string oc ("To: " ^ to_address ^ "\r\n");
          output_string oc ("Subject: " ^ subject ^ "\r\n");
          output_string oc "MIME-Version: 1.0\r\n";
          output_string oc "Content-Type: text/html; charset=utf-8\r\n";
          output_string oc "\r\n";
          output_string oc (smtp_multiline_body body);
          output_string oc "\r\n.\r\n";
          flush oc;
          let* () = expect_code ic 250 in
          send_line "QUIT";
          let* () = expect_code ic 221 in
          Ok ())

let subject ~site_name = "Verify your email for " ^ site_name

let body ~site_name ~username ~verification_url =
  String.concat "\n"
    [
      "<html><body style=\"font-family:Segoe UI, Arial, sans-serif; color:#1f2a30;\">";
      ("<p>Hello " ^ username ^ ",</p>");
      ("<p>Thanks for signing up for <strong>" ^ site_name ^ "</strong>.</p>");
      "<p>Please open the link below to continue to the verification screen:</p>";
      ("<p><a href=\"" ^ verification_url
     ^ "\" style=\"display:inline-block;padding:12px 18px;border-radius:12px;background:#b56c3f;color:#fff;text-decoration:none;\">Open verification page</a></p>");
      ("<p>If the button does not work, copy this URL into your browser:<br /><a href=\""
     ^ verification_url ^ "\">" ^ verification_url ^ "</a></p>");
      "<p>If you did not create this account, you can safely ignore this email.</p>";
      "</body></html>";
    ]

let make_smtp ~host ~port ~from_address ~site_name =
  {
    send_verification_email =
      (fun ~to_email ~username ~verification_url ->
        Lwt_preemptive.detach
          (fun () ->
            smtp_send ~host ~port ~from_address ~to_address:to_email
              ~subject:(subject ~site_name)
              ~body:(body ~site_name ~username ~verification_url))
          ());
  }

let make_memory ?(from_address = "no-reply@recognita.xyz") ?(site_name = "Recognita") () =
  let outbox = ref [] in
  ( {
      send_verification_email =
        (fun ~to_email ~username ~verification_url ->
          outbox :=
            {
              from_address;
              to_address = to_email;
              subject = subject ~site_name;
              body = body ~site_name ~username ~verification_url;
              verification_url;
            }
            :: !outbox;
          Lwt.return (Ok ()));
    },
    outbox )
