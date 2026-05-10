let ( let* ) = Lwt.bind

type client = {
  base_url : string;
}

type actor = {
  user_id : int;
  username : string;
  email : string;
  password : string;
  client_id : string;
}

type session = {
  actor : actor;
  access_token : string;
  refresh_token : string;
}

type task = {
  id : int;
  slug : string;
  title : string;
  difficulty : int;
  type_ : string;
}

type submission = {
  id : int;
  task_id : int;
  user_id : int;
  verdict : string;
}

let make ~base_url = { base_url }

let ok value = Lwt.return (Ok value)

let error message = Lwt.return (Error message)

let parse_json body =
  try Ok (Yojson.Basic.from_string body)
  with Yojson.Json_error message ->
    Error ("Invalid JSON response: " ^ message ^ " body=" ^ body)

let error_message body =
  match parse_json body with
  | Ok json -> (
      match Yojson.Basic.Util.member "error" json |> Yojson.Basic.Util.member "message" with
      | `String message -> message
      | _ -> body)
  | Error _ -> body

let http_request client ?access_token ?(headers = []) ?(body = "") ~meth path =
  Lwt.catch
    (fun () ->
      Lwt_preemptive.detach
        (fun () ->
          Http_client.request ?access_token ~body ~headers ~base_url:client.base_url
            ~meth path)
        ()
      |> Lwt.map Result.ok)
    (fun exn -> error (Printexc.to_string exn))

let test_client_header client_id = ("X-Recognita-Test-Client", client_id)

let json_request client ?access_token ?(headers = []) ~client_id ~meth path json_body =
  let body = Yojson.Basic.to_string json_body in
  http_request client ?access_token
    ~headers:(test_client_header client_id :: ("Content-Type", "application/json") :: headers)
    ~body ~meth path

let expect_status response expected =
  if response.Http_client.status_code = expected then
    Ok response
  else
    Error
      (Printf.sprintf "HTTP %d expected %d: %s" response.status_code expected
         (error_message response.body))

let actor_of_identity ~user_id (identity : Mock_identity.person) =
  {
    user_id;
    username = identity.username;
    email = identity.email;
    password = identity.password;
    client_id = identity.client_id;
  }

let make_actor ~username ~password ~client_id =
  {
    user_id = 0;
    username;
    email = "";
    password;
    client_id;
  }

let session_of_auth_json identity json =
  let open Yojson.Basic.Util in
  {
    actor = actor_of_identity ~user_id:(json |> member "user" |> member "id" |> to_int) identity;
    access_token = json |> member "tokens" |> member "access_token" |> to_string;
    refresh_token = json |> member "tokens" |> member "refresh_token" |> to_string;
  }

let register client (identity : Mock_identity.person) =
  let* response =
    json_request client ~client_id:identity.client_id ~meth:"POST"
      "/api/v1/auth/register"
      (`Assoc
        [
          ("username", `String identity.username);
          ("email", `String identity.email);
          ("password", `String identity.password);
        ])
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 201, parse_json raw_response.body with
      | Ok _, Ok json -> ok (session_of_auth_json identity json)
      | Error message, _ | _, Error message -> error message)

let login client (actor : actor) =
  let* response =
    json_request client ~client_id:actor.client_id ~meth:"POST"
      "/api/v1/auth/login"
      (`Assoc
        [
          ("username", `String actor.username);
          ("password", `String actor.password);
        ])
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200, parse_json raw_response.body with
      | Ok _, Ok json ->
          ok
            {
              actor = { actor with user_id = json |> Yojson.Basic.Util.member "user" |> Yojson.Basic.Util.member "id" |> Yojson.Basic.Util.to_int };
              access_token =
                json |> Yojson.Basic.Util.member "tokens" |> Yojson.Basic.Util.member "access_token"
                |> Yojson.Basic.Util.to_string;
              refresh_token =
                json |> Yojson.Basic.Util.member "tokens" |> Yojson.Basic.Util.member "refresh_token"
                |> Yojson.Basic.Util.to_string;
            }
      | Error message, _ | _, Error message -> error message)

let login_with_credentials client ~username ~password ~client_id =
  login client (make_actor ~username ~password ~client_id)

let logout client (session : session) =
  let* response =
    http_request client ~access_token:session.access_token
      ~headers:[ test_client_header session.actor.client_id ] ~meth:"POST"
      "/api/v1/auth/logout"
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200 with
      | Ok _ -> ok ()
      | Error message -> error message)

let delete_current_user client (session : session) =
  let* response =
    http_request client ~access_token:session.access_token
      ~headers:[ test_client_header session.actor.client_id ] ~meth:"DELETE"
      "/api/v1/me"
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200 with
      | Ok _ -> ok ()
      | Error message -> error message)

let list_tasks client ?(client_id = "loadtest-public") () =
  let* response =
    http_request client ~headers:[ test_client_header client_id ] ~meth:"GET"
      "/api/v1/tasks"
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200, parse_json raw_response.body with
      | Ok _, Ok json ->
          let open Yojson.Basic.Util in
          let tasks =
            json |> member "tasks" |> to_list
            |> List.filter_map (fun item ->
                   match item |> member "slug" with
                   | `String slug ->
                       Some
                         {
                           id = item |> member "id" |> to_int;
                           slug;
                           title = item |> member "title" |> to_string;
                           difficulty = item |> member "difficulty" |> to_int;
                           type_ = item |> member "type" |> to_string;
                         }
                   | _ -> None)
          in
          ok tasks
      | Error message, _ | _, Error message -> error message)

let get_task_by_slug client ?(client_id = "loadtest-public") slug =
  let* response =
    http_request client ~headers:[ test_client_header client_id ] ~meth:"GET"
      ("/api/v1/tasks/slug/" ^ Uri.pct_encode slug)
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200, parse_json raw_response.body with
      | Ok _, Ok json ->
          let open Yojson.Basic.Util in
          let task = json |> member "task" in
          ok
            {
              id = task |> member "id" |> to_int;
              slug = task |> member "slug" |> to_string;
              title = task |> member "title" |> to_string;
              difficulty = task |> member "difficulty" |> to_int;
              type_ = task |> member "type" |> to_string;
            }
      | Error message, _ | _, Error message -> error message)

let create_task client (session : session) ?client_id ?author_id ~title
    ~description ~difficulty () =
  let base_fields =
    [
      ("title", `String title);
      ("description", `String description);
      ("type", `String "MODEL_CONSTRUCTION");
      ("difficulty", `Int difficulty);
      ("config", `Assoc [ ("version", `Int 1); ("grader", `Assoc [ ("kind", `String "mock") ]) ]);
      ("status", `String "PUBLISHED");
      ("visibility", `String "PUBLIC");
    ]
  in
  let fields =
    match author_id with
    | Some value -> ("author_id", `Int value) :: base_fields
    | None -> base_fields
  in
  let* response =
    json_request client ~access_token:session.access_token
      ~client_id:
        (match client_id with Some value -> value | None -> session.actor.client_id)
      ~meth:"POST" "/api/v1/tasks"
      (`Assoc fields)
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 201, parse_json raw_response.body with
      | Ok _, Ok json ->
          let open Yojson.Basic.Util in
          let task = json |> member "task" in
          ok
            {
              id = task |> member "id" |> to_int;
              slug = task |> member "slug" |> to_string;
              title = task |> member "title" |> to_string;
              difficulty = task |> member "difficulty" |> to_int;
              type_ = task |> member "type" |> to_string;
            }
      | Error message, _ | _, Error message -> error message)

let submit client (session : session) ~task_id ~data =
  let* response =
    json_request client ~access_token:session.access_token
      ~client_id:session.actor.client_id ~meth:"POST"
      ("/api/v1/tasks/" ^ string_of_int task_id ^ "/submissions")
      (`Assoc [ ("data", data) ])
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 201, parse_json raw_response.body with
      | Ok _, Ok json ->
          let open Yojson.Basic.Util in
          let submission = json |> member "submission" in
          ok
            {
              id = submission |> member "id" |> to_int;
              task_id = submission |> member "task_id" |> to_int;
              user_id = submission |> member "user_id" |> to_int;
              verdict = submission |> member "verdict" |> to_string;
            }
      | Error message, _ | _, Error message -> error message)

let list_submissions client (session : session) ~scope =
  let scope_name = match scope with `Mine -> "mine" | `All -> "all" in
  let* response =
    http_request client ~access_token:session.access_token
      ~headers:[ test_client_header session.actor.client_id ] ~meth:"GET"
      ("/api/v1/submissions?scope=" ^ scope_name)
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200, parse_json raw_response.body with
      | Ok _, Ok json ->
          let open Yojson.Basic.Util in
          let submissions =
            json |> member "submissions" |> to_list
            |> List.map (fun item ->
                   {
                     id = item |> member "id" |> to_int;
                     task_id = item |> member "task_id" |> to_int;
                     user_id = item |> member "user_id" |> to_int;
                     verdict = item |> member "verdict" |> to_string;
                   })
          in
          ok submissions
      | Error message, _ | _, Error message -> error message)

let get_submission client (session : session) ~submission_id =
  let* response =
    http_request client ~access_token:session.access_token
      ~headers:[ test_client_header session.actor.client_id ] ~meth:"GET"
      ("/api/v1/submissions/" ^ string_of_int submission_id)
  in
  match response with
  | Error _ as error -> Lwt.return error
  | Ok raw_response -> (
      match expect_status raw_response 200, parse_json raw_response.body with
      | Ok _, Ok json ->
          let open Yojson.Basic.Util in
          let submission = json |> member "submission" in
          ok
            (`Assoc
              [
                ("id", `Int (submission |> member "id" |> to_int));
                ("task_id", `Int (submission |> member "task_id" |> to_int));
                ("user_id", `Int (submission |> member "user_id" |> to_int));
                ("verdict", `String (submission |> member "verdict" |> to_string));
                ("data", submission |> member "data");
              ])
      | Error message, _ | _, Error message -> error message)
