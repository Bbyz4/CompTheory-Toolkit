open Model_json_support

let template_json () =
  `Assoc
    [
      ("type", `String "NFA");
      ( "model",
        `Assoc
          [
            ("states", `List []);
            ("inputAlphabet", `List []);
            ("transitions", `List []);
            ("startStates", `List []);
            ("acceptStates", `List []);
          ] );
    ]

let example_json () =
  `Assoc
    [
      ("type", `String "NFA");
      ( "model",
        `Assoc
          [
            ("states", `List [ `String "q0"; `String "q1" ]);
            ("inputAlphabet", `List [ `String "a" ]);
            ( "transitions",
              `List
                [
                  `Assoc
                    [
                      ("from", `String "q0");
                      ("to", `String "q1");
                      ("symbol", `String "a");
                    ];
                  `Assoc
                    [
                      ("from", `String "q1");
                      ("to", `String "q1");
                      ("symbol", `Null);
                    ];
                ] );
            ("startStates", `List [ `String "q0" ]);
            ("acceptStates", `List [ `String "q1" ]);
          ] );
    ]

let validate json =
  let* model =
    let* model_json = require_member "model" "model" json in
    require_object "model" model_json
  in
  let* states = require_member "model.states" "states" model in
  let* states = require_string_list "model.states" states in
  if states = [] then
    Error (error "model.states" "must contain at least one state")
  else
    let* input_alphabet = require_member "model.inputAlphabet" "inputAlphabet" model in
    let* input_alphabet = require_string_list "model.inputAlphabet" input_alphabet in
    let overlapping_symbols =
      List.filter (fun symbol -> List.mem symbol states) input_alphabet
    in
    if overlapping_symbols <> [] then
      Error
        (error "model.inputAlphabet"
           "must be disjoint from model.states")
    else
      let* start_states = require_member "model.startStates" "startStates" model in
      let* start_states = require_string_list "model.startStates" start_states in
      if start_states = [] then
        Error (error "model.startStates" "must contain at least one state")
      else
        let* _validated_start_states =
          validate_subset ~field:"model.startStates" ~superset:states start_states
        in
        let* accept_states =
          require_member "model.acceptStates" "acceptStates" model
        in
        let* accept_states =
          require_string_list "model.acceptStates" accept_states
        in
        let* _validated_accept_states =
          validate_subset ~field:"model.acceptStates" ~superset:states accept_states
        in
        let* transitions_json = require_member "model.transitions" "transitions" model in
        match transitions_json with
        | `List transitions ->
            let rec loop index seen acc = function
              | [] ->
                  Ok
                    (`Assoc
                       [
                         ("states", `List (List.map (fun value -> `String value) states));
                         ( "inputAlphabet",
                           `List
                             (List.map (fun value -> `String value) input_alphabet)
                         );
                         ("transitions", `List (List.rev acc));
                         ( "startStates",
                           `List (List.map (fun value -> `String value) start_states)
                         );
                         ( "acceptStates",
                           `List (List.map (fun value -> `String value) accept_states)
                         );
                       ])
              | item :: rest ->
                  let field = Printf.sprintf "model.transitions[%d]" index in
                  let* transition = require_object field item in
                  let* from_state =
                    require_member (field ^ ".from") "from" transition
                  in
                  let* from_state =
                    require_nonempty_string (field ^ ".from") from_state
                  in
                  let* to_state =
                    require_member (field ^ ".to") "to" transition
                  in
                  let* to_state =
                    require_nonempty_string (field ^ ".to") to_state
                  in
                  let* symbol =
                    match transition |> Yojson.Basic.Util.member "symbol" with
                    | `Null -> Ok None
                    | `String value ->
                        let trimmed = String.trim value in
                        if trimmed = "" then
                          Error (error (field ^ ".symbol") "must not be empty")
                        else
                          Ok (Some trimmed)
                    | _ -> Error (error (field ^ ".symbol") "must be a string or null")
                  in
                  if not (List.mem from_state states) then
                    Error (error (field ^ ".from") "must reference a declared state")
                  else if not (List.mem to_state states) then
                    Error (error (field ^ ".to") "must reference a declared state")
                  else
                    begin
                      match symbol with
                      | Some value when not (List.mem value input_alphabet) ->
                          Error
                            (error (field ^ ".symbol")
                               "must belong to model.inputAlphabet or be null")
                      | _ ->
                          let duplicate_key =
                            match symbol with
                            | Some value ->
                                Printf.sprintf "%s\000%s\000%s" from_state to_state
                                  value
                            | None ->
                                Printf.sprintf "%s\000%s\000<epsilon>" from_state
                                  to_state
                          in
                          if List.mem duplicate_key seen then
                            Error (error field "must not contain duplicate transitions")
                          else
                            let transition_json =
                              `Assoc
                                [
                                  ("from", `String from_state);
                                  ("to", `String to_state);
                                  ( "symbol",
                                    match symbol with
                                    | Some value -> `String value
                                    | None -> `Null );
                                ]
                            in
                            loop (index + 1) (duplicate_key :: seen)
                              (transition_json :: acc) rest
                    end
            in
            let* normalized_model = loop 0 [] [] transitions in
            Ok (`Assoc [ ("type", `String "NFA"); ("model", normalized_model) ])
        | _ -> Error (error "model.transitions" "must be a JSON array")
