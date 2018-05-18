open Testlib

let usage argv =
  print_string "Tests serializing and unserializing ndarrays to/from disk\n";
  Printf.printf "Usage: %s megabytes_in_file number_of_cycles\n" argv.(0);
  exit 1

let main () =
  let open Sys in (* for argv *)
  let num_args = Array.length argv in
  if num_args <> 3 then usage argv else
  let mb = int_of_string argv.(1) in
  let cycles = int_of_string argv.(2) in
  Owl_bin_prot.test_serialize mb cycles

let _ = main ()
