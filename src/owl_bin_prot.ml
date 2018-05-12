
(* Other things to try: memory-mapped files? *)

(* TODO: replace ocamldoc with Owl-style annotations *)

(* TODO: I probably should add an mli file.  Consider hiding
   the ppx_bin_prot-generated functions.  (If it's possible to
   embed some data structure here in a larger structure, maybe
   those functions need to visible??) *)

open Bin_prot.Std    (* for @@deriving bin_prot *)
open Bin_prot.Common (* for @@deriving bin_prot *)

(** Utility functions *)

(** Run function that has unit arg, print timing info to stdout, and return result. *)
let time f =
    let cpu_time, wall_time = Sys.time(), Unix.gettimeofday() in
    let result = f () in
    Printf.printf "cpu: %fs, wall: %fs\n%!" (Sys.time() -. cpu_time) (Unix.gettimeofday() -. wall_time);
    result

(** Multiply together all elements of an [int array]. *)
let multiply_array_elts ra = Array.fold_left ( * ) 1 ra


(** Type [flattened] hold dense matrix/ndarray data prior to/after 
    serialization.
    [dims] should contained the dimensions of the original ndarray, and
    [vec] should contain a flattened version of the ndarray data.
    ([vec] is defined by [Bin_prot.common]; it is a 
    [(float, float64_elt, fortran_layout) Bigarray.Array1].) 
    The functions with names beginning with "bin_" listed immediately 
    after this definition in generated documentation are defined 
    automatically via [[@@deriving bin_io]], which uses [ppx_bin_prot]. 
    These definitions are used in by higher-level serialization functions
    defined here. *)
type flattened = {dims : int array ; data : vec} [@@deriving bin_io]

(** Given a dense matrix/ndarray [x], [serialize x] returns a [bin_prot]
    buffer structure containing a serialized version of an instance of type 
    [flattened], i.e. of an array of dimensions of the original ndarray, and 
    the flattened data from the original ndarray.  A copy of the original
    ndarray can be recreated from the resulting buffer using [unserialize].
    The buffer structure can be saved to a file using [save_serialized]. *)
let serialize x =
  let dims = Owl.Dense.Ndarray.Generic.shape x in
  let len = multiply_array_elts dims in
  let x' = Bigarray.Genarray.change_layout x Bigarray.fortran_layout in
  let data = Bigarray.reshape_1 x' len in  (* Bigarray.Array1 with float64 and fortran_layout is compatible with Bin_prot's vec *)
  let flat = {dims; data} in
  let buf = create_buf (bin_size_flattened flat) in
  ignore (bin_write_flattened buf 0 flat);(* TODO maybe store return bytes read and compare with size and throw exception *)
  buf

(** Given a [bin_prot] buffer created with [serialize], writes it to file
    [filename].  If the file exists, it will be zeroed out and recreated. 
    This file can be read using [load_serialized]. *)
let save_serialized buf filename =
  let size = buf_len buf in
  let write_file fd = Core.Bigstring.write fd ~pos:0 ~len:size buf in
  Core.Unix.with_file filename ~mode:[O_WRONLY; O_CREAT; O_TRUNC] ~f:write_file (* O_TRUNC ... What should be done if the file exists? *)

(** Given a dense matrix/ndarray [x], [serialize_to_file x] transforms it
    into an instance of [flattened], serializes that using [bin_prot], and
    writes the result to file [filename].  If the file exists, it will be 
    zeroed out and recreated. The process can be reversed using 
    [unserialize_from_file]. *)
let serialize_to_file x filename =
  save_serialized (serialize x) filename

(** [load_serialized filename] reads a serialized [flattened] data structure
    from file [filename] and returns it in a [bin_prot] buffer structure.
    This can then be unserialized using [unserialize]. *)
let load_serialized filename =
  let read_file fd =
    let stats = Core.Unix.fstat fd in  (* Will this work correctly on symbolic links? If not use stat on the filename. *)
    let size = Int64.to_int (stats.st_size) in
    let buf = Bin_prot.Common.create_buf size in
    ignore(Core.Bigstring.read ~pos:0 ~len:size fd buf); (* TODO maybe store return bytes read and compare with size and throw exception *)
    buf
  in Core.Unix.(with_file filename ~mode:[O_RDONLY] ~f:read_file)

(** [unserialize buf] unserializes the [bin_prot] buffer [buf] and
    returns a matrix or ndarray specified by the [flattened] that
    is serialized in [buf]. *)
let unserialize buf =
  let posref = ref 0 in
  let {dims; data} = bin_read_flattened buf posref in
  let still_flat = Bigarray.Array1.change_layout data Bigarray.c_layout in
  Bigarray.reshape (Bigarray.genarray_of_array1 still_flat) dims

(** [unserialize_from_file filename] reads a serialized [flattened] data 
    structure from file [filename], unserializes the result, and returns
    the matrix or ndarray specified by the unserialized [flattened]. *)
let unserialize_from_file filename =
  unserialize (load_serialized filename)


(** Note that it's also possible to embed the flattened type in a more
    complex type, defining [bin_prot] access functions using [@@deriving],
    and then serialize data to a file form using the new functions along
    with [save_serialized] and [load_serialized].  For example:

{[
    # #require "ppx_bin_prot";;
    # open Bin_prot.Std;;
    # #load "owl_bin_prot.cma";;
    # type flatlist = Owl_bin_prot.flattened list [@@deriving bin_io];;
    type flatlist = Owl_bin_prot.flattened list
    val bin_shape_flatlist : Bin_prot.Shape.t = <abstr>
    val bin_size_flatlist : Owl_bin_prot.flattened list -> int = <fun>
    val bin_write_flatlist : Bin_prot.Common.buf -> pos:int -> Owl_bin_prot.flattened list -> int = <fun>
    val bin_writer_flatlist : Owl_bin_prot.flattened list Bin_prot.Type_class.writer0 = {Bin_prot.Type_class.size = <fun>; write = <fun>}
    val bin_read_flatlist : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> Owl_bin_prot.flattened list = <fun>
    val bin_reader_flatlist : Owl_bin_prot.flattened list Bin_prot.Type_class.reader0 = {Bin_prot.Type_class.read = <fun>; vtag_read = <fun>}
    val bin_flatlist : Owl_bin_prot.flattened list Bin_prot.Type_class.t0 =
      {Bin_prot.Type_class.shape = <abstr>; writer = {Bin_prot.Type_class.size = <fun>; write = <fun>}; reader = {Bin_prot.Type_class.read = <fun>; vtag_read = <fun>}}
    
    (* Convert some ndarrays in to 1D fortran_layout at this point.  Here we'll 
       just make sample data that's already in that form: *)
    # let v1 = Bigarray.Array1.create Bigarray.float64 Bigarray.fortran_layout 20;;
    # for i = 1 to 20 do Bigarray.Array1.set v1 i ((float i)**(0.5)) done;;
    # let v2 = Bigarray.Array1.create Bigarray.float64 Bigarray.fortran_layout 20;;
    # for i = 1 to 20 do (Bigarray.Array1.set v2 i (float i)) done;;
    
    # let flats = [{dims=[|4;5|]; data=v1}; {dims=[|4;5|]; data=v2}];;
    
    # let buf = create_buf (bin_size_flattened flats);;
    # bin_write_flatlist buf 0 flats;;
    # Owl_bin_prot.save_serialized buf "flats.bin";;
    
    # let buf' = Owl_bin_prot.load_serialized "flats.bin";;
    # let posref = ref 0;;
    # let flats' = bin_read_flatlist buf' posref;;
    # flats = flats';;
    - : bool = true
]}
*)
