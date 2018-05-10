
(* Other things to try: memory-mapped files *)

(*
module Big = Bigarray
module Gen = Bigarray.Genarray
module Unix = Core.Unix
module BP = Bin_prot
module NDG = Owl.Dense.Ndarray.Generic
*)

open Bin_prot.Std (* for @@deriving bin_prot *)


let time f =
    let cpu_time, wall_time = Sys.time(), Unix.gettimeofday() in
    let result = f () in
    Printf.printf "cpu: %fs, wall: %fs\n%!" (Sys.time() -. cpu_time) (Unix.gettimeofday() -. wall_time);
    result


type serialized = 
  {dims : int array ;
   bigarray1 : (float, CamlinternalBigarray.float64_elt, CamlinternalBigarray.fortran_layout) Bigarray.Array1.t
  } [@@deriving bin_io]

(** Multiply together elements of a numeric array. *)
let multiply_array_elts ra = Array.fold_left ( * ) 1 ra

let calc_bin_prot_size ba1 len =
  1 + len + (Bin_prot.Size.bin_size_float64_vec ba1)  (* IS THIS RIGHT? WHY? *)

let serialize x =
  let dims = Owl.Dense.Ndarray.Generic.shape x in
  let len = multiply_array_elts dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let ba1 = Bigarray.reshape_1 x' len in

  let bufsize = calc_bin_prot_size ba1 len in
  let buf = Bin_prot.Common.create_buf bufsize in 
  ignore (Bin_prot.Write.bin_write_float64_vec buf 0 ba1);
  {dims; buf}
  (* BUG this is only writing out the data, but I need it o write the dims as well. *)

let save_serialized sed filename =
  let {dims; buf} = sed in
  let size = Bin_prot.Common.buf_len buf in
  let write_file fd =
    Core.Bigstring.write fd ~pos:0 ~len:size  buf in
  Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] ~f:write_file (* O_TRUNC ... What should be done if the file exist? *)

let serialize_to_file x filename =
  save_serialized (serialize x) filename


let load_serialized filename =
  let read_file fd =
    let stats = Core.Unix.fstat fd in  (* Will this work correctly on symbolic links? If not use stat on the filename. *)
    let size = Int64.to_int (stats.st_size) in
    let buf = Bin_prot.Common.create_buf size in
    ignore (Core.Bigstring.read ~pos:0 ~len:size fd buf);
    {dims = [|size|]; buf=buf} (* Is this correct?? NO! TODO KLUDGE *)
  in Core.Unix.(with_file filename ~mode:[O_RDONLY] ~f:read_file)

(*
Bigarray.genarray_of_array1 a';;
Bigarray.reshape_2 (Bigarray.genarray_of_array1 a') 3 2;;
*)


  
