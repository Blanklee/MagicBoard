unit Client;

interface

uses
  Windows, SysUtils, Classes, StdCtrls, ComCtrls, ScktComp,
  Controls, Graphics, Globals, BlankUtils, Math;

type
  // Server 프로그램용 TClient: Server에 접속된 각 Client 개체들
  // 원래 Server 프로그램에서 array[1..MAX_CLIENTS] of XXX로 각자 만들던 것을 1개 Class로 모음
  TClient = class
  private
    FTotalSize: int64;      // 보내야 할 총용량
    FTotalSent: int64;      // 현재 보낸 총용량
    FTotalSending: int64;   // 파일 1개를 보내는 중의 TotalSent
    FSocket: TCustomWinSocket;
    FOnMemoOut: TMemoOutEvent;
    procedure TriggerMemoOut (msg: string);
    procedure Socket1Error (Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure SetTotalSize (Value: int64);
  protected
    function GetConnected: boolean;
    function GetSelected: boolean;
    procedure SetSocket (Value: TCustomWinSocket);
  public
    Group: integer;       // 사용안함
    Number: integer;
    Name: string;
    IpAddr: string;
    MacAddr: string;
	PWR_ON: boolean;
    Version: string;      // 사용안함
    Schedule: string;     // 사용안함: Client에 Schedule이 적용됐는지 여부
    CheckBox: TCheckBox;  // ServerForm1에서만 사용
    li: TListItem;        // ServerForm2에서만 사용
    Bar: TProgressBar;    // ServerForm2에서만 사용
    constructor Create (AOwner: TComponent; Mode: integer);
    destructor Destroy; override;
    procedure SetDisConnected;
    procedure SendText (msg: string);
    procedure SendTextIfChecked (msg: string);
    procedure SendTextIfSelected (msg: string);
    procedure InitTotalSize;
    procedure ProgressTotalSent (DocSize, DataSent: Int64);
  published
    property Connected: boolean read GetConnected;
    property Selected: boolean read GetSelected;
    property TotalSize: int64 read FTotalSize write SetTotalSize;
    property Socket: TCustomWinSocket read FSocket write SetSocket;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
  end;


implementation


// ----------------------------------------------------------------
// 여기서부터 Server용 TClient 구현함수
// ----------------------------------------------------------------
constructor TClient.Create (AOwner: TComponent; Mode: integer);
begin
    inherited Create;

    // 명령어 초기화, MAC 요청
    Group:= 0;
    Number:= 0;
    Name:= '';
    IpAddr:= '0.0.0.0';
    MacAddr:= '000000000000';
	PWR_ON:= false;
    Version:= '';
    Schedule:= '';
    FTotalSize:= 1;
    FTotalSent:= 0;
    FTotalSending:= 0;
    Socket:= nil;
    li:= nil;
    CheckBox:= nil;

    // ServerForm1 에서 사용: CheckBox로 관리
    if (Mode = 1) then begin
        CheckBox:= TCheckBox.Create (AOwner);
        CheckBox.Parent:= TWinControl (AOwner);
        CheckBox.SendToBack;
        CheckBox.Font.Color:= clGray;
    end
    // ServerForm2 에서 사용: ListView로 관리
    else if (Mode = 2) then begin
        Bar:= TProgressBar.Create (AOwner);
        Bar.Smooth:= true;
        Bar.Parent:= TWinControl (AOwner);
        Bar.Left:= 394;
        Bar.Width:= 96;
        Bar.Height:= 12;
        Bar.Brush.Color:= $E7E7E7;
    end;
end;

destructor TClient.Destroy;
begin
    CheckBox.Free;
    Bar.Free;
    inherited Destroy;
end;

procedure TClient.TriggerMemoOut(msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

function TClient.GetConnected: boolean;
begin
    if (Socket=nil) then Result:= false
    else Result:= Socket.Connected;
    // 위의 문구만으로는 가끔씩 오류도 발생하여, 아래 문구로 더욱 확실히 Check함
    // if (CheckBox.Font.Color = clGray) then Result:= false;
end;

function TClient.GetSelected: boolean;
begin
    Result:= (li <> nil) and li.Selected;
end;

procedure TClient.SetSocket (Value: TCustomWinSocket);
begin
    FSocket:= Value;
    // 연결이 끊어졌을때 아래 함수로 진입하도록 유도
    if (FSocket <> nil) then
    FSocket.OnErrorEvent:= Socket1Error;
end;

procedure TClient.Socket1Error (Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
    // 더이상 오류가 발생하지 않도록 초기화
    ErrorCode:= 0;

    // 연결이 종료된 경우 해당소켓의 처리.
    // 그런데 이게 어떤때는 동작하는데 어떤때는 연결 종료되어도 여기 들어오지도 않는다.
    // 따라서 이것만 믿고 처리해서는 안됨.
    if (ErrorEvent = eeDisconnect) then begin
        // CheckBox.Font.Color:= clGray;            // 회색으로 보여준다
        Socket.Disconnect (Socket.SocketHandle);    // 확실히 끊어준다
    end;
end;

procedure TClient.SetDisConnected;
begin
    // 연결이 끊어지면 오류방지를 위해 관련 Field를 모두 초기화한다
	PWR_ON:= false;
    Socket:= nil;
    // 전송률 삭제, 운영상태 삭제
    InitTotalSize;
    if (li <> nil) then li.SubItems[1]:= '';
end;

procedure TClient.SendText (msg: string);
begin
    if Connected then
    Socket.SendText (msg);
end;

procedure TClient.SendTextIfChecked (msg: string);
begin
    if (CheckBox <> nil) then
    if CheckBox.Checked then
    if Connected then
    Socket.SendText (msg);
end;

procedure TClient.SendTextIfSelected (msg: string);
begin
    if (li <> nil) then
    if li.Checked then
    if Connected then
    Socket.SendText (msg);
end;




// ----------------------------------------------------------------
// 여기서부터 전송률 구현함수
// ----------------------------------------------------------------

procedure TClient.InitTotalSize;
begin
    // 총용량 및 보낸용량 0으로
    FTotalSize:= 1;
    FTotalSent:= 0;

    if (Bar <> nil) then begin
        Bar.Max:= 1;
        Bar.Position:= 0;
    end;
    if (li <> nil) then begin
        li.SubItems[2]:= '0%';
    end;
end;

procedure TClient.SetTotalSize (Value: int64);
begin
    // 0으로 나눌수 없으므로 1로 해준다
    if (Value <= 0) then Value:= 1;
    FTotalSize := Value;
    
    // ProgressBar는 int64 안되므로 2GB 이상 못보여준다
    // 이를 해결하기 위해 TotalSize가 2GB 넘으면 div 1024 하여 처리한다
    if (Bar <> nil) then
        if (FTotalSize <= 2147483645) then Bar.Max:= Value
        else Bar.Max:= Value div 1024;
end;

procedure TClient.ProgressTotalSent (DocSize, DataSent: Int64);
var
    s: string;
begin
    // DataSent는 1개파일 전송한 누적용량이 나오므로 TotalSent(이전파일까지의 총용량)에서 더해준다
    FTotalSending:= FTotalSent + DataSent;
    // 파일 1개를 전송완료한 시점에서 TotalSent(총용량)을 올려준다
    if (DataSent = DocSize) then FTotalSent:= FTotalSending;

    // 100%가 넘으면 100%로 맞춰준다
    if (FTotalSending > FTotalSize) then FTotalSending:= FTotalSize;
    if (FTotalSent > FTotalSize) then FTotalSent:= FTotalSize;

    // 숫자%로 전송률 표시
    if (li <> nil) then begin
        s:= inttostr(floor(FTotalSending/FTotalSize*100)) + '%';
        if (li.SubItems[2] <> s) then li.SubItems[2]:= s;
    end;

    // ProgressBar로 전송률 표시
    if (Bar <> nil) then
        if (FTotalSize <= 2147483645) then Bar.Position:= FTotalSending
        else Bar.Position:= FTotalSending div 1024;

    {IFOPT D+
    TriggerMemoOut (
    Format('Num=%d, DocSize=%d, DataSend=%d, TotalSize=%d, TotalSent=%d, TotalSending=%d, Rate=%s, ProgPos=%d, ProgMax=%d',
      [Number, DocSize, DataSent, FTotalSize, FTotalSent, FTotalSending, s, Bar.Position, Bar.Max]));
    ENDIF}
end;

end.

