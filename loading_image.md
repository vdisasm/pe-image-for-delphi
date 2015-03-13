In most cases to work with PE image first create instance of **TPEImage** class

```
uses
  PE.Image;

...

procedure example;
var
  img: TPEImage;
begin
  img := TPEImage.Create;
  try
    // use image
  finally
    img.Free;
  end;
end;
```

Some functions are static and don't need class creation. Like **IsPE** function to check if file has MZ/PE signatures

```
if TPEImage.IsPE('myfile.exe') then
begin
  // it is PE image (MZ/PE signatures present)
end
else
begin
  // it's not
end;
```

Two base units are:

|PE.Image|Contains TPEImage class which does most of the work|
|:-------|:--------------------------------------------------|
|PE.Common|Contains base types and constants|

# Loading image #

When loading image you need to specify

## Image source ##

It can be _TStream_, _File_ or _Running Process_.

## Things to parse ##

To make image loading faster you can specify what image parts to load.

Currently all sections are loaded into memory and can be accessed by **Sections** property.

See **TParserFlag** in **PE.Common** unit

|Flag|Description|Property to Access|
|:---|:----------|:-----------------|
|PF\_EXPORT|Parse exported symbols.|ExportSyms|
|PF\_IMPORT|Parse imported symbols.|Imports|
|PF\_IMPORT\_DELAYED|Parse delayed imports.|ImportsDelayed|
|PF\_RELOCS|Parse relocations (fixups)|Relocs|
|PF\_TLS|Parse Thread-Local Storage directory|TLS|
|PF\_RESOURCES|Parse resources|ResourceTree|

By default all flags used (DEFAULT\_PARSER\_FLAGS which equals ALL\_PARSER\_FLAGS)

## Image layout ##
or image kind, declared in **PE.Common**
|PEIMAGE\_KIND\_DISK|use disk layout|
|:------------------|:--------------|
|PEIMAGE\_KIND\_MEMORY|use memory layout|

When you load normal PE use PEIMAGE\_KIND\_DISK.

PEIMAGE\_KIND\_MEMORY is used to load image from already running (mapped) image.

# Functions to load image #

```
LoadFromStream
```
You can define source stream, things to parse and image layout.

```
LoadFromFile
```
You can define source file name and things to parse. Disk layout used.

```
LoadFromMappedImage
```
Load image from module in current process.<br>
There are overloaded methods to define <b>module file name</b> or <b>module base address</b> in current process.<br>
You can define things to parse. Memory layout used.<br>
<br>
Internally it creates memory stream mapped to module (see <b>TPEMemoryStream</b> in unit PE.MemoryStream) and loads image from the stream.<br>
<pre><code>LoadFromProcessImage<br>
</code></pre>
Load image from module in any available process.<br>
You can define <b>process id</b>, <b>module address</b> and things to parse. Memory layout used.<br>
<br>
Internally it creates memory stream to read from other process (see <b>TProcessModuleStream</b> in unit PE.ProcessModuleStream) and loads image from the stream.