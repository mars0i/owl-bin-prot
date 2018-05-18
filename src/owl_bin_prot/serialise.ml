
(* TODO: Consider hiding
   the ppx_bin_prot-generated functions.  (If it's possible to
   embed some data structure here in a larger structure, maybe
   those functions need to visible??) *)

open Bin_prot.Std    (* for @@deriving bin_prot *)
open Bin_prot.Common (* for @@deriving bin_prot *)

let multiply_array_elts ra = Array.fold_left ( * ) 1 ra

type flattened = {dims : int array ; data : vec} [@@deriving bin_io]

let ndarray_to_flattened x =
  let dims = Owl.Dense.Ndarray.Generic.shape x in
  let len = multiply_array_elts dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let data = Bigarray.reshape_1 x' len in  (* Bigarray.Array1 with float64 and fortran_layout is compatible with Bin_prot's vec *)
  {dims; data}

let serialise x =
  let flat = ndarray_to_flattened x in
  let buf = create_buf (bin_size_flattened flat) in
  ignore (bin_write_flattened buf 0 flat);(* TODO maybe store return bytes read and compare with size and throw exception *)
  buf

let save_serialised buf filename =
  let size = buf_len buf in
  let write_file fd = Core.Bigstring.write fd ~pos:0 ~len:size buf in
  ignore(Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] ~f:write_file) (* O_TRUNC ... What should be done if the file exists? *)

let serialise_to_file x filename =
  save_serialised (serialise x) filename


let load_serialised filename =
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

let unserialise buf =
  let posref = ref 0 in
  let flat = bin_read_flattened buf posref in
  flattened_to_ndarray flat

let unserialise_from_file filename =
  unserialise (load_serialised filename)
