{
  description = "Entorno de desarrollo Flutter y Android - UmlStudio Mobile";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "16.0";
          buildToolsVersions = [ "34.0.0" "35.0.0" "36.0.0" ];
          platformVersions = [ "33" "34" "35" "36" ];
          abiVersions = [ "x86_64" ];
          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];
        };

        androidSdk = androidComposition.androidsdk;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter
            jdk17
            androidSdk
            cmake
            ninja
            pkg-config
            gtk3
          ];

          shellHook = ''
            export JAVA_HOME="${pkgs.jdk17}"
            export ANDROID_HOME="${androidSdk}/libexec/android-sdk"
            export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
            
            flutter config --android-sdk "$ANDROID_HOME" > /dev/null 2>&1
          '';
        };
      }
    );
}
