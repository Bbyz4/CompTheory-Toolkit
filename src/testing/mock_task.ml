type spec = {
  title : string;
  description : string;
  difficulty : int;
}

let faker_script_candidates () =
  let env_override =
    match Sys.getenv_opt "RECOGNITA_FAKE_TASK_SCRIPT" with
    | Some path when String.trim path <> "" -> [ path ]
    | _ -> []
  in
  env_override @ [ "scripts/mock_task_faker.py"; "/app/scripts/mock_task_faker.py" ]

let faker_script_path () =
  match List.find_opt Sys.file_exists (faker_script_candidates ()) with
  | Some path -> path
  | None ->
      failwith
        "faker task helper script not found; tried RECOGNITA_FAKE_TASK_SCRIPT, \
         scripts/mock_task_faker.py, /app/scripts/mock_task_faker.py"

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
        (Printf.sprintf "task faker helper exited with code %d: %s" code output)
  | Unix.WSIGNALED signal
  | Unix.WSTOPPED signal ->
      failwith
        (Printf.sprintf "task faker helper stopped with signal %d: %s" signal output)

let spec_of_yojson = function
  | `Assoc fields ->
      let find name =
        match List.assoc_opt name fields with
        | Some value -> value
        | None -> failwith ("Missing field in generated task spec: " ^ name)
      in
      {
        title = find "title" |> Yojson.Basic.Util.to_string;
        description = find "description" |> Yojson.Basic.Util.to_string;
        difficulty = find "difficulty" |> Yojson.Basic.Util.to_int;
      }
  | _ -> failwith "Generated task spec must be a JSON object"

let generate ~seed ~start_index ~count =
  if count < 0 then
    invalid_arg "Mock_task.generate count must be non-negative";
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
        failwith ("task faker helper failed: " ^ message)
    | `List items -> List.map spec_of_yojson items
    | _ -> failwith "task faker helper returned an unexpected payload"

let make ~seed ~index =
  match generate ~seed ~start_index:index ~count:1 with
  | [ spec ] -> spec
  | _ -> failwith "task faker helper did not return exactly one task spec"
