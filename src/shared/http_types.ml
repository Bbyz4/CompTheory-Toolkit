type request = {
  meth : string;
  target : string;
  path : string;
  headers : (string * string) list;
  body : string;
  remote_addr : string;
}

type response = {
  status : int;
  reason : string;
  headers : (string * string) list;
  body : string;
}

let reason_phrase = function
  | 200 -> "OK"
  | 201 -> "Created"
  | 204 -> "No Content"
  | 400 -> "Bad Request"
  | 401 -> "Unauthorized"
  | 403 -> "Forbidden"
  | 404 -> "Not Found"
  | 409 -> "Conflict"
  | 429 -> "Too Many Requests"
  | 500 -> "Internal Server Error"
  | _ -> "OK"

let make ?(headers = []) ~status body =
  { status; reason = reason_phrase status; headers; body }

let json ?(headers = []) ~status payload =
  make
    ~headers:(("content-type", "application/json; charset=utf-8") :: headers)
    ~status (Yojson.Basic.to_string payload)

let text ?(headers = []) ~status body =
  make ~headers:(("content-type", "text/plain; charset=utf-8") :: headers) ~status
    body

let empty ?(headers = []) ~status () = make ~headers ~status ""

