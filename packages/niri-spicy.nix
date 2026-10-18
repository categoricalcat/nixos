{
  lib,
  shaderc,
  vulkan-loader,
  niri-spicy,
  smithay-spicy,
}:

niri-spicy.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [
    shaderc
    vulkan-loader
  ];
  SHADERC_LIB_DIR = "${lib.getLib shaderc}/lib";
  postPatch = (old.postPatch or "") + ''
    substituteInPlace Cargo.toml --replace-fail '../smithay' '${smithay-spicy}'
  '';
  postFixup = (old.postFixup or "") + ''
    patchelf --add-rpath ${
      lib.makeLibraryPath [
        vulkan-loader
        shaderc
      ]
    } $out/bin/niri
  '';
})
