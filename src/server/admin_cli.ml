let ( let* ) = Lwt.bind

type command =
  | List_users
  | Ban_user of {
      user_id : int;
      reason : string option;
    }
  | Promote_admin of {
      user_id : int;
    }

type outcome =
  | Users_listed of Domain.public_user list
  | User_banned of Domain.public_user
  | User_promoted_to_admin of Domain.public_user

let default_ban_reason = "banned via admincli"

let normalize_reason = function
  | Some value ->
      let trimmed = String.trim value in
      if trimmed = "" then
        Some default_ban_reason
      else
        Some trimmed
  | None -> Some default_ban_reason

let prepare ~(repo : Repository.t) ~(clock : Clock.t) ~config =
  let _ = clock in
  let _ = config in
  let* init_result = repo.init_schema () in
  match init_result with
  | Error repo_error ->
      Lwt.return (Error (Repository.error_message repo_error))
  | Ok () -> Lwt.return (Ok ())

let perform ~(repo : Repository.t) ~(clock : Clock.t) = function
  | List_users -> (
      let* listed = repo.list_users () in
      match listed with
      | Ok users -> Lwt.return (Ok (Users_listed users))
      | Error repo_error ->
          Lwt.return (Error (Repository.error_message repo_error)))
  | Ban_user { user_id; reason } -> (
      let* found = repo.find_user_by_id user_id in
      match found with
      | Error repo_error ->
          Lwt.return (Error (Repository.error_message repo_error))
      | Ok None -> Lwt.return (Error "User not found")
      | Ok (Some user) ->
          let now = clock.now () in
          let* updated =
            repo.update_ban ~user_id:user.Domain.id ~is_banned:true
              ~ban_reason:(normalize_reason reason) ~updated_at:now
          in
          match updated with
          | Error repo_error ->
              Lwt.return (Error (Repository.error_message repo_error))
          | Ok None -> Lwt.return (Error "User not found")
          | Ok (Some updated_user) ->
              let* revoked =
                repo.revoke_user_sessions ~user_id:updated_user.id
                  ~revoked_at:now
              in
              match revoked with
              | Ok () ->
                  Lwt.return
                    (Ok (User_banned (Domain.public_user_of_user updated_user)))
              | Error repo_error ->
                  Lwt.return (Error (Repository.error_message repo_error)))
  | Promote_admin { user_id } ->
      let now = clock.now () in
      let* updated =
        repo.update_role ~user_id ~role:Domain.Admin ~updated_at:now
      in
      match updated with
      | Error repo_error ->
          Lwt.return (Error (Repository.error_message repo_error))
      | Ok None -> Lwt.return (Error "User not found")
      | Ok (Some user) ->
          Lwt.return (Ok (User_promoted_to_admin (Domain.public_user_of_user user)))

let ellipsize ~max_width value =
  if String.length value <= max_width then
    value
  else if max_width <= 3 then
    String.sub value 0 max_width
  else
    String.sub value 0 (max_width - 3) ^ "..."

let pad_right width value =
  let missing = width - String.length value in
  if missing <= 0 then value else value ^ String.make missing ' '

let pad_left width value =
  let missing = width - String.length value in
  if missing <= 0 then value else String.make missing ' ' ^ value

let user_status (user : Domain.public_user) =
  if user.is_banned then "banned" else "active"

let verified_status (user : Domain.public_user) =
  if user.verified then "yes" else "no"

let user_reason (user : Domain.public_user) =
  match user.ban_reason with
  | Some value when String.trim value <> "" -> value
  | _ -> "-"

let user_cells (user : Domain.public_user) =
  [
    string_of_int user.id;
    user.username;
    user.email;
    Domain.role_to_string user.role;
    verified_status user;
    user_status user;
    user_reason user;
  ]

let render_user_table users =
  if users = [] then
    "No users found.\n"
  else
    let headers = [ "ID"; "USERNAME"; "EMAIL"; "ROLE"; "VERIFIED"; "STATUS"; "REASON" ] in
    let rows =
      List.map
        (fun user ->
          match user_cells user with
          | id :: username :: email :: role :: verified :: status :: reason :: [] ->
              [
                id;
                ellipsize ~max_width:24 username;
                ellipsize ~max_width:32 email;
                role;
                verified;
                status;
                ellipsize ~max_width:36 reason;
              ]
          | _ -> failwith "unexpected user row")
        users
    in
    let widths =
      List.mapi
        (fun column header ->
          List.fold_left
            (fun current row ->
              max current (String.length (List.nth row column)))
            (String.length header) rows)
        headers
    in
    let render_row row =
      row
      |> List.mapi (fun index cell ->
             if index = 0 then
               pad_left (List.nth widths index) cell
             else
               pad_right (List.nth widths index) cell)
      |> String.concat " | "
    in
    let separator =
      widths |> List.map (fun width -> String.make width '-') |> String.concat "-+-"
    in
    let header_line = render_row headers in
    let body = rows |> List.map render_row |> String.concat "\n" in
    String.concat "\n"
      [ header_line; separator; body; ""; Printf.sprintf "%d user(s)." (List.length users) ]
    ^ "\n"

let render_ban_result (user : Domain.public_user) =
  let reason = user_reason user in
  Printf.sprintf "Banned user #%d (%s)\nemail: %s\nreason: %s\n" user.id
    user.username user.email reason

let render_promote_result (user : Domain.public_user) =
  Printf.sprintf "Promoted user #%d (%s) to admin\nemail: %s\n" user.id
    user.username user.email

let render = function
  | Users_listed users -> render_user_table users
  | User_banned user -> render_ban_result user
  | User_promoted_to_admin user -> render_promote_result user

let run_lwt ?db_url command =
  let config = Config.load () in
  let config =
    match db_url with
    | Some value -> { config with Config.db_url = value }
    | None -> config
  in
  let clock = Clock.system in
  let* connected =
    Startup.run_with_connection config.Config.db_url (fun connection ->
        let repo = Caqti_repo.make connection in
        let* prepared = prepare ~repo ~clock ~config in
        match prepared with
        | Error message -> Lwt.return (Error (App_error.Internal message))
        | Ok () -> (
            let* outcome = perform ~repo ~clock command in
            match outcome with
            | Ok value -> Lwt.return (Ok (render value))
            | Error message ->
                Lwt.return (Error (App_error.Internal message))))
  in
  match connected with
  | Ok _ as ok -> Lwt.return ok
  | Error app_error -> Lwt.return (Error (App_error.message app_error))

let run ?db_url command = Lwt_main.run (run_lwt ?db_url command)
