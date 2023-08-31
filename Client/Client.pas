unit Client;

interface

uses
  Windows, SysUtils, ExtCtrls, Classes, ScktComp, HttpGet,
  Xdir, BlankUtils, FileList, Globals;

const
  // TAutoConnect���� ����
  MAX_COUNTER = 15;	// FCounter�� 0..14�� ����ؼ� ����
  MAX_TIMEOUT = 6;	// 6�ʾȿ� �����κ��� ��������� ����ó��

type
  TCommandEvent = procedure (cmd: String) of object;
  TDoneFileEvent = procedure (cmd, FileName: string) of object;

  // Server�κ��� �������� ������ �Ѳ����� Download�ϴ� Class
  TGetFilesClient = class
  private
    position: integer;
    State: (Idle, Busy);
    FServer: string;
    FNumber: string;
    FListFile: string;
    FTimer: TTimer;
    FSimpleList: TStringList;   // ���ϸ� �ִ� List�� (AdditionalFileName, ScheduleFileName)
    FAlbumList: TFileList;      // �ٿ�޾ƾ� �� ���ϸ��, Server���� ���� ListFile�� �о���δ�
    FCurList: TFileList;        // ���� ���ϸ��, Folder�� ������ ���� �ۼ��� List
    FHttpGet: THttpGet;
    procedure TriggerMemoOut (msg: string);
    procedure Timer1Timer (Sender: TObject);
    procedure HttpGet1DoneFile (Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet1Error (Sender: TObject);
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnFilesDone: TNotifyEvent;
    procedure SetPort (Value: string);
    procedure SetListFile (const Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    function PrepareDownload: int64;
    procedure Run;
    procedure Stop;
  published
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnFilesDone: TNotifyEvent read FOnFilesDone write FOnFilesDone;
    property Server: string read FServer write FServer;
    property Number: string read FNumber write FNumber;
    property Port: string write SetPort;
    property ListFile: string read FListFile write SetListFile;
  end;

  // Server���� ������ ��� Ȯ���� �ִ� Class
  TAutoConnect = class
  private
    FTimeOut: integer;
    FCounter: integer;
    acTimer: TTimer;
    procedure TriggerMemoOut (msg: string);
    procedure acTimerTimer(Sender: TObject);
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnHello: TNotifyEvent;
    FOnClose: TNotifyEvent;
    FOnCheck: TNotifyEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure FillAliveFull;
    procedure TryConnectSoon;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnHello: TNotifyEvent read FOnHello write FOnHello;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnCheck: TNotifyEvent read FOnCheck write FOnCheck;
  end;

  // Server�� �⺻���� ����� �ϴ� Class
  TClient = class
  private
    FServer: string;		// ������ ����
    FServerPort: integer;   // Socket Port (51111)
    FHttpPort: string;		// HttpGet ��Ʈ (8001)
    FNumber: string;		// Client ������ȣ(ID)
    FMacAddr: string;		// ����ǻ���� Mac Address
    FCommand: string;		// Server�κ��� ���� ��ɾ�
    FAlbumState: string;    // Album�� �����
    Client1: TClientSocket;	// Server�κ��� ����� �޴� Socket
    HttpGets: array[1..5] of THttpGet;
    GetFilesClient: TGetFilesClient;	// ���ϵ� �޴� Class
    FAutoConnect: TAutoConnect;         // �ڵ� ������ Class
    procedure AutoConnectHello (Sender: TObject);
    procedure AutoConnectClose (Sender: TObject);
    procedure AutoConnectCheck (Sender: TObject);
    procedure Client1Connect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client1Disconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client1Error(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure Client1Read(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client1ProcessCommand (cmd: string; Socket: TCustomWinSocket); virtual;
    procedure HttpGet1Error(Sender: TObject);
    procedure HttpGet1DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet2DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet3DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure HttpGet4DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
    procedure GetFilesDone (Sender: TObject);
    procedure SendTotalSizeToServer (TotalSize: int64);
  protected
    FOnMemoOut: TMemoOutEvent;
    FOnCommand: TCommandEvent;
    FOnDoneFile: TDoneFileEvent;
    procedure TriggerMemoOut (msg: string);
    procedure TriggerCommand (cmd: string);
    procedure TriggerDoneFile (cmd, FileName: string);
    procedure SetServer (Value: string);
    procedure SetServerPort (Value: integer);
    procedure SetHttpPort (Value: string);
    procedure SetNumber (Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure SendTextToServer (msg: string);
  published
    property Server: string read FServer write SetServer;
    property ServerPort: integer read FServerPort write SetServerPort;
    property HttpPort: string read FHttpPort write SetHttpPort;
    property Number: string read FNumber write SetNumber;
    property AlbumState: string read FAlbumState write FAlbumState;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnCommand: TCommandEvent read FOnCommand write FOnCommand;
    property OnDoneFile: TDoneFileEvent read FOnDoneFile write FOnDoneFile;
  end;


implementation



// ----------------------------------------------------------------
// ���⼭���� TGetFilesClient �Լ� ����
// ----------------------------------------------------------------
constructor TGetFilesClient.Create;
begin
    inherited Create;
    FServer:= '';
    FNumber:= '';
    FListFile:= '';

    // ����ؼ� ����� ������ Main Scheduler ���
    FTimer:= TTimer.Create (nil);
    FTimer.Interval:= 200;
    FTimer.OnTimer:= Timer1Timer;
    FTimer.Enabled:= false;

    // �ٿ�ε� �޾ƾ��� ���ϸ��, �������ϸ��
    FSimpleList:= TStringList.Create;
    FAlbumList:= TFileList.Create;
    FCurList:= TFileList.Create;

    // �ٿ�ε忡 Ȱ���� HttpGet
    // �Ʒ��� ���� BinaryData:= True�� �ؾ� �������� ���� �����̰ų� ������ ������ ������ ����� �߻��Ѵ�
    // �Ʒ��� False�� �ϸ� �������� ���� ������ �� ���� �߻����� 0����Ʈ ���� ������ �Ѿ ������
    FHttpGet:= THttpGet.Create (nil);
    FHttpGet.BinaryData:= True;
    FHttpGet.Port:= '8001';
    FHttpGet.OnDoneFile:= HttpGet1DoneFile;
    FHttpGet.OnError:= HttpGet1Error;
end;

destructor TGetFilesClient.Destroy;
begin
    FTimer.Free;
    FSimpleList.Free;
    FAlbumList.Free;
    FCurList.Free;
    FHttpGet.Free;
    inherited Destroy;
end;

procedure TGetFilesClient.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;


procedure TGetFilesClient.SetPort (Value: string);
begin
    FHttpGet.Port:= Value;
end;

procedure TGetFilesClient.SetListFile (const Value: string);
var
    i: integer;
    fname: string;
begin
    FListFile:= Value;  // ������

    // ListFile �κ��� ������ �о�´�
    FAlbumList.Clear;
    if (FileExists(FListFile)) then
    try
        fname:= ExtractFileName(FListFile);
        // SEND_ALBUM => TFileList�� ����
        if (fname=AlbumFileName)
            then FAlbumList.LoadFromFile (FListFile) else
        // SEND_ADDFILE, SEND_SCHEDULE => TStringList�� ����
        if (fname=AdditionalFileName) or (fname=ScheduleFileName)
            then FAlbumList.LoadFromSimple (FListFile);
        TriggerMemoOut ('LoadFromSimple �Ϸ�, Count = ' + inttostr(FAlbumList.Count));
    except
        TriggerMemoOut ('LoadFromFile or Simple ���� ��������');
        FAlbumList.Clear;
    end;

    // �������� �ۼ��� ���ϸ���� �ѹ��� ����� �ش�
    {$IFOPT D+}
    TriggerMemoOut ('--- �����κ��� ���� ���ϸ�� ---');
    for i:= 1 to FAlbumList.Count do begin
        TriggerMemoOut (ExtractFileName (FAlbumList.FileNames[i-1]));
    end;
    TriggerMemoOut (' ');
    {$ENDIF}
end;


function TGetFilesClient.PrepareDownload: int64;
var
    i, j: integer;
    Xdir1: TXdir;
begin
    // ------------ �ٿ�ε� �غ� ---------------
    // ������ ��¥�� ũ�Ⱑ ���� �͵��� �ٽù��� �ʴ´�
    // ������ �ʿ䰡 ���� ���ϵ��� ���� ���������� �޴´�
    // Return: ������ �޾ƾ� �� ���ϵ��� ��ũ��
    // ------------------------------------------

    // �������� �ƴ��� �˻��Ѵ�
    Result:= -1;
    if (FAlbumList.Count = 0) then exit;

    // 1) ���� Files ������ ��� ���ϸ���� CurList�� �����´�
    Xdir1:= TXdir.Create (nil);
    Xdir1.StartDir:= FolderName;
    FCurList.Clear;
    while Xdir1.Find do if Xdir1.IsFile then
    if (Xdir1.FileName <> FListFile) then
    FCurList.AddFile (Xdir1.FileName);
    Xdir1.Stop;
    Xdir1.Free;

    // 2) AlbumList�� CurList�� ���Ͽ� ���������̸� Delete
    if (FCurList.Count > 0) then
    for i:= FCurList.Count downto 1 do
    for j:= FAlbumList.Count downto 1 do
    if TFileList.FileItemSame (FCurList[i-1], FAlbumList[j-1]) then
    begin
        FCurList.Delete(i-1);   // ������ ��Ͽ��� ����
        FAlbumList.Delete(j-1); // �ٿ�ε� ���� ��Ͽ��� ����
        break;
    end;

    // 3) CurList�� �����ִ� ���ϵ��� ������ ������ �ش� (�ʿ���� ���ϵ���)
    for i:= 1 to FCurList.Count do
    DeleteFile (FCurList.FileNames[i-1]);

    // 4) FAlbumList�� �����ִ� ���ϵ鸸 ��� �ٿ�ε� ������ �ȴ�
    {$IFOPT D+}
    TriggerMemoOut ('--- �ٿ�޾ƾ� �� ���ϸ�� ---');
    for i:= 1 to FAlbumList.Count do begin
        TriggerMemoOut (ExtractFileName (FAlbumList.FileNames[i-1]));
    end;
    TriggerMemoOut (' ');
    {$ENDIF}

    // 5) �ѿ뷮�� ���ؼ� Return �Ѵ�
    Result:= 0;
    for i:= 1 to FAlbumList.Count do
    Result:= Result + FAlbumList.FileItems[i-1].FileSize;
end;

procedure TGetFilesClient.Run;
begin
    // �̹� �������̸� ����� (if Running then Stop)
    if (State = Busy) then Stop;

    // ���� ���� �˻�
    if (FServer = '') then exit;
    if (FListFile = '') then exit;

    // ù��° ���Ϻ��� �����Ѵ�
    position:= 0;
    // �ٿ�ε带 �����Ѵ�
    FTimer.Enabled:= true;
end;


procedure TGetFilesClient.Stop;
begin
    // ��� �۾��� ��� �����Ѵ�
    FTimer.Enabled:= false;
    FHttpGet.Abort;
    State:= Idle;
end;

procedure TGetFilesClient.Timer1Timer (Sender: TObject);
var
    s: string;
begin
    // Timer �Լ��� �ֱ������� ����Ͽ� ���� �۾��� �����Ѵ�
    // TriggerMemoOut (#13#10'Timer Enabled');

    // �۾����̸� ���⼭ �ϴ� ���������� ����Ѵ�
    if (State = Busy) then exit;

    // �� �޾����� �������� ���ش�
    if (position >= FAlbumList.Count) then begin
        FTimer.Enabled:= false;
        if Assigned (FOnFilesDone) then FOnFilesDone (nil);
        exit;
    end;

    // ���� Pos�� ������ �׸�
    s:= FAlbumList.FileNames[position];

    try
        // ����, �ּ�, *��ɹ� Line�� �ǳʶڴ�
        if (Trim(s)='') then exit;
        if (s[1] in ['/','*','[','(']) then exit;

        // �������� �� �ٺ�~
        State:= Busy;
        TriggerMemoOut (inttostr(position+1)+'��° ���� Down����');

        // �� ������ �ٿ�ε� �޴´�
        FHttpGet.URL:= 'http://'+ FServer + '/getfile.html?num='+FNumber+'&pathname='+s;
        FHttpGet.FileName:= FolderName + ExtractFileName (s);
        FHttpGet.GetFile;
    finally
        // ���� �׸����� �Ѿ��
        position:= position + 1;
    end;
end;

procedure TGetFilesClient.HttpGet1DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
var
    p: PFileItem;
    FileHandle, Age: integer;
begin
    // �ٿ�ε� �Ϸ��ϸ� ����� ����� �ְ� ���� ���Ϸ� �Ѿ���� �س��´�
    TriggerMemoOut ('-�ٿ�ε� �Ϸ�: ' + ExtractFileName(FileName) + ' ('+inttostr3(FileSize)+' Bytes)');

    if (FileSize < 30) then
        // �߸��� ������ ������ ������: 404 Not Found
        DeleteFile (FileName)
    else begin
        // ���� ��¥�� ������ �ش�
        p:= FAlbumList[position-1];
        Age:= p^.DateTime;
        FileHandle:= FileOpen (FileName, fmOpenReadWrite or fmShareDenyNone);
        if (FileSetDate(FileHandle, Age) <> 0) then;
        FileClose (FileHandle);
    end;

    // ���� ������ ���� �� �ֵ��� ���ش�
    FTimer.Interval:= 200;	// ��ٷ� �۾� �����ϼ���. ����ϸ� ���ϰ����� ������ ���� �ɸ���.
    State:= Idle;			// �ڵ����� �ٿ�ε� ��õ� ����Ѵ�. ���� ���Ϸ� �Ѿ�� ����.

    // �� �޾����� �������� ���ش�
    // if (pos >= FList.Count) then begin
    //	FTimer.Enabled:= false;
    //	if Assigned (FOnFilesDone) then FOnFilesDone (nil);
    //	exit;
    // end;
end;

procedure TGetFilesClient.HttpGet1Error(Sender: TObject);
begin
    // ������ ���� �����ð��� ���������� ��õ��Ѵ�
    TriggerMemoOut ('Http Get Error');
    FTimer.Interval:= 5000;	// ���� �ÿ��� 5�ʸ��� ��õ��Ѵ�. ª�� �ϸ� �ʹ� ���ž���.
    State:= Idle;			// �ڵ����� �ٿ�ε� ��õ� ����Ѵ�
end;





// ----------------------------------------------------------------
// ���⼭���� TAutoConnect �Լ� ����
// ----------------------------------------------------------------


constructor TAutoConnect.Create;
begin
    inherited Create;
    FTimeOut:= 0;
    FCounter:= 0;

    // Server�� �ڵ� �������ϴ� ActoConnect Timer
    acTimer:= TTimer.Create (nil);
    acTimer.Enabled:= true;
    acTimer.Interval:= 1000;
    acTimer.OnTimer:= acTimerTimer;
end;

destructor TAutoConnect.Destroy;
begin
    acTimer.Free;
    inherited Destroy;
end;

procedure TAutoConnect.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TAutoConnect.FillAliveFull;
begin
    FTimeOut:= MAX_TIMEOUT + 3;
end;

procedure TAutoConnect.TryConnectSoon;
begin
    // ��� ������ �õ��� �ϵ��� FCounter�� �����Ѵ�
    FTimeOut:= 0;
    FCounter:= 0;
    TriggerMemoOut ('��� ������ �õ��� �մϴ�');
end;

procedure TAutoConnect.acTimerTimer(Sender: TObject);
begin
    // 1�ʿ� �ѹ��� ����� ���´�.
    FCounter:= FCounter + 1;
    if (FCounter >= MAX_COUNTER) then FCounter:= 0;

    // ������ 1�ʿ� 1�� ���ҽ�Ų��
    if (FTimeOut > 0) then FTimeOut:= FTimeOut - 1;

    {$IFOPT D+}
    // TriggerMemoOut (Format('FCounter = %d, FTimeOut = %d', [FCounter, FTimeOut]));
    {$ENDIF}


    // ����Ȯ��: ������ ������ �õ�
    if (FCounter = 2) then begin
        // TriggerMemoOut ('FCounter = 2, ������ ������ �õ�');
        if Assigned(FOnCheck) then FOnCheck (Self);
    end

    // �����: ����Ȯ�ο� Dummy Message ����
    else if (FCounter = 5) then begin
        // TriggerMemoOut ('FCounter = 5, ����Ȯ�ο� Dummy Message ����');
        if Assigned(FOnHello) then FOnHello (Self);
    end

    // MAX_TIMEOUT�� Server�κ��� ������ ���µ� ��� ����� �ɷ� �ν��ϸ� ������ ������Ų��
    else if (FCounter = 5 + MAX_TIMEOUT) then begin
        // TriggerMemoOut ('FCounter = 11, ������ ������ Check');
        if (FTimeOut = 0) then
        if Assigned(FOnClose) then FOnClose (Self);
    end;
end;





// ----------------------------------------------------------------
// ���⼭���� TClient �Լ� ����
// ----------------------------------------------------------------

procedure TClient.SetServer (Value: string);
begin
    if (FServer <> Value) then begin
        FServer:= Value;
        GetFilesClient.Server:= Value;
        // ���������� ��������. �������� Timer�� �˾Ƽ� �Ѵ�
        if (Client1.Active) then Client1.Close;
        Client1.Address:= Value;
    end;
end;

procedure TClient.SetServerPort (Value: integer);
begin
    if (FServerPort <> Value) then begin
        FServerPort:= Value;
        // ���������� Port����. �������� Timer�� �˾Ƽ� �Ѵ�
        if (Client1.Active) then Client1.Close;
        Client1.Port:= Value;
    end;
end;

procedure TClient.SetHttpPort (Value: string);
var
    i: integer;
begin
    FHttpPort:= Value;
    for i:= 1 to 5 do HttpGets[i].Port:= Value;
    GetFilesClient.Port:= Value;
end;

procedure TClient.SetNumber (Value: string);
begin
    if (FNumber <> Value) then begin
        FNumber:= Value;
        GetFilesClient.Number:= Value;
        // ���������� ��������. �������� Timer�� �˾Ƽ� �Ѵ�
        if (Client1.Active) then Client1.Close;
    end;
end;

procedure TClient.TriggerMemoOut (msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TClient.TriggerCommand (cmd: string);
begin
    if Assigned (FOnCommand) then FOnCommand (cmd);
end;

procedure TClient.TriggerDoneFile (cmd, FileName: string);
begin
    if Assigned(FOnDoneFile) then FOnDoneFile (cmd, FileName);
end;



// ----------------------------------------------------------------
// ���⼭���� TClient �ʱ�ȭ �� ������ �Լ�
// ----------------------------------------------------------------

constructor TClient.Create;
var
    i: integer;
begin
    inherited Create;
    FServer:= '127.0.0.1';
    FServerPort:= 51111;
    FHttpPort:= '8001';
    FNumber:= '1';
    FMacAddr:= GetMacAddress;
    FCommand:= '';
    FAlbumState:= '';

    // ��ɾ� �޴� Socket ����
    Client1:= TClientSocket.Create (nil);
    Client1.Address:= FServer;
    Client1.Port:= 51111;
    Client1.OnConnect:= Client1Connect;
    Client1.OnDisconnect:= Client1Disconnect;
    Client1.OnError:= Client1Error;
    Client1.OnRead:= Client1Read;

    // ���� �޴� Socket ����
    for i:= 1 to 5 do begin
        HttpGets[i]:= THttpGet.Create (nil);
        HttpGets[i].Port:= FHttpPort;
        HttpGets[i].BinaryData:= true;
        HttpGets[i].OnError:= HttpGet1Error;
    end;
    HttpGets[1].OnDoneFile := HttpGet1DoneFile;
    HttpGets[2].OnDoneFile := HttpGet2DoneFile;
    HttpGets[3].OnDoneFile := HttpGet3DoneFile;
    HttpGets[4].OnDoneFile := HttpGet4DoneFile;

    // �������� �޴� Client ����
    GetFilesClient:= TGetFilesClient.Create;
    GetFilesClient.Server:= FServer;
    GetFilesClient.Port:= FHttpPort;
    GetFilesClient.Number:= FNumber;
    GetFilesClient.OnMemoOut:= TriggerMemoOut;
    GetFilesClient.OnFilesDone:= GetFilesDone;	// �ΰ����� �ٿ�Ϸ�� �Ұ͵� (��������)

    // Server�� �ڵ� �������ϴ� ActoConnect ���
    FAutoConnect:= TAutoConnect.Create;
    FAutoConnect.OnMemoOut:= TriggerMemoOut;
    FAutoConnect.OnHello:= AutoConnectHello;
    FAutoConnect.OnClose:= AutoConnectClose;
    FAutoConnect.OnCheck:= AutoConnectCheck;
end;

destructor TClient.Destroy;
var
    i: integer;
begin
    FAutoConnect.Free;
    FAutoConnect:= nil; // nil�����ָ� �Ʒ� Client.Close�� �����ӽõ� ����
    GetFilesClient.Free;
    if Client1.Active then Client1.Close;
    Client1.Free;
    for i:= 1 to 5 do HttpGets[i].Free;
    inherited Destroy;
end;





// ----------------------------------------------------------------
// ���⼭���� TClient Socket ���� �Լ�
// ----------------------------------------------------------------

procedure TClient.SendTextToServer (msg: string);
begin
    if Client1.Active then
    Client1.Socket.SendText (msg);
end;


procedure TClient.SendTotalSizeToServer(TotalSize: int64);
begin
    TriggerMemoOut ('�޾ƾ� �� �ѿ뷮�� ' + inttostr(TotalSize) + ' Bytes');
    SendTextToServer ('TotalSize='+inttostr(TotalSize));
end;


procedure TClient.AutoConnectHello (Sender: TObject);
begin
    if Client1.Active then begin
        TriggerMemoOut ('������: ����Ȯ�ο� HellO ����');
        Client1.Socket.SendText ('HellO');
    end
end;

procedure TClient.AutoConnectClose (Sender: TObject);
begin
    // Socket�� Close�϶�. ���������� ������ ������ ������ ��
    if Client1.Active then Client1.Close;
end;

procedure TClient.AutoConnectCheck (Sender: TObject);
begin
    if not Client1.Active then
    try
        TriggerMemoOut ('������: Server�� ������ �õ�');
        Client1.Open;
    except
        TriggerMemoOut ('Try Exception: Server�� ������ �� ����');
    end;
end;

procedure TClient.Client1Connect(Sender: TObject; Socket: TCustomWinSocket);
begin
    TriggerMemoOut ('Server�� ����Ǿ����ϴ�.');
    if (FAutoConnect <> nil) then FAutoConnect.FillAliveFull;
    Socket.SendText ('num='+FNumber+'&mac='+FMacAddr+'&album='+FAlbumState+'&');
    TriggerMemoOut ('����: num='+FNumber+'&mac='+FMacAddr+'&album='+FAlbumState+'&');
end;

procedure TClient.Client1Disconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
    TriggerMemoOut ('Server�� ������ �����Ǿ����ϴ�.');
    if (FAutoConnect <> nil) then   // Destroy���� Free�� ���ü� �����ϱ� nil���� Ȯ��
    FAutoConnect.TryConnectSoon;	// ������ ����. ���� ���ӽõ�
end;

procedure TClient.Client1Error(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
    ErrorCode:= 0;		// ���̻� Exception�� �߻����� �ʰ� �Ѵ�
    TriggerMemoOut ('Server�� ������ �� �����ϴ�.');
    try Client1.Close; except end;
    // if (FAutoConnect <> nil) then FAutoConnect.TryConnectSoon;
end;

// Server�κ��� ���� �޾Ҵ�
procedure TClient.Client1Read(Sender: TObject; Socket: TCustomWinSocket);
var
    cmd: string;
begin
    // Server�κ��� ���� �޾Ҵ�
    if (FAutoConnect <> nil) then FAutoConnect.FillAliveFull;
    cmd:= Socket.ReceiveText;

    // ���� �����޼����� ������ �����Ѵ�
    if (length(cmd) < 4) or (length(cmd) > 20) then exit;
    TriggerMemoOut ('��ɼ���: ' + cmd);
    // GooD�� �����Ѵ�. �ȱ׷��� cmd=GooD�� GetFilesDone���� ���޵Ǿ� Album ������ �ȵȴ�.
    if (cmd='GooD') then exit;

    // ��ɾ ó���Ѵ�
    FCommand:= cmd;
    // �ٿ�ε� ���̸� �����Ѵ�
    GetFilesClient.Stop;
    // MainForm �ʿ��� ��ó�� ���ش�
    TriggerCommand (cmd);
    // ��ɾ �ϳ��� ó���Ѵ�
    Client1ProcessCommand (cmd, Socket);
end;

// Server�κ��� ���� ��ɾ ó���Ѵ�
procedure TClient.Client1ProcessCommand (cmd: string; Socket: TCustomWinSocket);
begin
    // Server���� ���� Mac Address�� ��û => �ٷ� �뺸�� �ش�
    if (cmd = 'YOUR_MAC') then begin
        Socket.SendText ('num='+FNumber+'&mac='+FMacAddr+'&');
        TriggerMemoOut ('����: num='+FNumber+'&mac='+FMacAddr+'&');
    end else

    // PPT ������ �����´�
    if (cmd = 'SEND_PPT') then begin
        HttpGets[1].Abort;
        HttpGets[1].URL:= 'http://'+FServer+'/ppt.html?num='+FNumber;
        HttpGets[1].FileName:= FolderName+'Screen_t.ppt';
        HttpGets[1].GetFile;
    end else

    // PPTX ������ �����´�
    if (cmd = 'SEND_PPTX') then begin
        HttpGets[1].Abort;
        HttpGets[1].URL:= 'http://'+FServer+'/ppt.html?num='+FNumber;
        HttpGets[1].FileName:= FolderName+'Screen_t.pptx';
        HttpGets[1].GetFile;
    end else

    // �߰����ϵ� �����´�
    if (cmd = 'SEND_ADDLIST') then begin
        // List �ٿ�ް� ������ �����Ѵ�
        HttpGets[2].Abort;
        HttpGets[2].URL:= 'http://' + FServer + '/addlist.html?num='+FNumber;
        HttpGets[2].FileName:= FolderName+AdditionalFileName;
        HttpGets[2].GetFile;
    end else

    // ������ �� �������ϵ� �����´�
    if (cmd = 'SEND_SCHEDULE') then begin
        // List �ٿ�ް� ������ �����Ѵ�
        HttpGets[3].Abort;
        HttpGets[3].URL:= 'http://' + FServer + '/schedule.html?num='+FNumber;
        HttpGets[3].FileName:= FolderName+ScheduleFileName;
        HttpGets[3].GetFile;
    end else

    // �����ٹ� �����´�
    if (cmd = 'SEND_ALBUM') then begin
        // List �ٿ�ް� ������ �����Ѵ�
        HttpGets[4].Abort;
        HttpGets[4].URL:= 'http://' + FServer + '/albumlist.html?num='+FNumber;
        HttpGets[4].FileName:= FolderName+AlbumFileName;
        HttpGets[4].GetFile;
    end
end;




// ----------------------------------------------------------------
// ���⼭���� TClient HttpGet ���� �Լ�
// ----------------------------------------------------------------

procedure TClient.HttpGet1Error(Sender: TObject);
begin
    TriggerMemoOut ('Http ����ȵ�');
end;


procedure TClient.HttpGet1DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
var
    ext: string;
begin
    // PPT ������ �ٿ�ε� �޾Ҵ�. PPT Viewer ���α׷��� ������ �ش�
    TriggerMemoOut ('Http Get �Ϸ�: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // ��ȿ�� �˻�: ������ ���°�� 24B¥�� 404 Not Found ���Ϸ� ����Ǹ�, ������ ������
    if (FileSize < 25) then begin DeleteFile (FileName); exit; end;

    // ���� PPT Viewer ���α׷��� �����Ų��
    while CheckProcess ('PPTVIEW.EXE') do begin
        KillProcess ('PPTVIEW.EXE'); Sleep(500);
    end;

    // ppt���� pptx���� �����Ѵ�
    ext:= LowerCase(ExtractFileExt(FileName));

    // �ٿ�ε���� ������ ���� ���α׷����� ��ü
    try		DeleteFile (FolderName+'Screen1'+ext);
    finally	RenameFile (FolderName+'Screen_t'+ext, FolderName+'Screen1'+ext); end;

    // Server�� ���� �ٹ޾Ҵٰ� �뺸�� �ش�
    HttpGets[5].URL:= 'http://' + FServer + '/complete.html?num='+FNumber;
    HttpGets[5].GetString;

    // PPT Viewer ���α׷��� �����Ų��
    TriggerDoneFile (FCommand, 'Screen1'+ext);
end;


procedure TClient.HttpGet2DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
begin
    // SEND_ADDFILE => �߰����� ����Ʈ �ٿ�ε� �Ϸ�
    TriggerMemoOut ('Http Get �Ϸ�: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // �ϳ��� �����´�. �ٵǸ� OnFilesDone Event �߻�, Owner���� �������
    GetFilesClient.ListFile:= FileName;		// ������
    GetFilesClient.Run;
end;


procedure TClient.HttpGet3DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
begin
    // SEND_SCHEDULE => ���������� ����Ʈ �ٿ�ε� �Ϸ�
    TriggerMemoOut ('Http Get �Ϸ�: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // �ϳ��� �����´�. �ٵǸ� OnFilesDone Event �߻�, Owner���� �������
    GetFilesClient.ListFile:= FileName;		// ������
    GetFilesClient.Run;
end;


procedure TClient.HttpGet4DoneFile(Sender: TObject; FileName: String; FileSize: Integer);
var
    TotalSize: int64;
begin
    // SEND_ALBUM => �ٹ����� ����Ʈ �ٿ�ε� �Ϸ�
    TriggerMemoOut ('Http Get �Ϸ�: FileName = ' + FileName + ', FileSize = ' + inttostr(FileSize));

    // �ϳ��� �����´�. �ٵǸ� OnFilesDone Event �߻�, Owner���� �������
    GetFilesClient.ListFile:= FileName;		// ������
    TotalSize:= GetFilesClient.PrepareDownload;

    // �޾ƾ��� �ѿ뷮: -1�̸� �������, 0 �̻��̸� ����
    if (TotalSize >= 0) then begin
        // ������ TotalSize �˷��ְ�, �ޱ� �����Ѵ�
        SendTotalSizeToServer (TotalSize);
        GetFilesClient.Run;
    end;
end;


procedure TClient.GetFilesDone (Sender: TObject);
begin
    // ������ ��� �ٿ�ε� �޾Ҵ�.
    TriggerMemoOut ('--GetFilesDone: ������ ��� �޾ҽ��ϴ�.');

    // Server�� ���� �ٹ޾Ҵٰ� �뺸�� �ش�
    HttpGets[5].URL:= 'http://' + FServer + '/complete.html?num='+FNumber;
    HttpGets[5].GetString;

    TriggerMemoOut ('--TriggerDoneFile ȣ��: ' + FCommand + ', ' + ExtractFileName(GetFilesClient.ListFile));
    TriggerDoneFile (FCommand, ExtractFileName(GetFilesClient.ListFile));
end;

end.

