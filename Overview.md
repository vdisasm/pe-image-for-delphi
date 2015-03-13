# Introduction #

**PEImage** library can be used to parse and modify 32/64 bit executable images. Image can be loaded from stream, file or from mapped image.

The library is part of [VDisAsm Project](http://vdisasm.com/)

Also it can make simple image building/rebuilding. But it's rather experimental.


# Supported features #

## It can load image ##

  * from file
  * from stream
  * from mapped image (i.e. from module in current process address space, like ntdll)
  * from module in other process

## It can parse ##

  * 32/64 bit images. You don't need to worry about field sizes.
  * exports
  * imports
  * relocations
  * thread local storage table
  * long section names from COFF table
  * resources: raw and decoding following formats
    * RT\_BITMAP (PE.Resources.Windows.Bitmap.pas)
    * RT\_VERSION (PE.Resources.VersionInfo.pas)
  * exception records in .pdata section (useful for example for ARM, x64 executables)
  * overlay functions
    * extract to file
    * delete
    * append to other file
  * address conversion between virtual address and relative virtual address.

## Selective parsing ##

You can specify what stage to parse. For example, you can tell it to load only base image and not to waste time for parsing other elements. Or you can specify combination of things to load (exports+imports+relocs...). See TParserFlag's PF\_xxx in PE.Common.pas

## Rebuilding image parts ##

Units PE.Build.??? are responsible for building image directory data. Currently supported:

  * export
  * import
  * resources
  * relocations

## Saving ##

You can modify image and save it to file or stream. It's easy way to make some patches programmatically. Faster way is to convert virtual addresses into file offsets and patch directly in file.

Also you can dump only needed part, like section, overlay, resource.

## Loading and Mapping Executable Image ##

Parsed image can be loaded as executable image in similar way Windows Loader does. Now it works for DLLs and EXEs.

This functionality have to be used very carefully because not all images can run properly.

## Code analysis ##

  * PE.Image.x86 unit
    * searching relative jumps and calls in sections

## Portability ##

It was written with portability in mind and uses minimum platform dependency.

## Usage examples ##

The library can be used for

  * learning PE format
  * creating packers or protectors
  * creating unpackers
  * creating linker for your compiler
  * creating proxy dlls
  * ...

Some examples are provided in trunk.

## Other ##

**TPEMemoryStream** class (unit **PE.MemoryStream**) allows to read mapped in-memory executable as simple stream.

**TProcessModuleStream** class (unit **PE.ProcessModuleStream**) allows to read module in other process as a stream.