unit PE.ExportSym;

interface

uses
  System.Generics.Collections,
  PE.Common;

type

  { TPEExportSym }

  TPEExportSym = class
    RVA: TRVA;
    Ordinal: dword;
    Name: AnsiString;
    ForwarderName: AnsiString;
    Forwarder: boolean;

    // Is this symbol has RVA or is forwarder.
    function IsValid: boolean; inline;

    procedure Clear;
    function Clone: TPEExportSym;
  end;

  PPEExportSym = ^TPEExportSym;

  TPEExportSymVec = TList<TPEExportSym>;
  TPEExportSymByRVA = TDictionary<TRVA, TPEExportSym>;

  { TPEExportSyms }

  TPEExportSyms = class
  private
    FItems: TPEExportSymVec;
    // FItemsByRVA: TPEExportSymByRVA;
    function GetCount: integer;
    procedure ExportSymNotify(Sender: TObject; const Item: TPEExportSym;
      Action: TCollectionNotification);
  public
    constructor Create;
    destructor Destroy; override;

    // Add item to list of symbols.
    // If SetOrdinal is True, src Item ordinal will be fixed to last sym number.
    procedure Add(Item: TPEExportSym; SetOrdinal: boolean = false);

    procedure AddByName(RVA: TRVA; const Name: AnsiString);

    // Usually you will not need it.
    procedure AddByOrdinal(RVA: TRVA; Ordinal: dword);

    procedure AddForwarder(const Name, ForwarderName: AnsiString);

    procedure Clear;

    // Get item by RVA or nil if not found.
    // todo: there can be many exports with same RVA
    // function GetItemByRVA(RVA: TRVA): TPEExportSym; inline;

    property Count: integer read GetCount;
    property Items: TPEExportSymVec read FItems;
  end;

implementation

function TPEExportSym.Clone: TPEExportSym;
begin
  result := TPEExportSym.Create;
  result.RVA := self.RVA;
  result.Ordinal := self.Ordinal;
  result.Name := self.Name;
  result.ForwarderName := self.ForwarderName;
  result.Forwarder := self.Forwarder;
end;

function TPEExportSym.IsValid: boolean;
begin
  // Either forwarder or has rva.
  result := Forwarder or (RVA <> 0);
end;

procedure TPEExportSym.Clear;
begin
  RVA := 0;
  Ordinal := 0;
  Name := '';
  ForwarderName := '';
  Forwarder := false;
end;

{ TExportSyms }

procedure TPEExportSyms.Add(Item: TPEExportSym; SetOrdinal: boolean = false);
begin
  if SetOrdinal then
    Item.Ordinal := FItems.Count + 1;
  FItems.Add(Item);
  // todo: there can be many exports with same RVA
  // FItemsByRVA.Add(Item.RVA, Item);
end;

procedure TPEExportSyms.AddByName(RVA: TRVA; const Name: AnsiString);
var
  Sym: TPEExportSym;
begin
  Sym := TPEExportSym.Create;
  Sym.RVA := RVA;
  Sym.Name := Name;
  Add(Sym, True);
end;

procedure TPEExportSyms.AddByOrdinal(RVA: TRVA; Ordinal: dword);
var
  Sym: TPEExportSym;
begin
  Sym := TPEExportSym.Create;
  Sym.RVA := RVA;
  Sym.Ordinal := Ordinal;
  Add(Sym, True);
end;

procedure TPEExportSyms.AddForwarder(const Name, ForwarderName: AnsiString);
var
  Sym: TPEExportSym;
begin
  Sym := TPEExportSym.Create;
  Sym.Name := Name;
  Sym.ForwarderName := ForwarderName;
  Sym.Forwarder := True;
  Add(Sym, True);
end;

procedure TPEExportSyms.Clear;
begin
  FItems.Clear;
  // FItemsByRVA.Clear;
end;

constructor TPEExportSyms.Create;
begin
  FItems := TPEExportSymVec.Create;
  FItems.OnNotify := ExportSymNotify;

  // FItemsByRVA := TPEExportSymByRVA.Create;
end;

destructor TPEExportSyms.Destroy;
begin
  // FItemsByRVA.Free;
  FItems.Free;
  inherited;
end;

procedure TPEExportSyms.ExportSymNotify(Sender: TObject;
  const Item: TPEExportSym; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    Item.Free;
end;

function TPEExportSyms.GetCount: integer;
begin
  result := FItems.Count;
end;

// function TPEExportSyms.GetItemByRVA(RVA: TRVA): TPEExportSym;
// begin
// if not FItemsByRVA.TryGetValue(RVA, result) then
// result := nil;
// end;

end.
