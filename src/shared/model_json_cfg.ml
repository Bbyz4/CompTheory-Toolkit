open Model_json_support

let template_json () =
  `Assoc
    [
      ("type", `String "CFG");
      ( "model",
        `Assoc
          [
            ("nonTerminals", `List []);
            ("terminals", `List []);
            ("transitions", `List []);
            ("startSymbol", `String "S");
          ] );
    ]

let example_json () =
  `Assoc
    [
      ("type", `String "CFG");
      ( "model",
        `Assoc
          [
            ("nonTerminals", `List [ `String "S"; `String "A" ]);
            ("terminals", `List [ `String "a"; `String "b" ]);
            ( "transitions",
              `List
                [
                  `Assoc
                    [
                      ("from", `String "S");
                      ("to", `List [ `String "A"; `String "b" ]);
                    ];
                  `Assoc
                    [
                      ("from", `String "A");
                      ("to", `List [ `String "a" ]);
                    ];
                  `Assoc [ ("from", `String "A"); ("to", `List []) ];
                ] );
            ("startSymbol", `String "S");
          ] );
    ]

let validate json =
  let* model =
    let* model_json = require_member "model" "model" json in
    require_object "model" model_json
  in
  let* non_terminals =
    require_member "model.nonTerminals" "nonTerminals" model
  in
  let* non_terminals =
    require_string_list "model.nonTerminals" non_terminals
  in
  if non_terminals = [] then
    Error (error "model.nonTerminals" "must contain at least one symbol")
  else
    let* terminals = require_member "model.terminals" "terminals" model in
    let* terminals = require_string_list "model.terminals" terminals in
    let overlapping_symbols =
      List.filter (fun symbol -> List.mem symbol non_terminals) terminals
    in
    if overlapping_symbols <> [] then
      Error
        (error "model.terminals"
           "must be disjoint from model.nonTerminals")
    else
      let grammar_symbols = non_terminals @ terminals in
      let* start_symbol =
        require_member "model.startSymbol" "startSymbol" model
      in
      let* start_symbol =
        require_nonempty_string "model.startSymbol" start_symbol
      in
      if not (List.mem start_symbol non_terminals) then
        Error
          (error "model.startSymbol"
             "must reference a declared non-terminal")
      else
        let* transitions_json =
          require_member "model.transitions" "transitions" model
        in
        match transitions_json with
        | `List transitions ->
            let rec parse_rhs field index acc = function
              | [] -> Ok (List.rev acc)
              | item :: rest ->
                  let* symbol =
                    require_nonempty_string
                      (Printf.sprintf "%s[%d]" field index)
                      item
                  in
                  if List.mem symbol grammar_symbols then
                    parse_rhs field (index + 1) (symbol :: acc) rest
                  else
                    Error
                      (error
                         (Printf.sprintf "%s[%d]" field index)
                         "must belong to model.nonTerminals or model.terminals")
            in
            let rec loop index seen acc = function
              | [] ->
                  Ok
                    (`Assoc
                       [
                         ( "nonTerminals",
                           `List
                             (List.map (fun value -> `String value) non_terminals)
                         );
                         ( "terminals",
                           `List (List.map (fun value -> `String value) terminals)
                         );
                         ("transitions", `List (List.rev acc));
                         ("startSymbol", `String start_symbol);
                       ])
              | item :: rest ->
                  let field = Printf.sprintf "model.transitions[%d]" index in
                  let* transition = require_object field item in
                  let* from_symbol =
                    require_member (field ^ ".from") "from" transition
                  in
                  let* from_symbol =
                    require_nonempty_string (field ^ ".from") from_symbol
                  in
                  if not (List.mem from_symbol non_terminals) then
                    Error
                      (error (field ^ ".from")
                         "must reference a declared non-terminal")
                  else
                    let* rhs_json =
                      require_member (field ^ ".to") "to" transition
                    in
                    begin
                      match rhs_json with
                      | `List rhs_values ->
                          let* rhs_symbols =
                            parse_rhs (field ^ ".to") 0 [] rhs_values
                          in
                          let duplicate_key =
                            Printf.sprintf "%s\000%s" from_symbol
                              (String.concat "\000" rhs_symbols)
                          in
                          if List.mem duplicate_key seen then
                            Error
                              (error field
                                 "must not contain duplicate transitions")
                          else
                            let normalized_transition =
                              `Assoc
                                [
                                  ("from", `String from_symbol);
                                  ( "to",
                                    `List
                                      (List.map
                                         (fun value -> `String value)
                                         rhs_symbols) );
                                ]
                            in
                            loop (index + 1) (duplicate_key :: seen)
                              (normalized_transition :: acc) rest
                      | _ -> Error (error (field ^ ".to") "must be a JSON array")
                    end
            in
            let* normalized_model = loop 0 [] [] transitions in
            Ok (`Assoc [ ("type", `String "CFG"); ("model", normalized_model) ])
        | _ -> Error (error "model.transitions" "must be a JSON array")
