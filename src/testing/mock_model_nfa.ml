open Mock_model_support

let transition_json ~from_state ~to_state ~symbol =
  `Assoc
    [
      ("from", `String from_state);
      ("to", `String to_state);
      ("symbol", match symbol with Some value -> `String value | None -> `Null);
    ]

let generate () =
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
          (transition_json ~from_state ~to_state ~symbol :: acc)
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
