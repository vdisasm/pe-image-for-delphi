unit PE.Build.Import;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Section,
  PE.Build.Common,
  PE.Utils;

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
  fn: TPEImportFunction;
  dq: UInt64;
  hint: word;
begin
  if FPE.Imports.Count = 0 then
    exit;

  NameOrdSize := FPE.ImageWordSize;

  // calc import layout:
  ofsDIR := 0;
  ofsILT := 0;

  for Lib in FPE.Imports.LibsByName do
  begin
    inc(ofsDIR, sizeof(TImportDirectoryTable));
    inc(ofsILT, NameOrdSize * (Lib.Functions.FunctionsByRVA.Count + 1));
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
    Stream.Position := ofsDIR;
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
    Stream.Position := sOfs;
    sOfs := sOfs + StreamWriteStringA(Stream, Lib.Name, 2);

    // write import names/ords
    for fn in Lib.Functions.FunctionsByRVA.Values do
    begin
      Stream.Position := ofsILT;

      if not fn.Name.IsEmpty then
      begin
        // by name
        dq := DirRVA + sOfs;
        Stream.Write(dq, NameOrdSize);
      end
      else
      begin
        // by ordinal
        dq := fn.Ordinal;
        if FPE.Is32bit then
          dq := dq or $80000000
        else
          dq := dq or $8000000000000000;
        Stream.Write(dq, NameOrdSize);
      end;

      // iat (write same value; Windows loader changes this value with real
      // address in LdrpSnapModule).
      if fn.RVA <> 0 then
      begin
        FPE.PositionRVA := fn.RVA;
        if not FPE.WriteEx(dq, NameOrdSize) then
          raise Exception.Create('Write error.');
      end;

      if not fn.Name.IsEmpty then
      begin
        Stream.Position := sOfs;
        // hint
        hint := 0;
        Stream.Write(hint, 2);
        // name
        sOfs := sOfs + sizeof(hint) + StreamWriteStringA(Stream, fn.Name, 2);
      end;
      inc(ofsILT, NameOrdSize);
    end;
    // write empty name/ord
    dq := 0;
    Stream.Position := ofsILT;
    Stream.Write(dq, NameOrdSize);
    inc(ofsILT, NameOrdSize);
  end;

  // last empty descriptor
  Stream.Position := ofsDIR;
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
