{
  First build SampleLib project.
  Then run this project.
  It should list imported delay-loaded functions.
}
program ImportsDelayed;

{$APPTYPE CONSOLE}


uses
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Image,
  PE.Imports.Lib,
  PE.Imports.Func;

// By ordinal only.
function delayed_01: integer; external 'samplelib' delayed index 110;
// By ordinal and hint/name.
function delayed_02: integer; external 'samplelib' delayed index 120 name 'delayed_02';

var
  img: TPEImage;
  Lib: TPEImportLibrary;
  fn: TPEImportFunction;

begin
  ReportMemoryLeaksOnShutdown := True;

  // Force linking of delay loaded imports into this exe.
  delayed_01;
  delayed_02;

  img := TPEImage.Create;
  try
    img.LoadFromFile(ParamStr(0), [PF_IMPORT_DELAYED]);

    for Lib in img.ImportsDelayed.LibsByName do
    begin
      writeln(Lib.Name);
      for fn in Lib.Functions.FunctionsByRVA.Values do
        writeln(format('  va: 0x%x "%s" ordinal %d', [
          img.RVAToVA(fn.RVA), fn.Name, fn.Ordinal]));
    end;

    readln;
  finally
    img.Free;
  end;

end.
