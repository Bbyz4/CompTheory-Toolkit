type response = {
  status_code : int;
  reason : string;
  headers : (string * string) list;
  body : string;
}

let parse_base_url base_url =
  let uri = Uri.of_string base_url in
  let host = Option.value (Uri.host uri) ~default:"localhost" in
  let port = Option.value (Uri.port uri) ~default:80 in
  let prefix =
    match Uri.path uri with "" -> "" | "/" -> "" | path -> path
  in
  (host, port, prefix)

let read_headers channel =
  let rec loop acc =
    let line = input_line channel |> String.trim in
    if line = "" then
      List.rev acc
    else
      match Util.split_once ~on:':' line with
      | Some (name, value) -> loop ((String.lowercase_ascii name, String.trim value) :: acc)
      | None -> loop acc
  in
  loop []

let request ?access_token ?(body = "") ?(headers = []) ~base_url ~meth path =
  let host, port, prefix = parse_base_url base_url in
  let sockaddr =
    let info = Unix.getaddrinfo host (string_of_int port) [ Unix.AI_SOCKTYPE Unix.SOCK_STREAM ] in
    match info with
    | [] -> failwith "Could not resolve host"
    | entry :: _ -> entry.Unix.ai_addr
  in
  let ic, oc = Unix.open_connection sockaddr in
  Fun.protect
    ~finally:(fun () ->
      close_in_noerr ic;
      close_out_noerr oc)
    (fun () ->
      let auth_headers =
        match access_token with
        | Some token -> [ ("Authorization", "Bearer " ^ token) ]
        | None -> []
      in
      let all_headers =
        [
          ("Host", host);
          ("Connection", "close");
          ("Accept", "application/json");
          ("Content-Length", string_of_int (String.length body));
        ]
        @ auth_headers
        @ headers
      in
      output_string oc
        (Printf.sprintf "%s %s%s HTTP/1.1\r\n" meth prefix path);
      List.iter
        (fun (name, value) ->
          output_string oc (Printf.sprintf "%s: %s\r\n" name value))
        all_headers;
      output_string oc "\r\n";
      output_string oc body;
      flush oc;
      let status_line = input_line ic |> String.trim in
      let parts = String.split_on_char ' ' status_line in
      let status_code =
        match parts with
        | _version :: code :: _ -> int_of_string code
        | _ -> failwith ("Invalid status line: " ^ status_line)
      in
      let reason =
        match parts with
        | _version :: _code :: rest -> String.concat " " rest
        | _ -> ""
      in
      let headers = read_headers ic in
      let content_length =
        match List.assoc_opt "content-length" headers with
        | Some value -> Option.value (int_of_string_opt value) ~default:0
        | None -> 0
      in
      let body =
        if content_length > 0 then
          really_input_string ic content_length
        else
          let buffer = Buffer.create 256 in
          (try
             while true do
               Buffer.add_char buffer (input_char ic)
             done
           with End_of_file -> ());
          Buffer.contents buffer
      in
      { status_code; reason; headers; body })
