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
          "sha256:f06b54c740a7b0b3f5f7886de35b514404769e182e1b2e238b9078b676b1e1ed";
        sha256 = "0s505fs81izgkbw4srvj7q3fixgnz39lmpylvin1zzh5kp8ghci2";
        finalImageName = "espressif/idf-rust";
        finalImageTag = "esp32_latest";
      };
    in {
      packages.${system}.esp32 = pkgs.stdenv.mkDerivation rec {
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
          pkgs.libxml2
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
          ln -s .rustup/toolchains/esp/bin $out/bin
          # [ -d $out/.cargo ] && [ -d $out/.rustup ]
        '';
      };
    };
}
