{
  Regions of PE Image.
}
unit PE.Regions;

interface

uses
  System.Generics.Collections,
  gmap,
  PE.Common;

type
  TRegionKind =
    (
    RK_NULL = 0,      //
    RK_STR_1BYTE,     // 1 byte string
    RK_STR_2BYTE,     // 2 byte string
    RK_PE = 100,      //
    RK_SEC_VSIZE,     //
    RK_DOS_HEADER,    //
    RK_DOS_BLOCK,     //
    RK_IDT,           // Import Directory Table
    RK_IAT_ITEM,      //
    RK_IAT_ITEM_PATCH //
    );

  TRVARegion = record
    RVA: TRVA;
    Size: Integer;
    constructor Create(RVA: TRVA; Size: Integer);
    class function Less(const a, b: TRVARegion): boolean; static;
    function EndRVA: TRVA; inline;
    function LastRVA: TRVA; inline;
  end;

  TRVARegionMapPair = TPair<TRVARegion, TRegionKind>;
  TRVARegionMap = TMap<TRVARegion, TRegionKind>;

  TRVARegionTrack = class
  protected
    FMap: TRVARegionMap;
  public
    constructor Create;
    destructor Destroy; override;
    property Map: TRVARegionMap read FMap;
  end;

  TRVARegionTracks = TList<TRVARegionTrack>;

  TRegionTracks = class
  private
    function CalcVMSize: UInt64; inline;
  protected
    FList: TRVARegionTracks;
    FTotalRegions: Integer;

    // RVA ranges of all regions on all tracks.
    FStartRVA: TRVA;
    FEndRVA: TRVA;

    procedure TrackNotify(Sender: TObject; const Item: TRVARegionTrack;
      Action: TCollectionNotification);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function Add(const Rgn: TRVARegion; Kind: TRegionKind): boolean;

    property List: TRVARegionTracks read FList;
    property StartRVA: TRVA read FStartRVA;
    property EndRVA: TRVA read FEndRVA;
    property VMSize: UInt64 read CalcVMSize;
  end;

implementation

{ TRVARegion }

constructor TRVARegion.Create(RVA: TRVA; Size: Integer);
begin
  self.RVA := RVA;
  self.Size := Size;
end;

function TRVARegion.EndRVA: TRVA;
begin
  Result := RVA + Size;
end;

function TRVARegion.LastRVA: TRVA;
begin
  Result := RVA + Size - 1;
end;

class function TRVARegion.Less(const a, b: TRVARegion): boolean;
begin
  Result := (a.RVA + a.Size) <= b.RVA;
end;

{ TRegionTracks }

function TRegionTracks.Add(const Rgn: TRVARegion; Kind: TRegionKind): boolean;
var
  Track, TmpTrack: TRVARegionTrack;
  bAddTrack: boolean;
begin
  Track := nil;
  bAddTrack := False;

  // Find or allocate track.
  for TmpTrack in FList do
    if not TmpTrack.Map.ContainsKey(Rgn) then
    begin
      Track := TmpTrack;
      break;
    end;

  if Track = nil then
  begin
    Track := TRVARegionTrack.Create;
    bAddTrack := True;
  end;

  Track.Map.Add(Rgn, Kind);

  // Update ranges.
  if FTotalRegions = 0 then
  begin
    FStartRVA := Rgn.RVA;
    FEndRVA := Rgn.EndRVA;
  end
  else
  begin
    if Rgn.RVA < FStartRVA then
      FStartRVA := Rgn.RVA;
    if Rgn.EndRVA > FEndRVA then
      FEndRVA := Rgn.EndRVA;
  end;

  inc(FTotalRegions);

  if bAddTrack then
    FList.Add(Track);

  Exit(True);
end;

function TRegionTracks.CalcVMSize: UInt64;
begin
  Result := FEndRVA - FStartRVA;
end;

procedure TRegionTracks.Clear;
begin
  FList.Clear;
  FStartRVA := 0;
  FEndRVA := 0;
  FTotalRegions := 0;
end;

constructor TRegionTracks.Create;
begin
  inherited;
  FList := TRVARegionTracks.Create;
  FList.OnNotify := TrackNotify;
end;

destructor TRegionTracks.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TRegionTracks.TrackNotify(Sender: TObject;
  const Item: TRVARegionTrack; Action: TCollectionNotification);
begin
  case Action of
    cnRemoved:
      Item.Free;
  end;
end;

{ TRVARegionTrack }

constructor TRVARegionTrack.Create;
begin
  inherited;
  FMap := TRVARegionMap.Create(TRVARegion.Less);
end;

destructor TRVARegionTrack.Destroy;
begin
  FMap.Free;
  inherited;
end;

end.
