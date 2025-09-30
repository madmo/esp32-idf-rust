{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          permittedInsecurePackages = [ "python-2.7.18.8" ];
        };
      };

      dockerArchive = pkgs.dockerTools.pullImage {
        imageName = "espressif/idf-rust";
        imageDigest = "sha256:57b0b7c59288e4dcfa5143fe494ac4e145d3a78ff1e61cb772b78d17935aa051";
        sha256 = "sha256-fNPeDsS7WAqkrBX60pQdXirLCfKsSKIoGACTTNOp0LA=";
        finalImageName = "espressif/idf-rust";
        finalImageTag = "all_latest";
      };

      esp_clang_version = "19.1.2_20250225";
      esp_gcc_version = "14.2.0_20240906";

      toolchain = pkgs.stdenv.mkDerivation {
        name = "esp32-toolchain";
        src = dockerArchive;
        unpackPhase = ''
          mkdir -p source
          tar -C source -xvf $src
        '';
        sourceRoot = "source";
        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.jq
        ];
        buildInputs = [
          pkgs.xz
          pkgs.zlib
          pkgs.libxml2_13
          pkgs.python2
          pkgs.libudev-zero
          pkgs.stdenv.cc.cc
        ];
        buildPhase = ''
          jq -r '.[0].Layers | @tsv' < manifest.json > layers
        '';
        installPhase = ''
          mkdir -p $out
          for i in $(< layers); do
            tar -C $out -xvf "$i" home/esp/.cargo home/esp/.rustup || true
          done
          mv -t $out $out/home/esp/{.cargo,.rustup}
          rmdir $out/home/esp
          rmdir $out/home
          # make naersk happy
          ln -s .rustup/toolchains/esp/bin $out/bin
          # [ -d $out/.cargo ] && [ -d $out/.rustup ]
          echo clang version: $out/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-*
          echo gcc version: $out/.rustup/toolchains/esp/xtensa-esp-elf/esp-*
          [ -d $out/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-${esp_clang_version} ]
          [ -d $out/.rustup/toolchains/esp/xtensa-esp-elf/esp-${esp_gcc_version} ]
        '';
      };
    in
    rec {
      packages.${system} = {
        esp32 = pkgs.callPackage (
          { }:
          pkgs.makeSetupHook
            {
              name = "esp32";
              propagatedBuildInputs = [ toolchain ];
              substitutions = {
                shell = "${pkgs.bash}/bin/bash";
              };
            }
            (
              pkgs.writeScript "xtensa-path-hook.sh" ''
                export LIBCLANG_PATH="${toolchain}/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-${esp_clang_version}/esp-clang/lib"
                export PATH="${toolchain}/.rustup/toolchains/esp/bin:${toolchain}/.rustup/toolchains/esp/xtensa-esp-elf/esp-${esp_gcc_version}/xtensa-esp-elf/bin:$PATH"
                export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/library"
              ''
            )
        ) { };
        default = packages.${system}.esp32;
      };
      devShells."${system}".default = pkgs.mkShell {
        nativeBuildInputs = [ packages.${system}.default ];
      };
    };
}
