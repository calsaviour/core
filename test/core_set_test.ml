open OUnit
open Core.Std

module String_set = Set.Make(String)

let s1 = String_set.of_list ["a"; "b"; "c"; "d"]
(*let m2 = Map.of_alist ["a",1; "c",-3; "d",4; "e",5]*)

type int_set = int Set.Poly.t with bin_io

module String_set_comp = struct
  include Int.Replace_polymorphic_compare

  type string_set_comp = Int.t Set.Poly.t with compare

  let test () =
    let compare = compare_string_set_comp in
    assert (compare (Set.Poly.of_list []) (Set.Poly.of_list []) = 0);
    assert (compare (Set.Poly.of_list [0]) (Set.Poly.of_list []) <> 0);
    assert (compare (Set.Poly.of_list [3;2;1]) (Set.Poly.of_list [1;2;3]) = 0);
    assert (compare (Set.Poly.of_list [0;1;2;3]) (Set.Poly.of_list [1;1;2;3]) <> 0);

end

module Quick = struct
  open Janecheck.Std

  let set_gen elt_gen set_of_list =
    let open Generator in
    list elt_gen >>| set_of_list
  ;;

  let int_set_gen = set_gen Generator.int Int.Set.of_list

  let int_set_pair_gen = Generator.tuple int_set_gen int_set_gen

  let symmetric_diff_set s1 s2 =
    Int.Set.symmetric_diff s1 s2
    |> Sequence.to_list
    |> List.map ~f:(function | First elt | Second elt -> elt)
    |> Int.Set.of_list
  ;;

  (* textbook definition of symmetric diff *)
  let symmetric_diff_spec s1 s2 = Int.Set.diff (Int.Set.union s1 s2) (Int.Set.inter s1 s2)

  let symmetric_diff_test =
    "symmetric_diff" >:: (fun () ->
      let seed = `Deterministic "core set symmetric diff" in
      let sexp_of = <:sexp_of< Int.Set.t * Int.Set.t >> in
      Janecheck.test ~trials:100 ~seed ~sexp_of int_set_pair_gen ~f:(fun (s1, s2) ->
        let expect = symmetric_diff_spec s1 s2 in
        let actual = symmetric_diff_set s1 s2 in
        <:test_eq< Int.Set.t >> actual expect))
  ;;

end

let test =
  "core_fset" >:::
    [ "sexp" >::
        (fun () ->
          let s = "(a b c d)" in
          let s1' = String_set.t_of_sexp (Sexp.of_string s) in
          "of_sexp1" @? (String_set.equal s1' s1);
          let s_dup = "(a b a d)" in
          let s_dup = Sexp.of_string s_dup in
          assert_raises
            (Sexplib.Conv.Of_sexp_error (
              Failure "Set.t_of_sexp: duplicate element in set",
              (sexp_of_string "a")))
            (fun () -> String_set.t_of_sexp s_dup)
        );
      "bin_io" >::
        (fun () ->
          let max_n = 20 in
          let bstr = Bigstring.create (max_n + 1) in
          for n = 0 to max_n do
            let s1 = Set.Poly.of_array (Array.init n ~f:succ) in
            let pos = bin_write_int_set bstr ~pos:0 s1 in
            "pos" @? (pos = n + 1);
            let pos_ref = ref 0 in
            let s2 = bin_read_int_set bstr ~pos_ref in
            "pos_ref" @? (!pos_ref = n + 1);
            "equal" @? (Set.equal s1 s2);
            bstr.{0} <- '\002';
            bstr.{1} <- 'x';
            bstr.{2} <- 'x';
            pos_ref := 0;
            let dup_check =
              try
                ignore (bin_read_int_set bstr ~pos_ref);
                false
              with Bin_prot.Common.Read_exc (Failure _, 3) -> true
            in
            "dup_check" @? dup_check
          done;
        );
      "with_compare" >:: String_set_comp.test;
      Quick.symmetric_diff_test
    ]
