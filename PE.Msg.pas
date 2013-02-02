unit PE.Msg;

interface

type
  TMsgProc = procedure(Text: PWideChar); stdcall;

  TMsgMgr = record
  private
    FMsgProc: TMsgProc;
  public
    constructor Create(AMsgProc: TMsgProc);
    procedure Write(const AText: UnicodeString); overload;
    procedure Write(const AFmt: UnicodeString; const AArgs: array of const); overload;
  end;

  PMsgMgr = ^TMsgMgr;

implementation

uses
  System.SysUtils;

{ TMessageMgr }

procedure TMsgMgr.Write(const AText: UnicodeString);
begin
  if Assigned(FMsgProc) then
    FMsgProc(PWideChar(AText));
end;

constructor TMsgMgr.Create(AMsgProc: TMsgProc);
begin
  FMsgProc := AMsgProc;
end;

procedure TMsgMgr.Write(const AFmt: UnicodeString; const AArgs: array of const);
begin
  Write(Format(AFmt, AArgs));
end;

end.
