open Yojson.Basic.Util

let pick_one list =
  match list with
  | [] -> failwith "pick_one requires a non-empty list"
  | _ -> List.nth list (Random.int (List.length list))

let sample_count ~min_value ~max_value =
  min_value + Random.int (max 1 (max_value - min_value + 1))

let unique_names ~prefix count =
  List.init count (fun index -> Printf.sprintf "%s%d" prefix index)

let choose_subset values ~min_count ~max_count =
  let shuffled = Array.of_list values in
  for index = Array.length shuffled - 1 downto 1 do
    let other = Random.int (index + 1) in
    let tmp = shuffled.(index) in
    shuffled.(index) <- shuffled.(other);
    shuffled.(other) <- tmp
  done;
  let upper = min max_count (Array.length shuffled) in
  let lower = min min_count upper in
  let size =
    if upper <= lower then lower else lower + Random.int (upper - lower + 1)
  in
  Array.to_list (Array.sub shuffled 0 size)

let nfa_transition_json ~from_state ~to_state ~symbol =
  `Assoc
    [
      ("from", `String from_state);
      ("to", `String to_state);
      ("symbol", match symbol with Some value -> `String value | None -> `Null);
    ]

let generate_nfa () =
  let state_count = sample_count ~min_value:2 ~max_value:5 in
  let alphabet_count = sample_count ~min_value:1 ~max_value:3 in
  let states = unique_names ~prefix:"q" state_count in
  let alphabet = unique_names ~prefix:"a" alphabet_count in
  let start_states = choose_subset states ~min_count:1 ~max_count:2 in
  let accept_states = choose_subset states ~min_count:1 ~max_count:2 in
  let max_transitions = min 7 (state_count * (state_count + alphabet_count + 1)) in
  let transition_target = sample_count ~min_value:1 ~max_value:max_transitions in
  let rec build_transitions seen acc =
    if List.length acc >= transition_target then
      List.rev acc
    else
      let from_state = pick_one states in
      let to_state = pick_one states in
      let symbol =
        if Random.bool () then
          Some (pick_one alphabet)
        else
          None
      in
      let key =
        match symbol with
        | Some value -> Printf.sprintf "%s\000%s\000%s" from_state to_state value
        | None -> Printf.sprintf "%s\000%s\000<epsilon>" from_state to_state
      in
      if List.mem key seen then
        build_transitions seen acc
      else
        build_transitions (key :: seen)
          (nfa_transition_json ~from_state ~to_state ~symbol :: acc)
  in
  let transitions = build_transitions [] [] in
  `Assoc
    [
      ("type", `String "NFA");
      ( "model",
        `Assoc
          [
            ("states", `List (List.map (fun value -> `String value) states));
            ( "inputAlphabet",
              `List (List.map (fun value -> `String value) alphabet) );
            ("transitions", `List transitions);
            ( "startStates",
              `List (List.map (fun value -> `String value) start_states) );
            ( "acceptStates",
              `List (List.map (fun value -> `String value) accept_states) );
          ] );
    ]

let generate_for_model_type = function
  | Domain.Nfa -> Ok (generate_nfa ())
  | Domain.Cfg | Domain.Pda | Domain.Lba | Domain.Tm ->
      Error "mock model generation is not implemented for this model type yet"

let generate_for_task ~task_type ~config =
  match task_type with
  | "MODEL_CONSTRUCTION" -> (
      match config |> member "requiredModelType" with
      | `String value -> (
          match Domain.model_type_of_string value with
          | Some model_type -> generate_for_model_type model_type
          | None -> Error "task config has an unsupported requiredModelType")
      | _ -> Error "task config is missing requiredModelType")
  | _ -> Error "mock model generation is not implemented for this task type"
