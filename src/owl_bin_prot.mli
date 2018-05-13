(** Functions for serializing Owl dense matrices and ndarrays to files. *)

(** Note: Owl matrices are also Owl ndarrays, so everything said
    below about ndarrays also applies to matrices, vectors, etc. *)

(** Type [flattened] hold dense ndarray data prior to/after 
    serialization.
    [dims] should contained the dimensions of the original ndarray, and
    [vec] should contain a flattened version of the ndarray data.
    ([vec] is defined by [Bin_prot.common]; it is a 
    [(float, float64_elt, fortran_layout) Bigarray.Array1].)  *)
type flattened = { dims : int array; data : Bin_prot.Common.vec; }


(** Functions for serializing and writing to a file: *)

(** Given an Owl ndarray [x], [ndarray_to_flattened x] returns a [flattened]
    in which the [dims] field contains the dimensions of the original ndarray,
    and the [data] field contains the same data in a 1D [fortran_layout]
    [Bigarray.Array1].  (This is used by [serialize], but can also be used
    by serializatiion functions for more  complicated types in which
    [flattened]s will be embedded.) *)
val ndarray_to_flattened : (float, Bigarray.float64_elt) Owl.Dense.Ndarray.Generic.t -> flattened

(** Given a dense ndarray [x], [serialize x] returns a [bin_prot]
    buffer structure containing a serialized version of an instance of type 
    [flattened], i.e. of an array of dimensions of the original ndarray, and 
    the flattened data from the original ndarray.  A copy of the original
    ndarray can be recreated from the resulting buffer using [unserialize].
    The buffer structure can be saved to a file using [save_serialized]. *)
val serialize : (float, Bigarray.float64_elt) Owl.Dense.Ndarray.Generic.t -> Bin_prot.Common.buf

(** Given a [bin_prot] buffer created with [serialize], writes it to file
    [filename].  If the file exists, it will be zeroed out and recreated. 
    This file can be read using [load_serialized]. *)
val save_serialized : Bin_prot.Common.buf -> string -> unit

(** Given a dense ndarray [x], [serialize_to_file x] transforms it
    into an instance of [flattened], serializes that using [bin_prot], and
    writes the result to file [filename].  If the file exists, it will be 
    zeroed out and recreated. The process can be reversed using 
    [unserialize_from_file]. *)
val serialize_to_file :
  (float, Bigarray.float64_elt) Owl.Dense.Ndarray.Generic.t -> string -> unit


(** Functions for unserializing and loading from a file: *)

(** [load_serialized filename] reads a serialized [flattened] data structure
    from file [filename] and returns it in a [bin_prot] buffer structure.
    This can then be unserialized using [unserialize]. *)
val load_serialized : string -> Bin_prot.Common.buf

(** [flattened_to_ndarray flat], where [flat] is a [flattened], returns a new
    ndarray specified by [flat], i.e. with dimensions [flat.dims] and data from
    [flat.data]. *)
val flattened_to_ndarray :
  flattened ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Genarray.t

(** [unserialize buf] unserializes the [bin_prot] buffer [buf] and
    returns an ndarray specified by the [flattened] that
    is serialized in [buf]. *)
val unserialize :
  Bin_prot.Common.buf ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Genarray.t

(** [unserialize_from_file filename] reads a serialized [flattened] data 
    structure from file [filename], unserializes the result, and returns
    the ndarray specified by the unserialized [flattened]. *)
val unserialize_from_file :
  string ->
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Genarray.t


(** Utility functions: *)

(** Multiply together all elements of an [int array]. *)
val multiply_array_elts : int array -> int

(** Run function that has unit arg, print timing info to stdout, and return result. *)
val time : (unit -> 'a) -> 'a

(** By default [test_serialize] creates an ndarray of size 10x20x30 with 
    [uniform]; if [~size] is provided, it is multiplied 3 to determine the
    last dimension.  Then the file is serialized to a temporary file.  The 
    result is then unserialized from the file and checked to see if the
    original and copy are equal.  The result of that test is returned. 
    Total time in each of the two stages is printed to stdout. *)
val test_serialize : ?size:int -> unit -> bool


(** The functions with names beginning with "bin_" below are defined 
    automatically via [[@@deriving bin_io]] frm the [flattened] type 
    definition. This process uses [ppx_bin_prot].  The definitions are 
    used by higher-level serialization functions defined here, and can 
    also be used separately, of course. *)

(** Return the shape of a [flattened] from [bin_prot]'s point of view. *)
val bin_shape_flattened : Bin_prot.Shape.t

(** Return the size in bytes of a [flattened] from [bin_prot]'s point of view. *)
val bin_size_flattened : flattened -> int

(** Given a [bin_prot] buffer an an initial byte position in the buffer
    (e.g. 0), serialize the [flattened] into the buffer starting at that
    position. *)
val bin_write_flattened : Bin_prot.Common.buf -> pos:Bin_prot.Common.pos -> flattened -> Bin_prot.Common.pos

val bin_writer_flattened : flattened Bin_prot.Type_class.writer

(** Given a [bin_prot] buffer and a variable containing a reference to an
    initial byte positionin the buffer (e.g. [ref 0]), unserialize the
    buffer's contents, starting from that position, and return it as a
    [flattened].  The position reference will contain the position after
    what was read. *)
val bin_read_flattened : Bin_prot.Common.buf -> pos_ref:Bin_prot.Common.pos_ref -> flattened

val bin_reader_flattened : flattened Bin_prot.Type_class.reader

val bin_flattened : flattened Bin_prot.Type_class.t

