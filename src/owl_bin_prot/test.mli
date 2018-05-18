

(* These next should go somewhere else since they're not owl_bin_prot specific: *)

val time_print_return : (unit -> 'a) -> 'a
(** Run function that has unit arg, print timing info to stdout, and return 
    result. *)

val time_return_times : (unit -> 'a) -> 'a * float * float
(** Run function that has unit arg, return its result as the first element 
    of a triple.  The other elements are cpu time and wall time. *)

val test_serialise_once : ?gc:bool -> (float, Bigarray.float64_elt) Owl.Dense.Ndarray.Generic.t -> bool * float list
(** By default [test_serialise] creates an ndarray of size 1000x1000xsize
    (default: 1) with [Mat.uniform].  Then the file is serialised to a temporary 
    file.  The result is then unserialised from the file and checked to see if the
    original and copy are equal.  A pair is returned.  The first element is
    true or false, depending on whether the unseralied ndarray is equal to the
    original one.  The second element is a list of four floats, representing
    cpu time spent serializing and writing to disk, wall time in the same
    operations, cpu time spent reading from disk and unserializing, and wall 
    time in those opeations. TODO: add about [gc] *)

val test_serialise : ?gc:bool -> int -> int -> unit
(** TODO *)
