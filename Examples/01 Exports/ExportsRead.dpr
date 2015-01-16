program ExportsRead;

{$APPTYPE CONSOLE}


uses
  System.SysUtils,

  PE.Common,
  PE.Image,
  PE.ExportSym;

const
  SOURCE_PATH = 'samplelib.dll';

var
  img: TPEImage;
  sym: TPEExportSym;

begin
  img := TPEImage.Create;
  try
    // Read image and parse exports only.
    if not img.LoadFromFile(SOURCE_PATH, [PF_EXPORT]) then
    begin
      writeln('Failed to load image: ', SOURCE_PATH);
      exit;
    end;

    // Print exports.
    for sym in img.ExportSyms.Items do
    begin
      writeln(format('RVA: $%x; ord: $%x; name: "%s"; fwd: "%s"',
        [sym.RVA, sym.Ordinal, sym.Name, sym.ForwarderName]));
    end;

  finally
    img.Free;
  end;
end.
