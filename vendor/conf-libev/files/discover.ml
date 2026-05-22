let cut_tail l = List.rev (List.tl (List.rev l))

let string_split sep source =
  let copy_part index offset = String.sub source index (offset - index) in
  let length = String.length source in
  let rec loop prev current acc =
    if current >= length then
      List.rev acc
    else
      match (source.[current] = sep, current = prev, current = length - 1) with
      | true, true, _ -> loop (current + 1) (current + 1) acc
      | true, _, _ -> loop (current + 1) (current + 1) (copy_part prev current :: acc)
      | false, _, true ->
          loop (current + 1) (current + 1)
            (copy_part prev (current + 1) :: acc)
      | _ -> loop prev (current + 1) acc
  in
  loop 0 0 []

let uniq lst =
  let table = Hashtbl.create (List.length lst) in
  List.iter (fun item -> Hashtbl.replace table item ()) lst;
  Hashtbl.fold (fun item () acc -> item :: acc) table []

let get_paths env_name =
  try
    let paths = Sys.getenv env_name in
    let dirs = string_split ':' paths in
    List.map
      (fun dir ->
        let components = string_split '/' dir in
        "/" ^ String.concat "/" (cut_tail components))
      dirs
  with Not_found -> []

let env_paths =
  List.append (get_paths "LIBRARY_PATH") (get_paths "C_INCLUDE_PATH")

let search_paths =
  uniq
    (List.append
       [ "/usr"; "/usr/local"; "/opt"; "/opt/local"; "/opt/homebrew"; "/sw"; "/mingw" ]
       env_paths)

let caml_code =
  "external test : unit -> unit = \"lwt_test\"\nlet () = test ()\n"

let libev_code =
  {|
#include <caml/mlvalues.h>
#include <ev.h>

CAMLprim value lwt_test()
{
  ev_default_loop(0);
  return Val_unit;
}
|}

let ocamlc = ref "ocamlc"
let ext_obj = ref ".o"
let exec_name = ref "a.out"
let log_file = ref ""
let caml_file = ref ""

let search_header header =
  let rec loop = function
    | [] -> None
    | dir :: dirs ->
        if Sys.file_exists (dir ^ "/include/" ^ header) then Some dir else loop dirs
  in
  loop search_paths

let c_args =
  match search_header "ev.h" with
  | None -> ""
  | Some path -> Printf.sprintf "-ccopt -I%s/include -ccopt -L%s/lib" path path

let compile c_args args stub_file =
  let cmd =
    Printf.sprintf "%s -custom %s %s %s %s > %s 2>&1" !ocamlc c_args
      (Filename.quote stub_file) args (Filename.quote !caml_file)
      (Filename.quote !log_file)
  in
  Sys.command cmd = 0

let safe_remove file_name = try Sys.remove file_name with _ -> ()

let test_code args stub_code =
  let stub_file, oc = Filename.open_temp_file "lwt_stub" ".c" in
  let cleanup () =
    safe_remove stub_file;
    safe_remove (Filename.chop_extension (Filename.basename stub_file) ^ !ext_obj)
  in
  try
    output_string oc stub_code;
    flush oc;
    close_out oc;
    let result = compile "" args stub_file || compile c_args args stub_file in
    cleanup ();
    result
  with exn ->
    (try close_out oc with _ -> ());
    cleanup ();
    raise exn

let config = open_out "lwt_config.h"
let config_ml = open_out "lwt_config.ml"

let test_feature name macro ?(args = "") code =
  Printf.printf "testing for %s:%!" name;
  if test_code args code then (
    Printf.fprintf config "#define %s\n" macro;
    Printf.fprintf config_ml "#let %s = true\n" macro;
    Printf.printf " available\n%!";
    true)
  else (
    Printf.fprintf config "//#define %s\n" macro;
    Printf.fprintf config_ml "#let %s = false\n" macro;
    Printf.printf " unavailable\n%!";
    false)

let () =
  let args =
    [
      ("-ocamlc", Arg.Set_string ocamlc, "<path> ocamlc");
      ("-ext-obj", Arg.Set_string ext_obj, "<ext> C object files extension");
      ("-exec-name", Arg.Set_string exec_name, "<name> executable name");
    ]
  in
  Arg.parse args ignore "check for external C libraries and available features";
  let file, oc = Filename.open_temp_file "lwt_caml" ".ml" in
  caml_file := file;
  output_string oc caml_code;
  close_out oc;
  log_file := Filename.temp_file "lwt_output" ".log";
  at_exit (fun () ->
      (try close_out config with _ -> ());
      (try close_out config_ml with _ -> ());
      safe_remove !log_file;
      safe_remove !exec_name;
      safe_remove !caml_file;
      safe_remove (Filename.chop_extension !caml_file ^ ".cmi");
      safe_remove (Filename.chop_extension !caml_file ^ ".cmo"));
  if test_feature "libev" "HAVE_LIBEV" ~args:"-cclib -lev" libev_code then
    ()
  else (
    prerr_endline
      "Missing libev. Install the system package and retry, e.g. `brew install libev` on macOS or `sudo apt-get install libev-dev` on Debian/Ubuntu.";
    exit 1)
