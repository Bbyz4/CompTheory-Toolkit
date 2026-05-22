open Yojson.Basic.Util

type message = {
  submission_id : int;
}

type t = {
  ensure_ready : unit -> (unit, string) result Lwt.t;
  publish_submission : submission_id:int -> (unit, string) result Lwt.t;
  pull_submission : unit -> (message option, string) result Lwt.t;
}

let ok value = Lwt.return (Ok value)

let error message = Lwt.return (Error message)

let base64_encode value =
  let alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  in
  let length = String.length value in
  let buffer = Buffer.create (((length + 2) / 3) * 4) in
  let rec loop index =
    if index >= length then
      ()
    else
      let a = Char.code value.[index] in
      let b = if index + 1 < length then Char.code value.[index + 1] else 0 in
      let c = if index + 2 < length then Char.code value.[index + 2] else 0 in
      let triple = (a lsl 16) lor (b lsl 8) lor c in
      Buffer.add_char buffer alphabet.[(triple lsr 18) land 0x3f];
      Buffer.add_char buffer alphabet.[(triple lsr 12) land 0x3f];
      if index + 1 < length then
        Buffer.add_char buffer alphabet.[(triple lsr 6) land 0x3f]
      else
        Buffer.add_char buffer '=';
      if index + 2 < length then
        Buffer.add_char buffer alphabet.[triple land 0x3f]
      else
        Buffer.add_char buffer '=';
      loop (index + 3)
  in
  loop 0;
  Buffer.contents buffer

let basic_auth_header ~username ~password =
  let credentials = base64_encode (username ^ ":" ^ password) in
  ("Authorization", "Basic " ^ credentials)

let expect_2xx ~context response =
  if response.Http_client.status_code >= 200 && response.status_code < 300 then
    Ok response
  else
    Error
      (Printf.sprintf "%s failed with HTTP %d: %s" context response.status_code
         response.body)

let json_request ~base_url ~headers ~meth path body =
  try
    let response =
      Http_client.request ~base_url ~meth ~body
        ~headers:(("Content-Type", "application/json") :: headers)
        path
    in
    Ok response
  with exn ->
    Error (Printf.sprintf "HTTP request failed: %s" (Printexc.to_string exn))

let make_memory () =
  let queue : int Queue.t = Queue.create () in
  {
    ensure_ready = (fun () -> ok ());
    publish_submission =
      (fun ~submission_id ->
        Queue.push submission_id queue;
        ok ());
    pull_submission =
      (fun () ->
        if Queue.is_empty queue then
          ok None
        else
          ok (Some { submission_id = Queue.pop queue }));
  }

let make_rabbitmq_http ~base_url ~username ~password ~vhost ~queue_name () =
  let headers = [ basic_auth_header ~username ~password ] in
  let vhost_path = Uri.pct_encode vhost in
  let queue_path = Uri.pct_encode queue_name in
  let ensure_ready () =
    let body =
      Yojson.Basic.to_string
        (`Assoc
          [
            ("durable", `Bool true);
            ("auto_delete", `Bool false);
            ("arguments", `Assoc []);
          ])
    in
    match
      json_request ~base_url ~headers ~meth:"PUT"
        ("/api/queues/" ^ vhost_path ^ "/" ^ queue_path)
        body
    with
    | Error message -> error message
    | Ok response -> (
        match expect_2xx ~context:"Ensuring RabbitMQ queue" response with
        | Ok _ -> ok ()
        | Error message -> error message)
  in
  let publish_submission ~submission_id =
    let body =
      Yojson.Basic.to_string
        (`Assoc
          [
            ("properties", `Assoc [ ("delivery_mode", `Int 2) ]);
            ("routing_key", `String queue_name);
            ("payload", `String (string_of_int submission_id));
            ("payload_encoding", `String "string");
          ])
    in
    match
      json_request ~base_url ~headers ~meth:"POST"
        ("/api/exchanges/" ^ vhost_path ^ "/amq.default/publish")
        body
    with
    | Error message -> error message
    | Ok response -> (
        match expect_2xx ~context:"Publishing submission to RabbitMQ" response with
        | Error message -> error message
        | Ok published_response ->
            let json = Yojson.Basic.from_string published_response.body in
            if json |> member "routed" |> to_option to_bool = Some true then
              ok ()
            else
              error "Publishing submission to RabbitMQ returned routed=false")
  in
  let pull_submission () =
    let body =
      Yojson.Basic.to_string
        (`Assoc
          [
            ("count", `Int 1);
            ("ackmode", `String "ack_requeue_false");
            ("encoding", `String "auto");
            ("truncate", `Int 65536);
          ])
    in
    match
      json_request ~base_url ~headers ~meth:"POST"
        ("/api/queues/" ^ vhost_path ^ "/" ^ queue_path ^ "/get")
        body
    with
    | Error message -> error message
    | Ok response -> (
        match expect_2xx ~context:"Pulling submission from RabbitMQ" response with
        | Error message -> error message
        | Ok get_response -> (
            try
              let json = Yojson.Basic.from_string get_response.body in
              match json with
              | `List [] -> ok None
              | `List (item :: _) -> (
                  match item |> member "payload" |> to_option to_string with
                  | Some payload -> (
                      match int_of_string_opt payload with
                      | Some submission_id -> ok (Some { submission_id })
                      | None ->
                          error
                            ("RabbitMQ payload is not an integer submission id: "
                           ^ payload))
                  | None -> error "RabbitMQ message does not contain a string payload")
              | _ -> error "RabbitMQ get endpoint did not return a JSON array"
            with exn ->
              error
                (Printf.sprintf "Failed to decode RabbitMQ response: %s"
                   (Printexc.to_string exn))))
  in
  { ensure_ready; publish_submission; pull_submission }
