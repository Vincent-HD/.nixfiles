{
  lib,
  linuxPackages,
  stdenv,
  kernel ? linuxPackages.kernel,
  kernelModuleMakeFlags ? linuxPackages.kernelModuleMakeFlags,
}:

let
  kernelDirectory = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
stdenv.mkDerivation {
  pname = "cpuid-fault-emulation";
  version = "0.1";

  # Extracted from the manually downloaded source archive; its forum host blocks unattended fetches.
  src = ./source;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  hardeningDisable = [
    "format"
    "pic"
  ];

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail '/lib/modules/$(KERNEL)/build' '${kernelDirectory}'
  '';

  makeFlags = kernelModuleMakeFlags ++ [ "KERNEL=${kernel.modDirVersion}" ];

  installPhase = ''
    runHook preInstall

    # Kbuild installs the module and its certificate metadata; NixOS runs depmod
    # after merging it with the kernel and the other external modules.
    make -C ${kernelDirectory} ${lib.escapeShellArgs kernelModuleMakeFlags} \
      M="$PWD" INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=extra DEPMOD=true modules_install

    runHook postInstall
  '';

  meta = {
    description = "AMD SVM-based emulation of the Linux cpuid_fault interface";
    homepage = "https://cs.rin.ru/forum/viewtopic.php?f=10&t=159989";
    # The module declares GPL compatibility through MODULE_LICENSE("GPL").
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
