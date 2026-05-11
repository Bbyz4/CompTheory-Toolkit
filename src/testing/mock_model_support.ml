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
