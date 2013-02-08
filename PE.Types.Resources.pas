unit PE.Types.Resources;

interface

type
  MAKEINTRESOURCE = PWideChar;

const

  // The following are the predefined resource types.
  // http://msdn.microsoft.com/en-us/library/windows/desktop/ms648009(v=vs.85).aspx

  RT_CURSOR       = MAKEINTRESOURCE(1);  // Hardware-dependent cursor resource.
  RT_BITMAP       = MAKEINTRESOURCE(2);  // Bitmap resource.
  RT_ICON         = MAKEINTRESOURCE(3);  // Hardware-dependent icon resource.
  RT_MENU         = MAKEINTRESOURCE(4);  // Menu resource.
  RT_DIALOG       = MAKEINTRESOURCE(5);  // Dialog box.
  RT_STRING       = MAKEINTRESOURCE(6);  // String-table entry.
  RT_FONTDIR      = MAKEINTRESOURCE(7);  // Font directory resource.
  RT_FONT         = MAKEINTRESOURCE(8);  // Font resource.
  RT_ACCELERATOR  = MAKEINTRESOURCE(9);  // Accelerator table.
  RT_RCDATA       = MAKEINTRESOURCE(10); // Application-defined resource (raw data).
  RT_MESSAGETABLE = MAKEINTRESOURCE(11); // Message-table entry.
  RT_GROUP_CURSOR = MAKEINTRESOURCE(uint32(RT_CURSOR) + 11); // Hardware-independent cursor resource.
  RT_GROUP_ICON   = MAKEINTRESOURCE(uint32(RT_ICON) + 11); // Hardware-independent icon resource.
  RT_VERSION      = MAKEINTRESOURCE(16);                   // Version resource.
  RT_DLGINCLUDE   = MAKEINTRESOURCE(17);                   // Allows a resource editing tool to associate a string with an .rc file.
  RT_PLUGPLAY     = MAKEINTRESOURCE(19);                   // Plug and Play resource.
  RT_VXD          = MAKEINTRESOURCE(20);                   // VXD.
  RT_ANICURSOR    = MAKEINTRESOURCE(21);                   // Animated cursor.
  RT_ANIICON      = MAKEINTRESOURCE(22);                   // Animated icon.
  RT_HTML         = MAKEINTRESOURCE(23);                   // HTML resource.
  RT_MANIFEST     = MAKEINTRESOURCE(24);                   // Side-by-Side Assembly Manifest.

  RT_NAMES: array [0 .. 24] of string = (
    '#0',              // 0
    'RT_CURSOR',       // 1
    'RT_BITMAP',       // 2
    'RT_ICON',         // 3
    'RT_MENU',         // 4
    'RT_DIALOG',       // 5
    'RT_STRING',       // 6
    'RT_FONTDIR',      // 7
    'RT_FONT',         // 8
    'RT_ACCELERATOR',  // 9
    'RT_RCDATA',       // 10
    'RT_MESSAGETABLE', // 11
    'RT_GROUP_CURSOR', // 12
    '#13',             // 13
    'RT_GROUP_ICON',   // 14
    '#15',             // 15
    'RT_VERSION',      // 16
    'RT_DLGINCLUDE',   // 17
    '#18',             // 18
    'RT_PLUGPLAY',     // 19
    'RT_VXD',          // 20
    'RT_ANICURSOR',    // 21
    'RT_ANIICON',      // 22
    'RT_HTML',         // 23
    'RT_MANIFEST'      // 24
    );

  // 5.9.1. Resource Directory Table

type

  { TResourceDirectoryTable }

  TResourceDirectoryTable = packed record

    // Resource flags. This field is reserved for future use.
    // It is currently set to zero.
    Characteristics: uint32;

    // The time that the resource data was created by the resource compiler.
    TimeDateStamp: uint32;

    // The major version number, set by the user.
    MajorVersion: uint16;

    // The minor version number, set by the user.
    MinorVersion: uint16;

    // The number of directory entries immediately following the table that
    // use strings to identify Type, Name, or Language entries (depending on
    // the level of the table).
    NumberOfNameEntries: uint16;

    // The number of directory entries immediately following the Name entries
    // that use numeric IDs for Type, Name, or Language entries.
    NumberOfIDEntries: uint16;

  end;

  PResourceDirectoryTable = ^TResourceDirectoryTable;

  { TResourceNameEntry }

  TResourceNameEntry = packed record
    case byte of
      0:
        // The address of a string that gives the Type, Name, or Language ID entry,
        // depending on level of table.
        // Non-documented: 0-30 bits used.
        (NameRVA: uint32);
      1:
        // A 32-bit integer that identifies the Type, Name, or Language ID entry.
        (IntegerID: uint32);
  end;

  { TResourceDirectoryEntry }

  TResourceDirectoryEntry = packed record
  private

    // Either Name or Id.
    FEntry: TResourceNameEntry;

    DataEntryRVAorSubdirectoryRVA: uint32;

    function GetDataEntryRVAorSubdirectoryRVA: uint32; inline;
    function GetIntegerID: uint32; inline;
    function GetNameRVA: uint32; inline;
    procedure SetSubDirRVA(const Value: uint32); inline;
    procedure SetDataEntryRVA(const Value: uint32); inline;
    procedure SetNameRVA(const Value: uint32); inline;
    procedure SetIntegerID(const Value: uint32); inline;

  public

    procedure Clear;

    // To check which union select.
    function IsDataEntryRVA: boolean; inline;
    function IsSubdirectoryRVA: boolean; inline;

    // High bit 0. Address of a Resource Data entry (a leaf).
    property DataEntryRVA: uint32 read GetDataEntryRVAorSubdirectoryRVA write SetDataEntryRVA;

    // High bit 1. The lower 31 bits are the address of another resource
    // directory table (the next level down).
    property SubdirectoryRVA: uint32 read GetDataEntryRVAorSubdirectoryRVA write SetSubDirRVA;

    property NameRVA: uint32 read GetNameRVA write SetNameRVA;

    property IntegerID: uint32 read GetIntegerID write SetIntegerID;

  end;

  { TResourceDataEntry }

  TResourceDataEntry = packed record

    // The address of a unit of resource data in the Resource Data area.
    DataRVA: uint32;

    // The size, in bytes, of the resource data that is pointed to by the
    // Data RVA field.
    Size: uint32;

    // The code page that is used to decode code point values within the
    // resource data. Typically, the code page would be the Unicode code page.
    Codepage: uint32;

    // Reserved, must be 0.
    Reserved: uint32;

  end;

implementation

procedure TResourceDirectoryEntry.Clear;
begin
  FEntry.NameRVA := 0;
  DataEntryRVAorSubdirectoryRVA := 0;
end;

function TResourceDirectoryEntry.GetDataEntryRVAorSubdirectoryRVA: uint32;
begin
  Result := DataEntryRVAorSubdirectoryRVA and $7FFFFFFF;
end;

function TResourceDirectoryEntry.GetIntegerID: uint32;
begin
  Result := FEntry.IntegerID;
end;

function TResourceDirectoryEntry.GetNameRVA: uint32;
begin
  Result := FEntry.NameRVA and $7FFFFFFF;
end;

function TResourceDirectoryEntry.IsDataEntryRVA: boolean;
begin
  Result := (DataEntryRVAorSubdirectoryRVA and $80000000) = 0;
end;

function TResourceDirectoryEntry.IsSubdirectoryRVA: boolean;
begin
  Result := (DataEntryRVAorSubdirectoryRVA and $80000000) <> 0;
end;

procedure TResourceDirectoryEntry.SetDataEntryRVA(const Value: uint32);
begin
  DataEntryRVAorSubdirectoryRVA := Value and $7FFFFFFF;
end;

procedure TResourceDirectoryEntry.SetIntegerID(const Value: uint32);
begin
  FEntry.IntegerID := Value;
end;

procedure TResourceDirectoryEntry.SetNameRVA(const Value: uint32);
begin
 FEntry.NameRVA := Value and $7FFFFFFF;
end;

procedure TResourceDirectoryEntry.SetSubDirRVA(const Value: uint32);
begin
  DataEntryRVAorSubdirectoryRVA := Value or $80000000;
end;

end.
