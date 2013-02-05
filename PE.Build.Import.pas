unit PE.Build.Import;

interface

uses
  System.Classes,
  PE.Common,
  PE.Section,
  PE.Build.Common;

type
  TImportBuilder = class(TDirectoryBuilder)
  public
    procedure Build(DirRVA: UInt64; Stream: TStream); override;
    class function GetDefaultSectionFlags: Cardinal; override;
    class function GetDefaultSectionName: string; override;
    class function NeedRebuildingIfRVAChanged: Boolean; override;
  end;

implementation

uses
  PE.Imports,
  PE.Types.Imports;

procedure TImportBuilder.Build(DirRVA: UInt64; Stream: TStream);
var
  IDir: TImportDirectoryTable;
  iLib, iFn: integer;
  sOfs: uint32;
  ofsILT: uint32;
  ofsDIR: uint32;
  NameOrdSize: byte;
  lib: TPEImportLibrary;
  strA: AnsiString;
  dq: UInt64;
  hint: word;
begin
  if FPE.Imports.Count = 0 then
    exit;

  if FPE.Is32bit then
    NameOrdSize := 4
  else
    NameOrdSize := 8;

  // reserve space for import descriptors
  sOfs := sizeof(TImportDirectoryTable) * (FPE.Imports.Count + 1);
  ofsILT := sOfs;
  ofsDIR := 0;

  // calc size for import names|ordinals
  for iLib := 0 to FPE.Imports.Count - 1 do
    for iFn := 0 to FPE.Imports[iLib].Functions.Count - 1 + 1 do
      inc(sOfs, NameOrdSize);

  Stream.Size := sOfs;

  // write
  for iLib := 0 to FPE.Imports.Count - 1 do
  begin
    lib := FPE.Imports[iLib];

    Stream.Seek(ofsDIR, 0);
    IDir.ImportLookupTableRVA := DirRVA + ofsILT;
    IDir.TimeDataStamp := 0;
    IDir.ForwarderChain := 0;
    IDir.NameRVA := DirRVA + sOfs;
    if FPE.Imports[iLib].Functions.Count > 0 then
      IDir.ImportAddressTable := lib.Functions[0].RVA
    else
      IDir.ImportAddressTable := 0;
    Stream.Write(IDir, sizeof(TImportDirectoryTable));
    inc(ofsDIR, sizeof(TImportDirectoryTable));

    // write dll name
    Stream.Seek(sOfs, 0);
    strA := lib.Name + #0;
    if Length(strA) mod 2 <> 0 then
      strA := strA + #0;
    Stream.Write(strA[1], Length(strA));
    inc(sOfs, Length(strA));

    // write import names/ords
    for iFn := 0 to lib.Functions.Count - 1 do
    begin
      Stream.Seek(ofsILT, 0);
      if lib.Functions[iFn].Name <> '' then
      begin
        // by name
        // ofs of name
        dq := DirRVA + sOfs;
        Stream.Write(dq, NameOrdSize);
        // hint/name
        Stream.Seek(sOfs, 0);
        // hint
        hint := 0;
        Stream.Write(hint, 2);
        // name
        strA := lib.Functions[iFn].Name + #0;
        if Length(strA) mod 2 <> 0 then
          strA := strA + #0;
        Stream.Write(strA[1], Length(strA));
        inc(sOfs, 2 + Length(strA));
      end
      else
      begin
        // by ordinal
        dq := lib.Functions[iFn].Ordinal;
        if FPE.Is32bit then
          dq := dq or $80000000
        else
          dq := dq or $8000000000000000;
        Stream.Write(dq, NameOrdSize);
      end;
      inc(ofsILT, NameOrdSize);
    end;
    // write empty name/ord
    dq := 0;
    Stream.Seek(ofsILT, 0);
    Stream.Write(dq, NameOrdSize);
    inc(ofsILT, NameOrdSize);
  end;

  // last empty descriptor
  Stream.Seek(ofsDIR, 0);
  IDir.Clear;
  Stream.Write(IDir, sizeof(TImportDirectoryTable));
end;

class function TImportBuilder.GetDefaultSectionFlags: Cardinal;
begin
  result := $C0000040;
end;

class function TImportBuilder.GetDefaultSectionName: string;
begin
  result := '.idata';
end;

class function TImportBuilder.NeedRebuildingIfRVAChanged: Boolean;
begin
  Result := True;
end;

end.
