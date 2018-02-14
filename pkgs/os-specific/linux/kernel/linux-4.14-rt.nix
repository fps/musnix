{ stdenv, fetchurl, hostPlatform, buildPackages, perl, buildLinux, ... } @ args:

buildLinux (args // rec {
  kversion = "4.14.15";
  pversion = "rt13";
  version = "${kversion}-${pversion}";
  extraMeta.branch = "4.14";

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v4.x/linux-${kversion}.tar.xz";
    sha256 = "0hk15qslkq15x53zkp70gnhdmjg5j9xigyykmig3g03gqsh97hzz";
  };
} // (args.argsOverride or {}))