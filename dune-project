(lang dune 2.8)

(generate_opam_files true)

(name pool)

(version 0.0.1-beta.1)

(authors "Department of Economics, University of Zurich")

(source
 (uri git+https://gitlab.uzh.ch/econ/study-coordination/pool))

(license GPL-2.0-or-later)

(maintainers "engineering@uzh.econ.ch")

(homepage "https://gitlab.uzh.ch/econ/study-coordination/pool")

(bug_reports "https://gitlab.uzh.ch/econ/study-coordination/pool")

(documentation "https://gitlab.uzh.ch/econ/study-coordination/pool/doc")

(package
 (name pool)
 (synopsis "The Z-Pool tool")
 (description "\nTODO\n")
 (depends
  dune
  (ocaml
   (>= 4.12.0))
  (conformist
   (>= 0.8.1))
  (sihl
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (sihl-cache
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (sihl-email
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (sihl-queue
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (sihl-storage
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (sihl-token
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (sihl-user
   (and
    (>= 3.0.5)
    (< 4.0.0)))
  (lwt
   (>= 5.6.1))
  (logs
   (>= 0.7.0))
  (containers
   (>= 3.6))
  (mariadb
   (= 1.1.4))
  (caqti-driver-mariadb
   (>= 1.8.0))
  (caqti
   (>= 1.8.0))
  (ocamlformat
   (>= 0.18.0))
  (ppx_deriving
   (>= 5.2.1))
  (ppx_yojson_conv
   (>= 0.14.0))
  (ppx_variants_conv
   (= v0.14.2))
  canary
  (guardian
   (= 0.0.5))
  ;; Test/Dev dependencies
  (alcotest-lwt :with-test)
  (ppx_inline_test :with-test)))
