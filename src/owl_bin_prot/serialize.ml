
(* TODO: Consider hiding
   the ppx_bin_prot-generated functions.  (If it's possible to
   embed some data structure here in a larger structure, maybe
   those functions need to visible??) *)

open Bin_prot.Std    (* for @@deriving bin_prot *)
open Bin_prot.Common (* for @@deriving bin_prot *)

(* These should go somewhere else *)

let time_print_return f =
    let cpu_time, wall_time = Sys.time(), Unix.gettimeofday() in
    let result = f () in
    Printf.printf "cpu: %fs, wall: %fs\n%!" (Sys.time() -. cpu_time) (Unix.gettimeofday() -. wall_time);
    result

let time_return_times f =
    let cpu_time, wall_time = Sys.time(), Unix.gettimeofday() in
    let result = f () in
    let cpu_time = Sys.time() -. cpu_time in
    let wall_time = Unix.gettimeofday() -. wall_time in
    (result, cpu_time, wall_time)

let multiply_array_elts ra = Array.fold_left ( * ) 1 ra

type flattened = {dims : int array ; data : vec} [@@deriving bin_io]

let ndarray_to_flattened x =
  let dims = Owl.Dense.Ndarray.Generic.shape x in
  let len = multiply_array_elts dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let data = Bigarray.reshape_1 x' len in  (* Bigarray.Array1 with float64 and fortran_layout is compatible with Bin_prot's vec *)
  {dims; data}

let serialize x =
  let flat = ndarray_to_flattened x in
  let buf = create_buf (bin_size_flattened flat) in
  ignore (bin_write_flattened buf 0 flat);(* TODO maybe store return bytes read and compare with size and throw exception *)
  buf

let save_serialized buf filename =
  let size = buf_len buf in
  let write_file fd = Core.Bigstring.write fd ~pos:0 ~len:size buf in
  ignore(Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] ~f:write_file) (* O_TRUNC ... What should be done if the file exists? *)

let serialize_to_file x filename =
  save_serialized (serialize x) filename


let load_serialized filename =
  let read_file fd =
    let stats = Core.Unix.fstat fd in  (* Will this work correctly on symbolic links? If not use stat on the filename. *)
    let size = Int64.to_int (stats.st_size) in
    let buf = Bin_prot.Common.create_buf size in
    ignore(Core.Bigstring.read ~pos:0 ~len:size fd buf); (* TODO maybe store return bytes read and compare with size and throw exception *)
    buf
  in Core.Unix.(with_file filename ~mode:[O_RDONLY] ~f:read_file)

let flattened_to_ndarray flat =
  let {dims; data} = flat in
  let still_flat = Bigarray.Array1.change_layout data Bigarray.c_layout in
  Bigarray.reshape (Bigarray.genarray_of_array1 still_flat) dims

let unserialize buf =
  let posref = ref 0 in
  let flat = bin_read_flattened buf posref in
  flattened_to_ndarray flat

let unserialize_from_file filename =
  unserialize (load_serialized filename)

(* Move these somewhere else: *)

let test_serialize_once ?(gc=false) nd =
  let filename = Core.Filename.temp_file "owl_bin_prot_test" "" in
  if gc then Gc.major ();
  let (_, serial_cpu, serial_wall) = time_return_times (fun () -> serialize_to_file nd filename) in
  if gc then Gc.major ();
  let (nd', unser_cpu, unser_wall) = time_return_times (fun () -> unserialize_from_file filename) in
  Core.Unix.unlink filename;
  nd = nd', [serial_cpu; serial_wall; unser_cpu; unser_wall]

[@@@ warning "-8"] (* disable match warning on the list assignment. https://stackoverflow.com/a/46006016/1455243 *)
let test_serialize ?(gc=false) mb cycles =
  let xdim, ydim, zdim = 1000, 1000, mb in
  let nd = Owl.Arr.uniform [| xdim ; ydim ; zdim |] in
  let float_cycles = float cycles in
  let init_times = [0.; 0.; 0.; 0.] in
  let times = ref init_times in
  for i = 1 to cycles do
    let (_, new_times) = test_serialize_once ~gc nd in
    times := List.map2 (+.) !times new_times
  done;
  let [avg_serial_cpu; avg_serial_wall; avg_unser_cpu; avg_unser_wall] = 
        List.map (fun x -> x /. float_cycles) !times
  in
  Printf.printf "%d trials with a %dM-element ndarray:\n%!" cycles mb;
  Printf.printf "average for serialization:   cpu: %fs, wall: %fs\n%!" avg_serial_cpu avg_serial_wall;
  Printf.printf "average for unserialization: cpu: %fs, wall: %fs\n%!" avg_unser_cpu  avg_unser_wall
[@@@ warning "+8"]