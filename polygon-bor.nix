{ lib, stdenv, buildGoModule, fetchFromGitHub, libobjc, IOKit }:

let
  # A list of binaries to put into separate outputs
  bins = [
    "bor"
  ];

in buildGoModule rec {
  pname = "polygon-bor";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "maticnetwork";
    repo = "bor";
    rev = "v${version}";
    sha256 = "0kb15711szsk1mq651j4gra8xvqsm3g0bpggzc95mnazkw9m0749"; # retrieved using nix-prefetch-url
  };

  proxyVendor = true;
  vendorHash = "sha256-yp/sGhbqMYFtShH32YMViOZCoBP1O0ck/jqwwg3fcfY=";

  doCheck = false;

  outputs = [ "out" ] ++ bins;

  # Move binaries to separate outputs and symlink them back to $out
  postInstall = ''
    cp $out/bin/geth $out/bin/bor
  '' + lib.concatStringsSep "\n" (
    builtins.map (bin: "mkdir -p \$${bin}/bin && mv $out/bin/${bin} \$${bin}/bin/ && ln -s \$${bin}/bin/${bin} $out/bin/") bins
  );

  subPackages = [
    "cmd/abidump"
    "cmd/abigen"
    "cmd/bootnode"
    "cmd/clef"
    "cmd/cli"
    "cmd/clidoc"
    "cmd/devp2p"
    "cmd/ethkey"
    "cmd/evm"
    "cmd/geth"
    "cmd/p2psim"
    "cmd/rlpdump"
    "cmd/utils"
  ];

  # Fix for usb-related segmentation faults on darwin
  propagatedBuildInputs =
    lib.optionals stdenv.isDarwin [ libobjc IOKit ];

  meta = with lib; {
    description = "Bor is an Ethereum-compatible sidechain for the Polygon network";
    homepage = "https://github.com/maticnetwork/bor";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ "brunonascdev" ];
  };
}