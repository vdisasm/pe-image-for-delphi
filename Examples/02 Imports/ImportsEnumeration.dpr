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
begin
  // Scan libraries.
  for Lib in Img.Imports.LibsByName do
  begin
    writeln(format('"%s"', [Lib.Name]));

    // Scan imported functions (sorted by RVA).
    // It's map of RVA->Func (key->value).
    for Fn in Lib.Functions.FunctionsByRVA.Values do
    begin
      write('  '); // indent

      if ShowRVAs then
        write(format('rva: %-8x', [Fn.RVA]));

      if Fn.Name <> '' then
        writeln(format('"%s"', [Fn.Name]))
      else
        writeln(format('"%s" ordinal: %d', [Fn.Name, Fn.Ordinal]))
    end;
    writeln;
  end;
end;

procedure AnotherWayToEnumerate(Img: TPEImage);
var
  Lib: TPEImportLibrary;
  pair: TPair<TRVA, TPEImportFunction>;
begin
  for Lib in Img.Imports.LibsByName do
    for pair in Lib.Functions.FunctionsByRVA do
    begin
      // pair.key is rva of function
      // pair.value is function
      writeln(format('rva: %-8x %s "%s" %d', [pair.Key, Lib.Name, pair.Value.Name, pair.Value.Ordinal]));
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
