{
  * Example of adding exports to image.
  * First build SampleLib.dll then ExportsAdd.exe
  * ExportsAdd will add new exports to existing exports and rebuild the image.
}
program ExportsAdd;

uses
  PE.Common,
  PE.Image,
  PE.Section,
  PE.ExportSym,

  PE.Build.Export;

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
    img.ExportSyms.AddByName(sec.RVA + $00, 'exp1');
    img.ExportSyms.AddByName(sec.RVA + $10, 'exp2');
    img.ExportSyms.AddByName(sec.RVA + $20, 'exp3');
    img.ExportSyms.AddByName(sec.RVA + $30, 'exp4');

    // by ordinal
    img.ExportSyms.AddByOrdinal(sec.RVA + $40, $100);
    img.ExportSyms.AddByOrdinal(sec.RVA + $50, $101);

    // forwarder
    img.ExportSyms.AddForwarder('fwd5', 'external5');

    // Set executable export name.
    img.ExportedName := 'my_export_dll';

    // Rebuild exports. Try to overwrite old exports or append it in new
    // section if it's too large.
    sec := ReBuildExports(img, True);

    // Change name of export section.
    if sec <> nil then
      sec.Name := 'myexport';

    // Save resulted image to file.
    img.SaveToFile('result.dll');
  finally
    img.Free;
  end;

end.
