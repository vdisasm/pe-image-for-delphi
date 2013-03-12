{
  Example of filling section memory.
}
program FillMem;

uses
  PE.Common,
  PE.Image,
  PE.Section,
  PE.Types.Directories;

var
  img: TPEImage;
  sec: TPESection;
  dir: TImageDataDirectory;

begin
  img := TPEImage.Create;
  try
    // load image
    img.LoadFromFile('SampleLib.dll');
    // try get import directory info
    if img.DataDirectories.Get(DDIR_IMPORT, @dir) then
    begin
      // find section where import directory is located
      if img.Sections.RVAToSec(dir.VirtualAddress, @sec) then
      begin
        // Fill directory data block with zeros.
        img.Sections.FillMemory(dir.VirtualAddress, dir.Size, 0);
      end;
      img.SaveToFile('SampleLib_with_import_directory_zeroed.dll')
    end;
  finally
    img.Free;
  end;

end.
