type person = {
  first_name : string;
  last_name : string;
  username : string;
  email : string;
  password : string;
  client_id : string;
}

let faker_script_candidates =
  let env_override =
    match Sys.getenv_opt "RECOGNITA_FAKE_IDENTITY_SCRIPT" with
    | Some path when String.trim path <> "" -> [ path ]
    | _ -> []
  in
  env_override
  @
  [
    "scripts/mock_identity_faker.py";
    "/app/scripts/mock_identity_faker.py";
  ]

let faker_script_path () =
  match List.find_opt Sys.file_exists faker_script_candidates with
  | Some path -> path
  | None ->
      failwith
        "faker helper script not found; tried RECOGNITA_FAKE_IDENTITY_SCRIPT, \
         scripts/mock_identity_faker.py, /app/scripts/mock_identity_faker.py"

let read_process_output command args =
  let channel = Unix.open_process_args_in command args in
  let buffer = Buffer.create 4096 in
  let rec loop () =
    match input_line channel with
    | line ->
        Buffer.add_string buffer line;
        Buffer.add_char buffer '\n';
        loop ()
    | exception End_of_file -> ()
  in
  loop ();
  let output = Buffer.contents buffer in
  match Unix.close_process_in channel with
  | Unix.WEXITED 0 -> output
  | Unix.WEXITED code ->
      failwith
        (Printf.sprintf "faker helper exited with code %d: %s" code output)
  | Unix.WSIGNALED signal
  | Unix.WSTOPPED signal ->
      failwith
        (Printf.sprintf "faker helper stopped with signal %d: %s" signal output)

let person_of_yojson = function
  | `Assoc fields ->
      let find name =
        match List.assoc_opt name fields with
        | Some value -> value
        | None -> failwith ("Missing field in generated person: " ^ name)
      in
      {
        first_name = find "first_name" |> Yojson.Basic.Util.to_string;
        last_name = find "last_name" |> Yojson.Basic.Util.to_string;
        username = find "username" |> Yojson.Basic.Util.to_string;
        email = find "email" |> Yojson.Basic.Util.to_string;
        password = find "password" |> Yojson.Basic.Util.to_string;
        client_id = find "client_id" |> Yojson.Basic.Util.to_string;
      }
  | _ -> failwith "Generated person must be a JSON object"

let generate ~seed ~start_index ~count =
  if count < 0 then
    invalid_arg "Mock_identity.generate count must be non-negative";
  if count = 0 then
    []
  else
    let script_path = faker_script_path () in
    let output =
      read_process_output "python3"
        [|
          "python3";
          script_path;
          "--seed";
          string_of_int seed;
          "--start-index";
          string_of_int start_index;
          "--count";
          string_of_int count;
        |]
    in
    let json = Yojson.Basic.from_string output in
    match json with
    | `Assoc [ ("error", `String message) ] ->
        failwith ("faker helper failed: " ^ message)
    | `List items -> List.map person_of_yojson items
    | _ -> failwith "faker helper returned an unexpected payload"

let make ~seed ~index =
  match generate ~seed ~start_index:index ~count:1 with
  | [ person ] -> person
  | _ -> failwith "faker helper did not return exactly one identity"
