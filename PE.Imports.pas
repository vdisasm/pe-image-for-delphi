unit PE.Imports;

interface

uses
  System.Generics.Collections,
  PE.Common;

type
  { PEImage import record }

  TPEImportFunction = class
  public
    Ordinal: uint16;
    Name: AnsiString;
    RVA: TRVA; // rva that will be binded by loader
    procedure Clear; inline;
  end;

  PPEImportFunction = ^TPEImportFunction;

  TPEImportFunctions = TList<TPEImportFunction>;

  TPEImportLibrary = class
  private
    FName: AnsiString; // imported library name
    FFunctions: TPEImportFunctions;
    procedure ImportFunctionNotify(Sender: TObject; const Item: TPEImportFunction;
      Action: TCollectionNotification);
  public
    constructor Create(const AName: AnsiString);
    destructor Destroy; override;

    property Name: AnsiString read FName;
    property Functions: TPEImportFunctions read FFunctions;
  end;

  TPEImports = TList<TPEImportLibrary>;

implementation

{ TImportFunction }

procedure TPEImportFunction.Clear;
begin
  Ordinal := 0;
  Name := '';
  RVA := 0;
end;

{ TImportLibrary }

constructor TPEImportLibrary.Create(const AName: AnsiString);
begin
  inherited Create;
  FFunctions := TPEImportFunctions.Create;
  FFunctions.OnNotify := ImportFunctionNotify;
  FName := AName;
end;

destructor TPEImportLibrary.Destroy;
begin
  FFunctions.Free;
  inherited;
end;

procedure TPEImportLibrary.ImportFunctionNotify(Sender: TObject;
  const Item: TPEImportFunction; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

end.
