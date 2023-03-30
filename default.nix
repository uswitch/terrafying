let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/893186f4fd4c1e697b2bc38aa8f268f236d5ea02.tar.gz";
  }) {};

  stdenv = pkgs.stdenv;
  ruby = (pkgs.ruby_2_3_0.override { cursesSupport = true; });

  unstable = builtins.tryEval ( import <unstable> {} );
  terraform = if unstable.success then
    import (unstable.value.path + "/pkgs/applications/networking/cluster/terraform/") {
      stdenv = unstable.value.stdenv;
      lib =  unstable.value.lib;
      buildGoPackage = unstable.value.buildGoPackage;
      fetchFromGitHub = unstable.value.fetchFromGitHub;
    }
  else
    [];

  platformBuildInputs = if stdenv.isDarwin then [] else [
    pkgs.glibc
  ];
in stdenv.mkDerivation rec {
  name = "terrafying";
  buildInputs = platformBuildInputs ++ [
    ruby
    pkgs.libxml2
    pkgs.libxslt
    pkgs.zlib
    pkgs.bzip2
    pkgs.openssl
    pkgs.readline
    terraform
  ];

  src = ./.;

  installPhase = ''
    mkdir -p $out
    cp -R $src/* $out

    for i in `ls $out/bin`; do
      chmod +x $out/bin
    done
  '';

  shellHook = ''
    export PKG_CONFIG_PATH=${pkgs.libxml2}/lib/pkgconfig:${pkgs.libxslt}/lib/pkgconfig:${pkgs.zlib}/lib/pkgconfig

    # gems
    mkdir -p .nix-gems
    export GEM_HOME=$PWD/.nix-gems
    export GEM_PATH=$GEM_HOME
    export PATH=$GEM_HOME/bin:$PATH
  '';
}

