
(* Other things to try: memory-mapped files *)

(*
module Big = Bigarray
module Gen = Bigarray.Genarray
module Unix = Core.Unix
module BP = Bin_prot
module NDG = Owl.Dense.Ndarray.Generic
*)

(* open Bin_prot.Std *)

type serialized = {size : int; buf : Bin_prot.Common.buf}  (* FIXME No this is not right.  size should be an array of dims. call it shape or dims. *)

let serialize x =
  let dims = Owl.Dense.Ndarray.Generic.shape x in
  let len = Array.fold_left ( * ) 1 dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let a = Bigarray.reshape_1 x' len in
  let size = 1 + len + (Bin_prot.Size.bin_size_float64_vec a) in  (* IS THIS RIGHT? WHY? *)
  let buf = Bin_prot.Common.create_buf size in 
  ignore (Bin_prot.Write.bin_write_float64_vec buf 0 a);
  {size; buf}

let save_serialized sed filename =
  let {size; buf} = sed in
  let write_file fd =
    Core.Bigstring.write fd ~pos:0 ~len:size  buf in
  Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] ~f:write_file (* O_TRUNC ... What should be done if the file exist? *)

let serialize_to_file x filename =
  save_serialized (serialize x) filename

let load_serialized filename =
  let read_file fd =
    let stats = Core.Unix.fstat fd in  (* Will this work correctly on symbolic links? If not use stat on the filename. *)
    let size = stats.st_size in
    let buf = Bin_prot.Common.create_buf size in
    let nread = Core.Bigstring.read ~pos:0 ~len:size fd buf in  
    {size; buf} (* Is size correct?? *)
  in Core.Unix.(with_file filename ~mode:[O_RDONLY] ~f:read_file)

(*
Bigarray.genarray_of_array1 a';;
Bigarray.reshape_2 (Bigarray.genarray_of_array1 a') 3 2;;
*)


  
