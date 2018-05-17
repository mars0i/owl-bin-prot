module Owl_bin_prot = OBP
Module OS = Bos.OS

let main () =
  let depth =
    OS.Arg.(opt ["m"; "megabytes"] int ~absent:2 ~doc:"Number of megabytes of a test ndarray to serialize.")
  in
  let pos_args = OS.Arg.(parse ~pos:string ()) in
  (* No command line error or help request occured, run the program. *)
  OBP.test_serialize ~size:

let main () = main ()
