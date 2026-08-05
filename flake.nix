{
  description = "dndist — a Typst package for printable D&D 5.5e character sheets (unofficial)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (nixpkgs) lib;
        pname = "dndist";
        version = "1.0.0";

        # - The layout is calibrated to these three faces.
        # - `legacyPackages.fontPaths` exports them, thus consumers do not restate them.
        fontPaths = [
          "${pkgs.et-book}/share/fonts"
          "${pkgs.montserrat}/share/fonts"
          "${pkgs.texlivePackages.euler-math}/fonts"
        ];

        # - `buildTypstPackage` copies all of `src` and ignores typst.toml's `exclude`.
        # - The repo root is the package root, thus this list is the only control
        #   over the contents of the published package.
        # - This is an allow-list: a new root file does not ship by default.
        # - The `package-contents` check makes sure of this.
        packageFileset = lib.fileset.unions [
          ./typst.toml
          ./dndist.typ
          ./LICENSE
          ./NOTICE
          ./README.md
          ./src
          ./template
        ];

        dndist = pkgs.buildTypstPackage {
          inherit pname version;
          src = lib.fileset.toSource {
            root = ./.;
            fileset = packageFileset;
          };
          typstDeps = [ pkgs.typstPackages.cuti ];
        };

        typstEnv = pkgs.typst.wrapper {
          packages = _: [ dndist ];
          fonts = fontPaths;
          # - `typst.wrapper` sets only TYPST_FONT_PATHS, thus system fonts stay available.
          # - A host Montserrat can then satisfy the family with different metrics.
          # - Set "true", not "1": typst reads this variable as a bool and rejects "1".
          extraWrapperArgs = [
            "--set"
            "TYPST_IGNORE_SYSTEM_FONTS"
            "true"
          ];
        };

        # - The repo's scripting language is Perl.
        # - Each script is wrapped by one `makeWrapper` call that supplies its `PATH`,
        #   thus no script hunts for a tool.
        perlWrapper =
          name: script: path:
          pkgs.runCommand name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
            makeWrapper ${pkgs.perl}/bin/perl $out/bin/${name} \
              --add-flags ${script} \
              --prefix PATH : ${lib.makeBinPath path}
          '';

        # This wrapped binary gives the consumer repo the font guard without a copy
        # of the script.
        typst-strict = perlWrapper "typst-strict" ./typst-strict.pl [ typstEnv ];

        # - This regenerates the README screenshots from the template.
        # - It renders through typst-strict, thus the images keep the real fonts.
        # - It writes into the working tree, thus it is an app, not a package.
        docs-images = perlWrapper "docs-images" ./docs-images.pl [
          typst-strict
          pkgs.poppler-utils
        ];

        # tests/ is outside packageFileset, thus the checks need the repo source.
        repoSrc = lib.cleanSource ./.;

        # - A check that compiles real Typst out of the repo source.
        # - `tool` is the compiler it needs on PATH: typstEnv, or typst-strict for
        #   the checks that must also fail on a substituted font.
        typstCheck =
          name: tool: script:
          pkgs.runCommand "dndist-${name}"
            {
              nativeBuildInputs = [ tool ];
              src = repoSrc;
            }
            ''
              cd "$src"
              mkdir -p "$out"
              ${script}
            '';

        # This is the file a `typst init` user compiles.
        templateEntrypoint = (lib.importTOML ./typst.toml).template.entrypoint;

        # - The exact file list `packageFileset` allows, relative to the repo root.
        # - `package-contents` compares the built package against it, thus the
        #   allow-list is the one statement of what ships.
        packageFiles = map (p: lib.removePrefix (toString ./. + "/") (toString p)) (
          lib.fileset.toList packageFileset
        );
      in
      {
        packages = {
          inherit dndist typstEnv typst-strict;
          default = dndist;
        };

        # A list of strings is not a derivation, thus `nix flake check` rejects it
        # under `packages`.
        legacyPackages = { inherit fontPaths; };

        apps.docs-images = {
          type = "app";
          program = "${docs-images}/bin/docs-images";
          meta.description = "Regenerate the README screenshots in docs/";
        };

        formatter = pkgs.nixfmt-tree;

        # - Each check compiles real Typst.
        # - A failed `assert` or an unresolved font family fails the build.
        # - There is no test harness.
        checks = {
          # - This check runs the engine assertions.
          # - `assert` stops compilation, thus a green build is a green test run.
          # - `--root` is necessary: the file reaches into ../src/{resolve,model}.typ
          #   for unexported symbols.
          # - typstEnv hard-`--set`s TYPST_IGNORE_SYSTEM_FONTS, thus no flag here.
          resolve-test = typstCheck "resolve-test" typstEnv ''
            typst compile --root "$src" tests/resolve-test.typ "$out/resolve-test.pdf"
          '';

          # - This check compiles every fixture in both layouts.
          # - The fixtures have no assertions, but they must compile.
          # - A compile failure shows a layout fault that resolve-test cannot find.
          render = typstCheck "render-fixtures" typst-strict ''
            for f in tests/*.typ; do
              # A plain `[ … ] && continue` survives `set -e` only by bash's
              # AND-list exemption; `case` states the skip outright.
              case "$f" in tests/resolve-test.typ) continue ;; esac
              name="$(basename "$f" .typ)"
              for layout in card letter; do
                echo "rendering $name ($layout)"
                typst-strict --root "$src" --input "layout=$layout" \
                  "$f" "$out/$name-$layout.pdf"
              done
            done
          '';

          # This check compiles the template in place, with the font guard.
          template = typstCheck "template" typst-strict ''
            for layout in card letter; do
              typst-strict --root "$src/template" --input "layout=$layout" \
                template/main.typ "$out/template-$layout.pdf"
            done
          '';

          # - This check runs `typst init` against the built package.
          # - It finds a bad [template] path or entrypoint.
          # - It finds a template/ dropped from packageFileset.
          # - It uses typstEnv, not typst-strict: `typst` must run with no flags of
          #   ours, because an explicit flag hides a bad wrapper environment variable.
          # - There is no font guard here; the `template` check above has it.
          # - It compiles the declared entrypoint. `typst init` copies the template
          #   directory whatever the manifest says.
          template-init = pkgs.runCommand "dndist-template-init" { nativeBuildInputs = [ typstEnv ]; } ''
            cd "$TMPDIR"
            typst init @preview/${pname}:${version} mychar
            cd mychar
            mkdir -p "$out"
            for layout in card letter; do
              echo "compiling the scaffolded project ($layout)"
              typst compile --input "layout=$layout" \
                ${templateEntrypoint} "$out/init-$layout.pdf"
            done
          '';

          # - `fonts.pl` downloads the fonts a user without Nix needs, pinned by
          #   sha256 to the exact build this flake renders with.
          # - This check compares those pins against the flake's own font files.
          # - A nixpkgs bump thus fails here, rather than handing a newcomer a
          #   different build of a family that resolves without any warning.
          # - It hashes only the faces the pins name; the other Montserrat
          #   weights are not downloaded, thus they are not compared.
          font-pins =
            pkgs.runCommand "dndist-font-pins"
              {
                nativeBuildInputs = [ pkgs.perl ];
                src = repoSrc;
                fontDirs = fontPaths;
              }
              ''
                cd "$src"
                perl fonts.pl --pins | sort > "$TMPDIR/pinned"

                for f in $(find $fontDirs -type f \( -name '*.ttf' -o -name '*.otf' \)); do
                  echo "$(sha256sum "$f" | cut -d' ' -f1)  $(basename "$f")"
                done | sort > "$TMPDIR/available"

                # Every pinned file must appear, byte-identical, among the flake's.
                if ! comm -23 "$TMPDIR/pinned" "$TMPDIR/available" | grep -q .; then
                  cp "$TMPDIR/pinned" "$out"
                  exit 0
                fi
                echo "error: fonts.pl pins a build this flake does not render with:" >&2
                comm -23 "$TMPDIR/pinned" "$TMPDIR/available" >&2
                echo "  fix: re-pin the hashes in fonts.pl, and re-check the layout" >&2
                exit 1
              '';

          # - This check runs the path a user with only typst and a clone takes.
          # - `packages/` holds the committed symlink that names this repo as
          #   `@preview/${pname}:${version}`.
          # - An empty cache path leaves that symlink as the only source of the
          #   package, thus a broken or misnamed link fails here.
          # - The cache path is a flag, not the environment variable: typstEnv
          #   hard-`--set`s that variable, thus an export here reaches nothing and
          #   the wrapper's own copy of the package answers instead.
          # - `typst init` needs no dependency, thus the empty cache is enough.
          bare-typst = typstCheck "bare-typst" typstEnv ''
            typst init --package-path packages --package-cache-path "$TMPDIR/empty-cache" \
              @preview/${pname}:${version} "$TMPDIR/mychar"
            cp "$TMPDIR/mychar/${templateEntrypoint}" "$out/${templateEntrypoint}"
          '';

          # - `buildTypstPackage` ignores typst.toml's `exclude` (it is a plain
          #   `cp -r` of its `src`), and the repo root is the package root, thus
          #   `packageFileset` is the only control over what ships.
          # - This check compares the built package against that allow-list exactly.
          # - An exact diff catches a file nobody thought to name, thus a new root
          #   file cannot leak by being forgotten.
          # - Both sides sort in the shell, thus the comparison does not depend on
          #   Nix's byte-wise `<` matching the sandbox's collation.
          package-contents =
            pkgs.runCommand "dndist-package-contents"
              {
                expected = lib.concatStringsSep "\n" packageFiles;
              }
              ''
                printf '%s\n' "$expected" | sort > "$TMPDIR/expected"
                cd ${dndist}/lib/typst-packages/${pname}/${version}
                find . -type f | sed 's|^\./||' | sort > "$TMPDIR/actual"
                if ! diff -u "$TMPDIR/expected" "$TMPDIR/actual"; then
                  echo "error: the published package does not match packageFileset" >&2
                  echo "  fix: packageFileset in flake.nix" >&2
                  exit 1
                fi
                cp "$TMPDIR/actual" "$out"
              '';
        };

        devShells.default = pkgs.mkShell {
          packages = [
            typstEnv
            typst-strict
          ];
          # resolve-test.typ reaches into ../src/, thus it needs a root.
          shellHook = ''
            export TYPST_ROOT="$PWD"
          '';
        };
      }
    );
}
