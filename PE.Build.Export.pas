{
  Building export table to stream.
  This stream can be later saved to section or replace old export table.

  todo: clear old export data
}
unit PE.Build.Export;

interface

uses
  System.Classes,
  PE.Common,
  PE.Section;

{
  * Build export table and store it to stream.
  *
  * PE:              Source PE Image.
  * ExportTableRVA:  RVA of table start.
  * Stream:          Stream to store export table.
}

procedure BuildExports(PE: TObject; ExportTableRVA: TRVA; Stream: TStream);

{
  * Rebuild export section.
  *
  * If TryToOverwriteExportSecttion is True, it will try to put new export
  * section at old section space (if new section is smaller).
  *
  * If new section is bigger than old it will be forced to create new section.
  *
  * Result is new section if it was created or nil if old section was replaced.
}
function ReBuildExports(PE: TObject; TryToOverwriteExportSecttion: boolean): TPESection;

implementation

uses
  System.Generics.Collections,

  PE.Image,
  PE.ExportSym,
  PE.Types.Export,
  PE.Types.Directories;

procedure BuildExports(PE: TObject; ExportTableRVA: TRVA; Stream: TStream);
type
  TSym = record
    sym: TPEExportSym;
    nameRVA: TRVA;
  end;

  TSyms = TList<TSym>;
var
  p: TPEImage;
  i: integer;
  ExpDir: TImageExportDirectory;
  ofs_SymRVAs: uint32;  // sym rvas offsets
  ofs_NameRVAs: uint32; // name rva offsets
  ofs_NameOrds: uint32; // name ordinals
  ofs_LibName: uint32;  // offset of address of names
  sym: TPEExportSym;
  rva32: uint32;
  rvas: packed array of uint32;
  minIndex, maxIndex: word;
var
  nSyms: TSyms;
  nSym: TSym;
  ordinal: word;
begin
  p := TPEImage(PE);

  nSyms := TSyms.Create;

  try

    // Collect named items
    // Find min and max index.
    maxIndex := 0;
    if p.ExportSyms.Count = 0 then
      minIndex := 1
    else
      minIndex := $FFFF;

    for sym in p.ExportSyms.Items do
      begin
        nSym.sym := sym;
        nSym.nameRVA := 0;
        nSyms.Add(nSym);

        if sym.ordinal > maxIndex then
          maxIndex := sym.ordinal;
        if sym.ordinal < minIndex then
          minIndex := sym.ordinal;
      end;

    // Create rvas.
    if maxIndex <> 0 then
      begin
        SetLength(rvas, maxIndex); // zeroed by compiler
        for i := 0 to p.ExportSyms.Count - 1 do
          begin
            sym := p.ExportSyms.Items[i];
            if sym.ordinal <> 0 then
              rvas[sym.ordinal - minIndex] := sym.RVA;
          end;
      end;

    // Calc offsets.
    ofs_SymRVAs := SizeOf(ExpDir);
    ofs_NameRVAs := ofs_SymRVAs + Length(rvas) * SizeOf(rva32);
    ofs_NameOrds := ofs_NameRVAs + nSyms.Count * SizeOf(rva32);
    ofs_LibName := ofs_NameOrds + nSyms.Count * SizeOf(ordinal);

    // Initial seek.
    Stream.Size := ofs_LibName;
    Stream.Position := ofs_LibName;

    // Write exported name.
    if p.ExportedName <> '' then
      p.StreamWriteStrA(Stream, p.ExportedName);

    // Write names.
    for i := 0 to nSyms.Count - 1 do
      begin
        nSym := nSyms[i];
        nSym.nameRVA := ExportTableRVA + Stream.Position;
        nSyms[i] := nSym;
        p.StreamWriteStrA(Stream, nSym.sym.Name);
      end;

    // Write forwarder names.
    for i := 0 to nSyms.Count - 1 do
      begin
        nSym := nSyms[i];
        if nSym.sym.Forwarder then
          begin
            rvas[nSym.sym.ordinal - minIndex] := ExportTableRVA + Stream.Position;
            p.StreamWriteStrA(Stream, nSym.sym.ForwarderName);
          end;
      end;

    // Fill export dir.
    ExpDir.ExportFlags := 0;
    ExpDir.TimeDateStamp := 0;
    ExpDir.MajorVersion := 0;
    ExpDir.MinorVersion := 0;
    if p.ExportedName <> '' then
      ExpDir.nameRVA := ExportTableRVA + ofs_LibName
    else
      ExpDir.nameRVA := 0;
    ExpDir.OrdinalBase := minIndex;
    ExpDir.AddressTableEntries := Length(rvas);
    ExpDir.NumberOfNamePointers := nSyms.Count;
    ExpDir.ExportAddressTableRVA := ExportTableRVA + ofs_SymRVAs;
    ExpDir.NamePointerRVA := ExportTableRVA + ofs_NameRVAs;
    ExpDir.OrdinalTableRVA := ExportTableRVA + ofs_NameOrds;

    // Seek start.
    Stream.Position := 0;

    // Write export dir.
    Stream.Write(ExpDir, SizeOf(ExpDir));

    // Write RVAs of all symbols.
    p.StreamWrite(Stream, rvas[0], Length(rvas) * SizeOf(rvas[0]));

    // Write name RVAs.
    for i := 0 to nSyms.Count - 1 do
      begin
        nSym := nSyms[i];
        rva32 := nSym.nameRVA;
        p.StreamWrite(Stream, rva32, SizeOf(rva32));
      end;

    // Write name ordinals.
    for i := 0 to nSyms.Count - 1 do
      begin
        nSym := nSyms[i];
        ordinal := nSym.sym.ordinal - minIndex;
        p.StreamWrite(Stream, ordinal, SizeOf(ordinal));
      end;

  finally
    nSyms.Free;
  end;

end;

function ReBuildExports(PE: TObject; TryToOverwriteExportSecttion: boolean): TPESection;
const
  DEF_SECTION_NAME  = '.edata';
  DEF_SECTION_FLAGS = $40000040; // readable, initialized data
var
  Stream: TMemoryStream;
  img: TPEImage;
  sec: TPESection;
  dir: TImageDataDirectory;
  destRVA: TRVA;
  destSize: uint32;
begin
  Result := nil;

  img := PE as TPEImage;

  // Create and fill export section.
  Stream := TMemoryStream.Create;
  try

    // Build to get size.
    BuildExports(img, 0, Stream);

    sec := nil;
    destRVA := 0;  // compiler friendly
    destSize := 0; // compiler friendly

    // Try to get old section space.
    if TryToOverwriteExportSecttion then
      if img.DataDirectories.Get(DDIR_EXPORT, @dir) then
        if dir.Size >= Stream.Size then
          if img.RVAToSec(dir.VirtualAddress, @sec) then
            begin
              destRVA := dir.VirtualAddress;
              destSize := dir.Size;
            end;

    // If we still got no section, create new with default name and flags.
    // User can change it later.
    if sec = nil then
      begin
        sec := img.Sections.AddNew(DEF_SECTION_NAME, Stream.Size, DEF_SECTION_FLAGS, nil);
        Result := sec;
        destRVA := sec.RVA;
        destSize := Stream.Size;
      end;

    // Rebuild data to have valid RVAs.
    Stream.Clear;
    BuildExports(img, destRVA, Stream);

    // Move built data to section.
    Move(Stream.Memory^, sec.Mem^, Stream.Size);

    // Update export directory pointer.
    img.DataDirectories.Put(DDIR_EXPORT, destRVA, destSize);
  finally
    Stream.Free;
  end;
end;

end.
