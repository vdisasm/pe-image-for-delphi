unit PE.Parser.TLS;

interface

uses
  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.TLS,
  PE.TLS;

type
  TPETLSParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image;

{ TPETLSParser }

function TPETLSParser.Parse: TParserResult;
var
  PE: TPEImage;
var
  Dir: TImageDataDirectory;
  TLSDir: TTLSDirectory;
  AddressofCallbacks, VA: TVA;
  bRead: boolean;
begin
  PE := (FPE as TPEImage);

  if not PE.DataDirectories.Get(DDIR_TLS, @Dir) then
    exit(PR_OK);
  if Dir.IsEmpty then
    exit(PR_OK);

  // Compiler friendly.
  bRead := False;
  AddressofCallbacks := 0;

  if PE.SeekRVA(Dir.VirtualAddress) then
    case PE.ImageBits of
      32:
        begin
          bRead := PE.ReadEx(@TLSDir.tls32, SizeOf(TLSDir.tls32));
          AddressofCallbacks := TLSDir.tls32.AddressofCallbacks;
        end;
      64:
        begin
          bRead := PE.ReadEx(@TLSDir.tls64, SizeOf(TLSDir.tls64));
          AddressofCallbacks := TLSDir.tls64.AddressofCallbacks;
        end;
    else
      exit(PR_ERROR);
    end;

  if not bRead then
    exit(PR_ERROR);

  // Assign dir.
  PE.TLS.Dir := TLSDir;

  if PE.SeekVA(AddressofCallbacks) then
    while True do
    begin
      VA := PE.ReadUIntPE;
      if VA = 0 then
        break;
      PE.TLS.CallbackRVAs.Add(PE.VAToRVA(VA));
    end;

  result := PR_OK;

end;

end.
