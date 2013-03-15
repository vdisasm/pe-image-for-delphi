program BuildRelocs;

uses
  PE.Common,
  PE.Image,
  PE.Section,
  PE.Build;

var
  img: TPEImage;
  sec: TPESection;

begin
  img := TPEImage.Create;
  try
    sec := img.Sections.AddNew('.code', 32, $60000020, nil);

    // Create "code".
    sec.Mem[0] := $A1;
    PCardinal(@sec.Mem[1])^ := img.ImageBase + sec.RVA + 6;
    sec.Mem[5] := $C3;
    PCardinal(@sec.Mem[6])^ := $12345678;

    img.EntryPointRVA := sec.RVA;

    // Create reloc and export.
    img.Relocs.Put(sec.RVA + 1, 3);
    img.ExportSyms.AddByName(sec.RVA + 6, 'MyVariable');

    // Rebuild.
    ReBuildDirData(img, DDIR_RELOCATION, False);
    ReBuildDirData(img, DDIR_EXPORT, False);

    // Save.
    img.SaveToFile('myreloc.exe');
  finally
    img.Free;
  end;
end.
