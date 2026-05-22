let ( let* ) = Lwt.bind

let ( let+ ) promise f = Lwt.map f promise

let starts_with ~prefix value =
  let prefix_length = String.length prefix in
  String.length value >= prefix_length
  && String.sub value 0 prefix_length = prefix

let split_once ~on value =
  match String.index_opt value on with
  | None -> None
  | Some index ->
      let left = String.sub value 0 index in
      let right =
        String.sub value (index + 1) (String.length value - index - 1)
      in
      Some (left, right)

let strip_query target =
  match String.index_opt target '?' with
  | None -> target
  | Some index -> String.sub target 0 index

let lower = String.lowercase_ascii

let trim = String.trim

let header_assoc headers =
  List.map (fun (name, value) -> (lower name, value)) headers

let find_header headers name =
  List.assoc_opt (lower name) (header_assoc headers)

let option value ~default = match value with Some item -> item | None -> default

let constant_time_equal left right =
  if String.length left <> String.length right then
    false
  else
    let diff = ref 0 in
    for index = 0 to String.length left - 1 do
      diff :=
        !diff lor Char.code left.[index] lxor Char.code right.[index]
    done;
    !diff = 0

let string_repeat count value =
  let buffer = Buffer.create (count * String.length value) in
  for _ = 1 to count do
    Buffer.add_string buffer value
  done;
  Buffer.contents buffer

let hex_of_string value =
  let buffer = Buffer.create (String.length value * 2) in
  String.iter
    (fun char -> Buffer.add_string buffer (Printf.sprintf "%02x" (Char.code char)))
    value;
  Buffer.contents buffer

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

let iso8601_of_unix_time seconds =
  let tm = Unix.gmtime seconds in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

let parse_bearer_token headers =
  match find_header headers "authorization" with
  | Some value when starts_with ~prefix:"Bearer " value ->
      Some (String.sub value 7 (String.length value - 7))
  | _ -> None

let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () ->
      let length = in_channel_length channel in
      really_input_string channel length)

let sql_quote value =
  "'" ^ String.concat "''" (String.split_on_char '\'' value) ^ "'"

let sql_nullable = function None -> "NULL" | Some value -> sql_quote value

let pp_exn exn = Printexc.to_string exn
