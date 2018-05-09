
(* Other things to try: memory-mapped files *)

(*
module Big = Bigarray
module Gen = Bigarray.Genarray
module Unix = Core.Unix
module BP = Bin_prot
*)
module NDG = Owl.Dense.Ndarray.Generic

(* open Bin_prot.Std *)

let serialize x filename =
  let dims = NDG.shape x in
  let len = Array.fold_left ( * ) 1 dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let a = Bigarray.reshape_1 x' len in
  let size = len + (Bin_prot.Size.bin_size_float64_vec a) + 1 in  (* Is this right?  Why? *)
  let buf = Bin_prot.Common.create_buf size in 
  Bin_prot.Write.bin_write_float64_vec buf 0 a;
  let write_file fd = Core.Bigstring.write ~pos:0 ~len:size fd buf in
  Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] write_file (* O_TRUNC ... What should be done if the file exist? *)

(*
Bigarray.genarray_of_array1 a';;
Bigarray.reshape_2 (Bigarray.genarray_of_array1 a') 3 2;;
*)


  
