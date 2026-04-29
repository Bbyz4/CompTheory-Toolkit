let emit_result = function
  | Ok output ->
      print_string output;
      `Ok ()
  | Error message -> `Error (false, message)

let db_url_arg =
  let doc =
    "Optional PostgreSQL connection string. Defaults to $(b,DATABASE_URL) or the project default."
  in
  Cmdliner.Arg.(
    value
    & opt (some string) None
    & info [ "database-url" ] ~docv:"URL" ~doc)

let list_users_term =
  let doc = "List users directly from the database." in
  let term =
    let run db_url = emit_result (Toolkit.Admin_cli.run ?db_url Toolkit.Admin_cli.List_users) in
    Cmdliner.Term.(ret (const run $ db_url_arg))
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "list-users" ~doc) term

let user_id_arg =
  let doc = "User id to ban." in
  Cmdliner.Arg.(
    required & pos 0 (some int) None & info [] ~docv:"USER_ID" ~doc)

let reason_arg =
  let doc =
    "Ban reason stored with the account. Defaults to \"banned via admincli\"."
  in
  Cmdliner.Arg.(
    value & opt (some string) None & info [ "reason" ] ~docv:"TEXT" ~doc)

let ban_user_term =
  let doc = "Ban a user directly in the database and revoke active sessions." in
  let term =
    let run db_url user_id reason =
      emit_result
        (Toolkit.Admin_cli.run ?db_url
           (Toolkit.Admin_cli.Ban_user { user_id; reason }))
    in
    Cmdliner.Term.(ret (const run $ db_url_arg $ user_id_arg $ reason_arg))
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "ban-user" ~doc) term

let promote_admin_term =
  let doc = "Promote a user to admin directly in the database." in
  let term =
    let run db_url user_id =
      emit_result
        (Toolkit.Admin_cli.run ?db_url
           (Toolkit.Admin_cli.Promote_admin { user_id }))
    in
    Cmdliner.Term.(ret (const run $ db_url_arg $ user_id_arg))
  in
  Cmdliner.Cmd.v (Cmdliner.Cmd.info "promote-admin" ~doc) term

let cmd =
  let doc = "Administrative CLI for direct host-side moderation tasks." in
  Cmdliner.Cmd.group (Cmdliner.Cmd.info "admincli" ~doc)
    [ list_users_term; ban_user_term; promote_admin_term ]

let () = exit (Cmdliner.Cmd.eval cmd)
