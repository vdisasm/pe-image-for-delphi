{
  Unit to manipulate resources in Windows oriented way.

  It means 3 resource levels:
  - Type (RT_...)
  - Name
  - Language
}
unit PE.Resources.Windows;

interface

uses
  PE.Image,
  PE.Resources;

{ Values for Windows PE. }

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

type
  TWindowsResourceTree = class
  protected
    FResourceTree: TResourceTree;
  public
    constructor Create(ResourceTree: TResourceTree);

    // Find resource by Type, Name and Language (optional).
    // The function is similar to FindResourceEx:
    // http://msdn.microsoft.com/en-us/library/windows/desktop/ms648043(v=vs.85).aspx
    function Find(const &Type, Name: string; Language: word = 0): TResourceTreeLeafNode;
  end;

implementation

uses
  System.SysUtils;

constructor TWindowsResourceTree.Create(ResourceTree: TResourceTree);
begin
  FResourceTree := ResourceTree;
end;

function TWindowsResourceTree.Find(const &Type, Name: string;
  Language: word): TResourceTreeLeafNode;
begin
  raise Exception.Create('Not implemented');
end;

end.
