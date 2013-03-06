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
  System.Classes,
  PE.Image,
  PE.Resources;

{ Values for Windows PE. }

type
  RSRCID = UInt32;

const
  // The following are the predefined resource types.
  // http://msdn.microsoft.com/en-us/library/windows/desktop/ms648009(v=vs.85).aspx

  RT_CURSOR       = RSRCID(1);                      // Hardware-dependent cursor resource.
  RT_BITMAP       = RSRCID(2);                      // Bitmap resource.
  RT_ICON         = RSRCID(3);                      // Hardware-dependent icon resource.
  RT_MENU         = RSRCID(4);                      // Menu resource.
  RT_DIALOG       = RSRCID(5);                      // Dialog box.
  RT_STRING       = RSRCID(6);                      // String-table entry.
  RT_FONTDIR      = RSRCID(7);                      // Font directory resource.
  RT_FONT         = RSRCID(8);                      // Font resource.
  RT_ACCELERATOR  = RSRCID(9);                      // Accelerator table.
  RT_RCDATA       = RSRCID(10);                     // Application-defined resource (raw data).
  RT_MESSAGETABLE = RSRCID(11);                     // Message-table entry.
  RT_GROUP_CURSOR = RSRCID(UInt32(RT_CURSOR) + 11); // Hardware-independent cursor resource.
  RT_GROUP_ICON   = RSRCID(UInt32(RT_ICON) + 11);   // Hardware-independent icon resource.
  RT_VERSION      = RSRCID(16);                     // Version resource.
  RT_DLGINCLUDE   = RSRCID(17);                     // Allows a resource editing tool to associate a string with an .rc file.
  RT_PLUGPLAY     = RSRCID(19);                     // Plug and Play resource.
  RT_VXD          = RSRCID(20);                     // VXD.
  RT_ANICURSOR    = RSRCID(21);                     // Animated cursor.
  RT_ANIICON      = RSRCID(22);                     // Animated icon.
  RT_HTML         = RSRCID(23);                     // HTML resource.
  RT_MANIFEST     = RSRCID(24);                     // Side-by-Side Assembly Manifest.

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

    // Add new or update existing resource and return resource node.
    function &Set(Source: TStream; const &Type, Name: string; Language: word = 0): TResourceTreeLeafNode;
  end;

implementation

uses
  System.SysUtils;

function TWindowsResourceTree.&Set(Source: TStream; const &Type, Name: string;
  Language: word): TResourceTreeLeafNode;
begin
  raise Exception.Create('Not implemented');
end;

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
