{
  * Example of adding exports to image.
  * ExportsAdd will add new exports and rebuild image.
}
program ExportsAdd;

uses
  PE.Common,
  PE.Image,
  PE.Section,
  PE.ExportSym,

  PE.Build;

var
  img: TPEImage;
  sec: TPESection;

begin
  img := TPEImage.Create;
  try

    img.LoadFromFile('SampleLib.dll');

    // Create new 512-byte sized section.
    sec := img.Sections.AddNew('data', 512, 0, nil);

    // Add exports
    // by name
    img.ExportSyms.AddByName(sec.RVA + $40, 'exp40');
    img.ExportSyms.AddByName(sec.RVA + $30, 'exp30');
    img.ExportSyms.AddByName(sec.RVA + $20, 'exp20');
    img.ExportSyms.AddByName(sec.RVA + $10, 'exp10');

    // by ordinal
    img.ExportSyms.AddByOrdinal(sec.RVA + $40, 64);
    img.ExportSyms.AddByOrdinal(sec.RVA + $80, 128);

    // forwarder
    img.ExportSyms.AddForwarder('fwd5', 'external5');

    // Set executable export name.
    img.ExportedName := 'my_export_dll';

    // Rebuild exports. Try to overwrite old exports or append it in new
    // section if it's too large.
    sec := ReBuildDirData(img, DDIR_EXPORT, True);

    // Change name of export section.
    if sec <> nil then
      sec.Name := 'myexport';

    // Save resulted image to file.
    img.SaveToFile('tmp\new_exports.dll');
  finally
    img.Free;
  end;

end.
