unit PE.Parser.Export;

interface

uses
  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.Export;

type
  TPEExportParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image,
  PE.ExportSym;

{ TPEExportParser }

function TPEExportParser.Parse: TParserResult;
var
  ExpIDD: TImageDataDirectory;
  ExpDir: TImageExportDirectory;
  i, base, ordnl: Integer;
  RVAs: packed array of uint32;
  NamePointerRVAs: packed array of uint32;
  OrdinalTableRVAs: packed array of UInt16;
  Exp: array of TPEExportSym;
  Item: TPEExportSym;
begin
  with TPEImage(FPE) do
  begin
    begin

      // Clear exports.
      ExportSyms.Clear;

      // Get export dir.
      if not DataDirectories.Get(DDIR_EXPORT, @ExpIDD) then
        exit(PR_OK);

      // No exports is ok.
      if ExpIDD.IsEmpty then
        exit(PR_OK);

      // If can't find Export dir, failure.
      if not SeekRVA(ExpIDD.VirtualAddress) then
        exit(PR_ERROR);

      // If can't read whole table, failure.
      if not ReadEx(@ExpDir, Sizeof(ExpDir)) then
        exit(PR_ERROR);

      // If no addresses, ok.
      if ExpDir.AddressTableEntries = 0 then
        exit(PR_OK);

      // Read lib exported name.
      if (ExpDir.NameRVA <> 0) and (SeekRVA(ExpDir.NameRVA)) then
        ExportedName := ReadANSIString;

      base := ExpDir.OrdinalBase;

      // Check if there's too many exports.
      if (ExpDir.AddressTableEntries >= SUSPICIOUS_MIN_LIMIT_EXPORTS) or
        (ExpDir.NumberOfNamePointers >= SUSPICIOUS_MIN_LIMIT_EXPORTS) then
      begin
        exit(PR_SUSPICIOUS);
      end;

      SetLength(Exp, ExpDir.AddressTableEntries);
      SetLength(RVAs, ExpDir.AddressTableEntries);

      // load RVAs of exported data
      if not(SeekRVA(ExpDir.ExportAddressTableRVA) and
        ReadEx(@RVAs[0], 4 * ExpDir.AddressTableEntries)) then
        exit(PR_ERROR);

      if ExpDir.NumberOfNamePointers <> 0 then
      begin
        // name/ordinal only
        SetLength(NamePointerRVAs, ExpDir.NumberOfNamePointers);
        SetLength(OrdinalTableRVAs, ExpDir.NumberOfNamePointers);

        // load RVAs of name pointers
        if not((SeekRVA(ExpDir.NamePointerRVA)) and
          ReadEx(@NamePointerRVAs[0], 4 * ExpDir.NumberOfNamePointers)) then
          exit(PR_ERROR);

        // load ordinals according to names
        if not((SeekRVA(ExpDir.OrdinalTableRVA)) and
          ReadEx(@OrdinalTableRVAs[0], 2 * ExpDir.NumberOfNamePointers)) then
          exit(PR_ERROR);
      end;

      for i := 0 to ExpDir.AddressTableEntries - 1 do
      begin
        Item := TPEExportSym.Create;
        Item.Ordinal := i + base;
        Item.RVA := RVAs[i];

        Exp[i] := Item;

        // if rva in export section, it's forwarder
        Exp[i].Forwarder := ExpIDD.Contain(RVAs[i]);
      end;

      // read names
      for i := 0 to ExpDir.NumberOfNamePointers - 1 do
      begin
        if (NamePointerRVAs[i] <> 0) then
        begin
          ordnl := OrdinalTableRVAs[i];
          if Exp[ordnl].IsValid then
          begin
            // read export name
            if not SeekRVA(NamePointerRVAs[i]) then
              exit(PR_ERROR);
            Exp[ordnl].Name := ReadANSIString;

            // read forwarder, if it is
            if Exp[ordnl].Forwarder then
            begin
              // if it is forwarder, rva will point inside of export dir.
              if not SeekRVA(Exp[ordnl].RVA) then
                exit(PR_ERROR);
              Exp[ordnl].ForwarderName := ReadANSIString;
              Exp[ordnl].RVA := 0; // no real address
            end;

          end;

        end;
      end;

      // finally array to list
      for i := low(Exp) to high(Exp) do
        if Exp[i].IsValid then
          ExportSyms.Add(Exp[i])
        else
          Exp[i].Free;

      exit(PR_OK);

    end;
  end;
end;

end.
