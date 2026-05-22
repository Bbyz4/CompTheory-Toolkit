open Mock_model_support

let generate () =
  let non_terminal_count = sample_count ~min_value:2 ~max_value:4 in
  let terminal_count = sample_count ~min_value:1 ~max_value:3 in
  let non_terminals = unique_names ~prefix:"N" non_terminal_count in
  let terminals = unique_names ~prefix:"t" terminal_count in
  let start_symbol = List.hd non_terminals in
  let transition_count = sample_count ~min_value:2 ~max_value:6 in
  let grammar_symbols = non_terminals @ terminals in
  let rec rhs length acc =
    if length <= 0 then
      List.rev acc
    else
      rhs (length - 1) (`String (pick_one grammar_symbols) :: acc)
  in
  let rec build_transitions seen acc =
    if List.length acc >= transition_count then
      List.rev acc
    else
      let from_symbol = pick_one non_terminals in
      let rhs_symbols =
        if Random.int 5 = 0 then
          []
        else
          rhs (sample_count ~min_value:1 ~max_value:3) []
      in
      let key =
        Printf.sprintf "%s\000%s" from_symbol
          (String.concat "\000"
             (List.map
                (function `String value -> value | _ -> "")
                rhs_symbols))
      in
      if List.mem key seen then
        build_transitions seen acc
      else
        let transition =
          `Assoc [ ("from", `String from_symbol); ("to", `List rhs_symbols) ]
        in
        build_transitions (key :: seen) (transition :: acc)
  in
  let transitions = build_transitions [] [] in
  `Assoc
    [
      ("type", `String "CFG");
      ( "model",
        `Assoc
          [
            ( "nonTerminals",
              `List (List.map (fun value -> `String value) non_terminals) );
            ("terminals", `List (List.map (fun value -> `String value) terminals));
            ("transitions", `List transitions);
            ("startSymbol", `String start_symbol);
          ] );
    ]
