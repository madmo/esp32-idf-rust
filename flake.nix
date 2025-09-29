{
  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs, }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = { permittedInsecurePackages = [ "python-2.7.18.8" ]; };
      };
      esp32 = pkgs.dockerTools.pullImage {
        imageName = "espressif/idf-rust";
        imageDigest =
          "sha256:0548e817d6cfccf04859bb72746a3b5425428e8da68c503dd48288e6bca13084";
        sha256 = "3W4vjmrEY38RaCcbRmG5fyvV574vmxC0dE4HymnpTUc=";
        finalImageName = "espressif/idf-rust";
        finalImageTag = "all_latest";
      };
    in rec {
      packages.${system} = {
        esp32 = pkgs.stdenv.mkDerivation rec {
          name = "esp32";
          src = esp32;
          unpackPhase = ''
            mkdir -p source
            tar -C source -xvf $src
          '';
          sourceRoot = "source";
          nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.jq ];
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
          '';
        };
        default = esp32;
      };
    };
}
