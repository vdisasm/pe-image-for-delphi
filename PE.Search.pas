unit PE.Search;

interface

uses
  PE.Section;

{
  *
  * Search byte pattern in ASection starting from AOffset.
  * Result is True if found and false otherwise.
  * AOffset will be set to last position scanned.
  *
  * Each byte of AMask is AND'ed with source byte and compared to pattern.
  * AMask can be smaller than APattern (or empty), but cannot be bigger.
  *
  * ADirection can be negative or positive to choose search direction.
  * If it is 0 the only match checked.
  *
  * Example:
  *
  *              AA ?? BB should be represented like:
  *   APattern:  AA 00 BB
  *   AMask:     AA 00 BB
  *
  *              AA 00 BB should be represented like:
  *   APattern:  AA 00 BB
  *   AMask:     AA FF BB
  *
}
function SearchBytes(
  const ASection: TPESection;
  const APattern: array of byte;
  const AMask: array of byte;
  var AOffset: UInt32;
  ADirection: Integer
  ): boolean;

implementation

function SearchBytes;
var
  pSrc: PByte;
  Mask: byte;
  LastOffset: UInt32;
  i: Integer;
  MaskLeft: Integer;
begin
  if Length(APattern) = 0 then
    Exit(False);

  if (AOffset + Length(APattern)) > ASection.AllocatedSize then
    Exit(False);

  if ADirection < 0 then
    ADirection := -1
  else if ADirection > 0 then
    ADirection := 1;

  pSrc := @ASection.Mem[AOffset];
  LastOffset := ASection.AllocatedSize - Length(APattern);

  while AOffset <= LastOffset do
  begin
    Result := True;
    MaskLeft := Length(AMask);
    for i := 0 to High(APattern) do
    begin
      if MaskLeft <> 0 then
        Mask := AMask[i]
      else
        Mask := $FF;

      if (pSrc[i] and Mask) <> APattern[i] then
      begin
        Result := False;
        break;
      end;

      if MaskLeft <> 0 then
        dec(MaskLeft);
    end;

    // Break if: found/no direction/at lower bound.
    if (Result) or (ADirection = 0) or ((ADirection < 0) and (AOffset = 0)) then
      break;

    // Next address/offset.
    inc(AOffset, ADirection);
    inc(pSrc, ADirection);
  end;
end;

end.
