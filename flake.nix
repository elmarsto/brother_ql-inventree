{
  description = "A python tool to render images directly on a Brother QL-series label maker";
  inputs = {
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    { flake-utils, gitignore, nixpkgs, pyproject-nix, ... }: flake-utils.lib.eachDefaultSystem (system:
      let
        app = p: { program = "${p}"; type = "app"; };
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python3;
        projectRoot = gitignore.lib.gitignoreSource ./.;
        project = pyproject-nix.lib.project.loadPyproject { inherit projectRoot; };
        brother_ql = 
          let
            attrs = project.renderers.buildPythonPackage { inherit python; };
          in
          python.pkgs.buildPythonPackage (attrs // {
            propagatedBuildInputs = attrs.propagatedBuildInputs ++ [
              pkgs.python3.pkgs.setuptools
            ];
          });
        bql = pkgs.writeShellScript "brother_ql" ''
          ${brother_ql}/bin/brother_ql $@
        '';
      in
      {
        inherit project;
        app.default = {
          type = "app";
          program = "${bql}";
        };
        devShells.default = 
          let
            pypkgs = project.renderers.withPackages { inherit python; };
            pythonEnv = python.withPackages pypkgs;
          in
          pkgs.mkShell {
            packages = with pkgs.python3.pkgs; [ pythonEnv ] ++  [
              pypandoc
              brother_ql
            ];
          };
        packages.default = brother_ql;
      }
    );
}
