unit PE.Build;

interface

uses
  System.Classes,
  PE.Common,
  PE.Section;

{
  * Rebuild directory data.
  *
  * If TryToOverwritesection is True, it will try to put new section at
  * old section space (if new section is smaller).
  *
  * If new section is bigger than old it will be forced to create new section.
  *
  * Result is new section if it was created or nil if old section was replaced.
}
function ReBuildDirData(PE: TObject; DDIR_ID: integer; Overwrite: boolean): TPESection;

implementation

uses
  PE.Image,
  PE.Types.Directories,
  PE.Build.Common,

  PE.Build.Export,
  PE.Build.Import,
  PE.Build.Resource;

const
  RebuilderTable: array [0 .. DDIR_LAST] of TDirectoryBuilderClass =
    (
    PE.Build.Export.TExportBuilder, // export
    PE.Build.Import.TImportBuilder, // import
    PE.Build.Resource.TRsrcBuilder, // resources
    nil,                            // exception
    nil,                            // certificate
    nil,                            // relocations
    nil,                            // debug
    nil,                            // architecture
    nil,                            // global ptr
    nil,                            // tls
    nil,                            // load config
    nil,                            // bound import
    nil,                            // iat
    nil,                            // delay import
    nil                             // clr runtime header
    );

function ReBuildDirData(PE: TObject; DDIR_ID: integer; Overwrite: boolean): TPESection;
var
  stream: TMemoryStream;
  builder: TDirectoryBuilder;
  img: TPEImage;
  sec: TPESection;
  dir: TImageDataDirectory;
  prognoseRVA, destRVA: TRVA;
  destSize: uint32;
begin
  Result := nil;

  if (DDIR_ID < 0) or (DDIR_ID > High(RebuilderTable)) then
    exit; // no builder found

  if RebuilderTable[DDIR_ID] = nil then
    exit; // no builder found

  img := PE as TPEImage;

  builder := RebuilderTable[DDIR_ID].Create(img);
  stream := TMemoryStream.Create;
  try

    // Prognose dest RVA.
    if img.DataDirectories.Get(DDIR_ID, @dir) then
      prognoseRVA := dir.VirtualAddress
    else
      prognoseRVA := 0;

    // Build to get size.
    builder.Build(prognoseRVA, stream);

    sec := nil;
    destRVA := 0;  // compiler friendly
    destSize := 0; // compiler friendly

    // Try to get old section space.
    if Overwrite then
      if img.DataDirectories.Get(DDIR_ID, @dir) then
        if dir.Size >= stream.Size then
          if img.RVAToSec(dir.VirtualAddress, @sec) then
          begin
            // If directory occupies whole section.
            if (sec.RVA = dir.VirtualAddress) and (sec.RawSize = dir.Size) then
            begin
              // We can resize the section.
              img.Sections.Resize(sec, stream.Size);
            end;
            // Set dest rva/size.
            destRVA := dir.VirtualAddress;
            destSize := dir.Size;
          end;

    // If we still have no section, create new with default name and flags.
    // User can change it later.
    if sec = nil then
    begin
      sec := img.Sections.AddNew(AnsiString(builder.GetDefaultSectionName),
        stream.Size, builder.GetDefaultSectionFlags, nil);
      destRVA := sec.RVA;
      destSize := stream.Size;
    end;

    // Rebuild data to have valid RVAs (if prognose is wrong)
    if builder.NeedRebuildingIfRVAChanged then
      if prognoseRVA <> destRVA then
      begin
        stream.Clear;
        builder.Build(destRVA, stream);
      end;

    // Move built data to section.
    Move(stream.Memory^, sec.Mem^, stream.Size);

    // Update directory pointer.
    img.DataDirectories.Put(DDIR_ID, destRVA, destSize);

    Result := sec;

  finally
    builder.Free;
    stream.Free;
  end;
end;

end.
