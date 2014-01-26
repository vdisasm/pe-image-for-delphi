unit PE.Build.Import;

interface

uses
  System.Classes,
  System.Generics.Collections,

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
  // Expand
  PE.Image,
  PE.Types.FileHeader,
  //
  PE.Imports,
  PE.Imports.Lib,
  PE.Imports.Func,
  PE.Types.Imports;

procedure TImportBuilder.Build(DirRVA: UInt64; Stream: TStream);
var
  IDir: TImportDirectoryTable;
  sOfs: uint32;
  ofsILT: uint32;
  ofsDIR: uint32;
  NameOrdSize: byte;
  Lib: TPEImportLibrary;
  fnPair: TPair<TRVA, TPEImportFunction>;
  strA: AnsiString;
  dq: UInt64;
  hint: word;
begin
  if FPE.Imports.Count = 0 then
    exit;

  NameOrdSize := FPE.ImageWordSize;

  // calc import layout:
  ofsDIR := 0;
  ofsILT := 0;
  sOfs := 0;

  for Lib in FPE.Imports.LibsByName do
  begin
    inc(ofsDIR, sizeof(TImportDirectoryTable));
    for fnPair in Lib.Functions.FunctionsByRVA do
      inc(ofsILT, NameOrdSize);
    // one last (empty) item
    inc(ofsILT, NameOrdSize);
  end;

  inc(ofsDIR, sizeof(TImportDirectoryTable));

  // set base values
  sOfs := ofsDIR + ofsILT;
  ofsILT := ofsDIR;
  ofsDIR := 0;

  Stream.Size := sOfs;

  // write
  for Lib in FPE.Imports.LibsByName do
  begin
    // write IDT
    Stream.Seek(ofsDIR, TSeekOrigin.soBeginning);
    IDir.ImportLookupTableRVA := DirRVA + ofsILT;
    IDir.TimeDateStamp := 0;
    IDir.ForwarderChain := 0;
    IDir.NameRVA := DirRVA + sOfs;
    if Lib.Functions.Count > 0 then
      IDir.ImportAddressTable := Lib.Functions.FunctionsByRVA.FirstKey
    else
      IDir.ImportAddressTable := 0;
    Stream.Write(IDir, sizeof(TImportDirectoryTable));
    inc(ofsDIR, sizeof(TImportDirectoryTable));

    // write dll name
    Stream.Seek(sOfs, TSeekOrigin.soBeginning);
    strA := Lib.Name + #0;
    if Length(strA) mod 2 <> 0 then
      strA := strA + #0;
    Stream.Write(strA[1], Length(strA));
    inc(sOfs, Length(strA));

    // write import names/ords
    for fnPair in Lib.Functions.FunctionsByRVA do
    begin
      Stream.Seek(ofsILT, TSeekOrigin.soBeginning);
      if fnPair.Value.Name <> '' then
      begin
        // by name
        // ofs of name
        dq := DirRVA + sOfs;
        Stream.Write(dq, NameOrdSize);
        // hint/name
        Stream.Seek(sOfs, TSeekOrigin.soBeginning);
        // hint
        hint := 0;
        Stream.Write(hint, 2);
        // name
        strA := fnPair.Value.Name + #0;
        if Length(strA) mod 2 <> 0 then
          strA := strA + #0;
        Stream.Write(strA[1], Length(strA));
        inc(sOfs, sizeof(hint) + Length(strA));
      end
      else
      begin
        // by ordinal
        dq := fnPair.Value.Ordinal;
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
    Stream.Seek(ofsILT, TSeekOrigin.soBeginning);
    Stream.Write(dq, NameOrdSize);
    inc(ofsILT, NameOrdSize);
  end;

  // last empty descriptor
  Stream.Seek(ofsDIR, TSeekOrigin.soBeginning);
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
  result := True;
end;

end.
