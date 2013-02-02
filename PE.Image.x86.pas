{
  *
  * Class for X86, X86-64 specifics.
  *
}
unit PE.Image.x86;

interface

uses
  System.Generics.Collections,
  PE.Common,
  PE.Image,
  PE.Section;

type
  TPEImageX86 = class(TPEImage)
  protected
    // Find relative jump or call in section, e.g e8,x,x,x,x or e9,x,x,x,x.
    // List must be created before passing it to the function.
    // Found VAs will be appended to list.
    function FindRelativeJumpInternal(Sec: TPESection; ByteOpcode: Byte;
      TargetVA: TVA; List: TList<TVA>): Boolean;
  public
    function FindRelativeJump(Sec: TPESection; TargetVA: TVA; List: TList<TVA>): Boolean;
    function FindRelativeCall(Sec: TPESection; TargetVA: TVA; List: TList<TVA>): Boolean;
  end;

implementation

const
  OPCODE_CALL_REL = $E8;
  OPCODE_JUMP_REL = $E9;

  { TPEImageX86 }

function TPEImageX86.FindRelativeCall(Sec: TPESection; TargetVA: TVA;
  List: TList<TVA>): Boolean;
begin
  Result := FindRelativeJumpInternal(Sec, OPCODE_CALL_REL, TargetVA, List);
end;

function TPEImageX86.FindRelativeJump(Sec: TPESection; TargetVA: TVA;
  List: TList<TVA>): Boolean;
begin
  Result := FindRelativeJumpInternal(Sec, OPCODE_JUMP_REL, TargetVA, List);
end;

function TPEImageX86.FindRelativeJumpInternal(Sec: TPESection; ByteOpcode: Byte;
  TargetVA: TVA; List: TList<TVA>): Boolean;
var
  curVa, va0, va1, tstVa: TVA;
  delta: int32;
  opc: Byte;
begin
  Result := False;

  va0 := RVAToVA(Sec.RVA);
  va1 := RVAToVA(Sec.GetEndRVA - SizeOf(ByteOpcode) - SizeOf(delta));

  if not SeekVA(va0) then
    exit(False);

  while self.PositionVA <= va1 do
    begin
      curVa := self.PositionVA;

      // get opcode
      if Read(@opc, SizeOf(ByteOpcode)) <> SizeOf(ByteOpcode) then
        exit;
      if opc = ByteOpcode then
        // on found probably jmp/call
        begin
          delta := int32(ReadUInt32);
          tstVa := curVa + SizeOf(ByteOpcode) + SizeOf(delta) + delta;
          if tstVa = TargetVA then
            begin // hit
              List.Add(curVa);
              Result := True; // at least 1 result is ok
            end
          else
            begin
              if not SeekVA(curVa + SizeOf(ByteOpcode)) then
                exit;
            end;
        end;
    end;
end;

end.
