program ImportsEnumeration;

{$APPTYPE CONSOLE}


uses
  System.SysUtils,
  System.Generics.Collections, // using TPair (in AnotherWayToEnumerate procedure)

  PE.Common, // using TRVA

  PE.Image,
  PE.Imports.Lib,  // using TPEImportLibrary
  PE.Imports.Func; // using TPEImportFunction

procedure Enumerate(Img: TPEImage; ShowRVAs: boolean);
var
  Lib: TPEImportLibrary;
  Fn: TPEImportFunction;
  rva: TRVA;
begin
  // Scan libraries.
  for Lib in Img.Imports.Libs do
  begin
    writeln(format('"%s"', [Lib.Name]));

    rva := Lib.IatRva;

    // Scan imported functions (sorted by RVA).
    // It's map of RVA->Func (key->value).
    for Fn in Lib.Functions do
    begin
      write('  '); // indent

      if ShowRVAs then
        write(format('rva: %-8x', [rva]));

      if Fn.Name <> '' then
        writeln(format('"%s"', [Fn.Name]))
      else
        writeln(format('"%s" ordinal: %d', [Fn.Name, Fn.Ordinal]));

      inc(rva, Img.ImageWordSize);
    end;
    inc(rva, Img.ImageWordSize); // null

    writeln;
  end;
end;

procedure AnotherWayToEnumerate(Img: TPEImage);
var
  Lib: TPEImportLibrary;
  Func: TPEImportFunction;
  rva: TRVA;
begin
  for Lib in Img.Imports.Libs do
  begin
    rva := Lib.IatRva;
    for Func in Lib.Functions do
    begin
      writeln(format('rva: %-8x %s "%s" %d', [rva, Lib.Name, Func.Name, Func.Ordinal]));
      inc(rva, Img.ImageWordSize);
    end;
    inc(rva, Img.ImageWordSize); // null
  end;
end;

procedure main;
var
  Img: TPEImage;
begin
  Img := TPEImage.Create;
  try
    Img.LoadFromFile('SampleLib.dll');

    writeln(format('Enumerating imports of "%s"', [Img.FileName]));
    writeln;

    // Try either Enumerate or AnotherWayToEnumerate

    Enumerate(Img, True);

    // AnotherWayToEnumerate(Img);

  finally
    Img.Free;
  end;
end;

begin
  main;
  readln;

end.
