open Util
open Yojson.Basic.Util

let contains needle haystack =
  try
    ignore (Str.search_forward (Str.regexp_string needle) haystack 0);
    true
  with Not_found -> false

let classify_error message =
  if contains "users_email_key" message then
    Repository.Conflict "Email already exists"
  else if contains "users_username_key" message then
    Repository.Conflict "Username already exists"
  else if contains "tasks_slug_key" message then
    Repository.Conflict "Task slug already exists"
  else if contains "duplicate key" message || contains "23505" message then
    Repository.Conflict "Unique field already exists"
  else
    Repository.Storage message

let map_caqti_error error = classify_error (Caqti_error.show error)

let parse_role value =
  match Domain.role_of_string value with
  | Some role -> Ok role
  | None -> Error (Repository.Storage ("Unknown role: " ^ value))

let parse_task_type value =
  match Domain.task_type_of_string value with
  | Some task_type -> Ok task_type
  | None -> Error (Repository.Storage ("Unknown task type: " ^ value))

let parse_task_status value =
  match Domain.task_status_of_string value with
  | Some status -> Ok status
  | None -> Error (Repository.Storage ("Unknown task status: " ^ value))

let parse_task_visibility value =
  match Domain.task_visibility_of_string value with
  | Some visibility -> Ok visibility
  | None -> Error (Repository.Storage ("Unknown task visibility: " ^ value))

let parse_submission_verdict value =
  match Domain.submission_verdict_of_string value with
  | Some verdict -> Ok verdict
  | None -> Error (Repository.Storage ("Unknown submission verdict: " ^ value))

let parse_user json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match parse_role (json |> member "role" |> to_string) with
    | Error _ as error -> error
    | Ok role ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            username = json |> member "username" |> to_string;
            email = json |> member "email" |> to_string;
            password_hash = json |> member "password_hash" |> to_string;
            role;
            verified = json |> member "verified" |> to_bool;
            is_banned = json |> member "is_banned" |> to_bool;
            ban_reason = json |> member "ban_reason" |> to_option to_string;
            created_at = json |> member "created_at" |> to_float;
            updated_at = json |> member "updated_at" |> to_float;
          }
  with exn -> Error (Repository.Storage ("Failed to decode user JSON: " ^ pp_exn exn))

let parse_public_user json =
  try
    match parse_role (json |> member "role" |> to_string) with
    | Error _ as error -> error
    | Ok role ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            username = json |> member "username" |> to_string;
            email = json |> member "email" |> to_string;
            role;
            verified = json |> member "verified" |> to_bool;
            is_banned = json |> member "is_banned" |> to_bool;
            ban_reason = json |> member "ban_reason" |> to_option to_string;
            created_at = json |> member "created_at" |> to_float;
            updated_at = json |> member "updated_at" |> to_float;
          }
  with exn ->
    Error (Repository.Storage ("Failed to decode public user JSON: " ^ pp_exn exn))

let parse_session json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    Ok
      {
        Domain.id = json |> member "id" |> to_int;
        user_id = json |> member "user_id" |> to_int;
        access_token = json |> member "access_token" |> to_string;
        refresh_token = json |> member "refresh_token" |> to_string;
        access_expires_at = json |> member "access_expires_at" |> to_float;
        refresh_expires_at = json |> member "refresh_expires_at" |> to_float;
        revoked_at = json |> member "revoked_at" |> to_option to_float;
        created_at = json |> member "created_at" |> to_float;
      }
  with exn ->
    Error (Repository.Storage ("Failed to decode session JSON: " ^ pp_exn exn))

let parse_email_verification json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    Ok
      {
        Domain.id = json |> member "id" |> to_int;
        user_id = json |> member "user_id" |> to_int;
        token = json |> member "token" |> to_string;
        expires_at = json |> member "expires_at" |> to_float;
        consumed_at = json |> member "consumed_at" |> to_option to_float;
        created_at = json |> member "created_at" |> to_float;
      }
  with exn ->
    Error
      (Repository.Storage
         ("Failed to decode verification JSON: " ^ pp_exn exn))

let parse_task json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match
      ( parse_task_type (json |> member "type" |> to_string),
        parse_task_status (json |> member "status" |> to_string),
        parse_task_visibility (json |> member "visibility" |> to_string) )
    with
    | (Error _ as error), _, _
    | _, (Error _ as error), _
    | _, _, (Error _ as error) ->
        error
    | Ok type_, Ok status, Ok visibility ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            title = json |> member "title" |> to_string;
            slug = json |> member "slug" |> to_option to_string;
            short_description =
              json |> member "short_description" |> to_option to_string;
            description = json |> member "description" |> to_string;
            type_;
            author_id = json |> member "author_id" |> to_int;
            difficulty = json |> member "difficulty" |> to_int;
            config = json |> member "config";
            status;
            visibility;
            created_at = json |> member "created_at" |> to_float;
            updated_at = json |> member "updated_at" |> to_float;
            published_at = json |> member "published_at" |> to_option to_float;
          }
  with exn ->
    Error (Repository.Storage ("Failed to decode task JSON: " ^ pp_exn exn))

let parse_submission json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match parse_submission_verdict (json |> member "verdict" |> to_string) with
    | Error _ as error -> error
    | Ok verdict ->
        Ok
          {
            Domain.id = json |> member "id" |> to_int;
            task_id = json |> member "task_id" |> to_int;
            user_id = json |> member "user_id" |> to_int;
            data = json |> member "data";
            verdict;
            run_data = json |> member "run_data" |> to_option (fun value -> value);
            created_at = json |> member "created_at" |> to_float;
            judged_at = json |> member "judged_at" |> to_option to_float;
          }
  with exn ->
    Error
      (Repository.Storage ("Failed to decode submission JSON: " ^ pp_exn exn))

let parse_public_user_list json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest -> (
              match parse_public_user item with
              | Ok parsed -> loop (parsed :: acc) rest
              | Error _ as error -> error)
        in
        loop [] items
    | _ -> Error (Repository.Storage "Expected a JSON array for users list")
  with exn ->
    Error (Repository.Storage ("Failed to decode users JSON: " ^ pp_exn exn))

let json_item_text = function
  | `String value -> value
  | value -> Yojson.Basic.to_string value

let parse_task_list json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest -> (
              match parse_task (json_item_text item) with
              | Ok parsed -> loop (parsed :: acc) rest
              | Error _ as error -> error)
        in
        loop [] items
    | _ -> Error (Repository.Storage "Expected a JSON array for tasks list")
  with exn ->
    Error (Repository.Storage ("Failed to decode tasks JSON: " ^ pp_exn exn))

let parse_submission_list json_text =
  try
    let json = Yojson.Basic.from_string json_text in
    match json with
    | `List items ->
        let rec loop acc = function
          | [] -> Ok (List.rev acc)
          | item :: rest -> (
              match parse_submission (json_item_text item) with
              | Ok parsed -> loop (parsed :: acc) rest
              | Error _ as error -> error)
        in
        loop [] items
    | _ -> Error (Repository.Storage "Expected a JSON array for submissions list")
  with exn ->
    Error
      (Repository.Storage ("Failed to decode submissions JSON: " ^ pp_exn exn))
