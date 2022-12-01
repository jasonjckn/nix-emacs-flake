{ system, inputs, pkgs, ... }:

[(final : prev :
  {
    # stdenv = inputs.nixpkgs.legacyPackages.${system}.llvmPackages_14.stdenv;
  })

 (self : super:
   let
     mkGitEmacs = namePrefix: { ... }@args:
       builtins.foldl'
         (drv: fn: fn drv)
         super.emacs

         [(drv: drv.override ({ srcRepo = true; }))
          (drv: drv.override args)


          (drv: drv.overrideAttrs (
            old: {
              name = "${namePrefix}";
              src = inputs.emacs-src;

              stdenv = inputs.nixpkgs.legacyPackages.${system}.llvmPackages_14.stdenv;
              version = inputs.emacs-src.lastModifiedDate;
              patches = [ ];

              postPatch = old.postPatch + ''
                substituteInPlace lisp/loadup.el \
                --replace '(emacs-repository-get-version)' '"${inputs.emacs-src.rev}"' \
                --replace '(emacs-repository-get-branch)' '"master"'
              '' +
              # XXX: remove when https://github.com/NixOS/nixpkgs/pull/193621 is merged
              (super.lib.optionalString (old ? NATIVE_FULL_AOT)
                (let backendPath = (super.lib.concatStringsSep " "
                  (builtins.map (x: ''\"-B${x}\"'') [
                    # Paths necessary so the JIT compiler finds its libraries:
                    "${super.lib.getLib self.libgccjit}/lib"
                    "${super.lib.getLib self.libgccjit}/lib/gcc"
                    "${super.lib.getLib self.stdenv.cc.libc}/lib"

                    # Executable paths necessary for compilation (ld, as):
                    "${super.lib.getBin self.stdenv.cc.cc}/bin"
                    "${super.lib.getBin self.stdenv.cc.bintools}/bin"
                    "${super.lib.getBin self.stdenv.cc.bintools.bintools}/bin"
                  ]));
                 in ''
                        substituteInPlace lisp/emacs-lisp/comp.el --replace \
                            "(defcustom comp-libgccjit-reproducer nil" \
                            "(setq native-comp-driver-options '(${backendPath}))
(defcustom comp-libgccjit-reproducer nil"
                    ''));
            }))

          # reconnect pkgs to the built emacs
          (drv:
            let
              result = drv.overrideAttrs (old: {
                passthru = old.passthru // {
                  pkgs = self.emacsPackagesFor result;
                };
              });
            in
              result)

          (
            drv: drv.overrideAttrs (
              old: let
                libName = drv: super.lib.removeSuffix "-grammar" drv.pname;
                libSuffix = if super.stdenv.isDarwin then "dylib" else "so";
                lib = drv: ''lib${libName drv}.${libSuffix}'';
                linkCmd = drv:
                  if super.stdenv.isDarwin
                  then ''cp ${drv}/parser $out/lib/${lib drv}
                         /usr/bin/install_name_tool -id $out/lib/${lib drv} $out/lib/${lib drv}
                        ''
                  else ''ln -s ${drv}/parser $out/lib/${lib drv}'';

                linkerFlag = drv: "-l" + libName drv;
                # plugins = args.withTreeSitterPlugins self.pkgs.tree-sitter-grammars;
                plugins = (with self.pkgs.tree-sitter-grammars; [


                  (tree-sitter-clojure.overrideAttrs (o: {
                    stdenv = inputs.nixpkgs.legacyPackages.${system}.llvmPackages_14.stdenv;
                    }))

                  (tree-sitter-bash.overrideAttrs (o: {
                    stdenv = inputs.nixpkgs.legacyPackages.${system}.llvmPackages_14.stdenv;
                    }))
		              # tree-sitter-c
                  # tree-sitter-c-sharp
                  # tree-sitter-cpp
                  # tree-sitter-css
                  # tree-sitter-java
                  # tree-sitter-python
                  # tree-sitter-javascript
                  # tree-sitter-json
                  # tree-sitter-tsx

                ]);
                tree-sitter-grammars = super.runCommandCC "tree-sitter-grammars" {}
                  (super.lib.concatStringsSep "\n" (["mkdir -p $out/lib"] ++ (map linkCmd plugins)));
              in {
                configureFlags = old.configureFlags ++
                                 super.lib.singleton "--with-tree-sitter";

                buildInputs = old.buildInputs ++
                              [ self.pkgs.tree-sitter
                                tree-sitter-grammars
                              ];

                # before building the `.el` files, we need to allow the `tree-sitter` libraries
                # bundled in emacs to be dynamically loaded.
                TREE_SITTER_LIBS = super.lib.concatStringsSep " " ([ "-ltree-sitter" ]
                                                                   ++ (map linkerFlag plugins)
                );
              }
            )
          )
         ] ;
   in
     {
       emacsGit = mkGitEmacs "emacs-git"
         {
           withSQLite3 = true;
           withWebP = true;
           nativeComp = true;
         };

       tree-sitter = inputs.nixpkgs.legacyPackages.${system}.tree-sitter.overrideAttrs (o:
         {
           stdenv = inputs.nixpkgs.legacyPackages.${system}.llvmPackages_14.stdenv;
         }
       );
     }
)]
