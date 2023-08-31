unit Client;

interface

uses
  Windows, SysUtils, Classes, StdCtrls, ComCtrls, ScktComp,
  Controls, Graphics, Globals, BlankUtils, Math;

type
  // Server ���α׷��� TClient: Server�� ���ӵ� �� Client ��ü��
  // ���� Server ���α׷����� array[1..MAX_CLIENTS] of XXX�� ���� ����� ���� 1�� Class�� ����
  TClient = class
  private
    FTotalSize: int64;      // ������ �� �ѿ뷮
    FTotalSent: int64;      // ���� ���� �ѿ뷮
    FTotalSending: int64;   // ���� 1���� ������ ���� TotalSent
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
    Group: integer;       // ������
    Number: integer;
    Name: string;
    IpAddr: string;
    MacAddr: string;
	PWR_ON: boolean;
    Version: string;      // ������
    Schedule: string;     // ������: Client�� Schedule�� ����ƴ��� ����
    CheckBox: TCheckBox;  // ServerForm1������ ���
    li: TListItem;        // ServerForm2������ ���
    Bar: TProgressBar;    // ServerForm2������ ���
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
// ���⼭���� Server�� TClient �����Լ�
// ----------------------------------------------------------------
constructor TClient.Create (AOwner: TComponent; Mode: integer);
begin
    inherited Create;

    // ��ɾ� �ʱ�ȭ, MAC ��û
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

    // ServerForm1 ���� ���: CheckBox�� ����
    if (Mode = 1) then begin
        CheckBox:= TCheckBox.Create (AOwner);
        CheckBox.Parent:= TWinControl (AOwner);
        CheckBox.SendToBack;
        CheckBox.Font.Color:= clGray;
    end
    // ServerForm2 ���� ���: ListView�� ����
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
    // ���� ���������δ� ������ ������ �߻��Ͽ�, �Ʒ� ������ ���� Ȯ���� Check��
    // if (CheckBox.Font.Color = clGray) then Result:= false;
end;

function TClient.GetSelected: boolean;
begin
    Result:= (li <> nil) and li.Selected;
end;

procedure TClient.SetSocket (Value: TCustomWinSocket);
begin
    FSocket:= Value;
    // ������ ���������� �Ʒ� �Լ��� �����ϵ��� ����
    if (FSocket <> nil) then
    FSocket.OnErrorEvent:= Socket1Error;
end;

procedure TClient.Socket1Error (Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
    // ���̻� ������ �߻����� �ʵ��� �ʱ�ȭ
    ErrorCode:= 0;

    // ������ ����� ��� �ش������ ó��.
    // �׷��� �̰� ����� �����ϴµ� ����� ���� ����Ǿ ���� �������� �ʴ´�.
    // ���� �̰͸� �ϰ� ó���ؼ��� �ȵ�.
    if (ErrorEvent = eeDisconnect) then begin
        // CheckBox.Font.Color:= clGray;            // ȸ������ �����ش�
        Socket.Disconnect (Socket.SocketHandle);    // Ȯ���� �����ش�
    end;
end;

procedure TClient.SetDisConnected;
begin
    // ������ �������� ���������� ���� ���� Field�� ��� �ʱ�ȭ�Ѵ�
	PWR_ON:= false;
    Socket:= nil;
    // ���۷� ����, ����� ����
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
// ���⼭���� ���۷� �����Լ�
// ----------------------------------------------------------------

procedure TClient.InitTotalSize;
begin
    // �ѿ뷮 �� �����뷮 0����
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
    // 0���� ������ �����Ƿ� 1�� ���ش�
    if (Value <= 0) then Value:= 1;
    FTotalSize := Value;
    
    // ProgressBar�� int64 �ȵǹǷ� 2GB �̻� �������ش�
    // �̸� �ذ��ϱ� ���� TotalSize�� 2GB ������ div 1024 �Ͽ� ó���Ѵ�
    if (Bar <> nil) then
        if (FTotalSize <= 2147483645) then Bar.Max:= Value
        else Bar.Max:= Value div 1024;
end;

procedure TClient.ProgressTotalSent (DocSize, DataSent: Int64);
var
    s: string;
begin
    // DataSent�� 1������ ������ �����뷮�� �����Ƿ� TotalSent(�������ϱ����� �ѿ뷮)���� �����ش�
    FTotalSending:= FTotalSent + DataSent;
    // ���� 1���� ���ۿϷ��� �������� TotalSent(�ѿ뷮)�� �÷��ش�
    if (DataSent = DocSize) then FTotalSent:= FTotalSending;

    // 100%�� ������ 100%�� �����ش�
    if (FTotalSending > FTotalSize) then FTotalSending:= FTotalSize;
    if (FTotalSent > FTotalSize) then FTotalSent:= FTotalSize;

    // ����%�� ���۷� ǥ��
    if (li <> nil) then begin
        s:= inttostr(floor(FTotalSending/FTotalSize*100)) + '%';
        if (li.SubItems[2] <> s) then li.SubItems[2]:= s;
    end;

    // ProgressBar�� ���۷� ǥ��
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

