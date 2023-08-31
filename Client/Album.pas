unit Album;

interface

uses
  Windows, SysUtils, StdCtrls, ExtCtrls, Classes, Forms, OleCtrls, WMPLib_TLB,
  ShellApi, Jpeg, Xdir, BlankUtils, Globals, FileList, ScheduleManager;

type
  // �ƹ� �������� ������ ȭ��ǥ�ÿ� �ΰ�� ǥ��
  TLogoPlayer = class
  private
    FlogoLabel: TLabel;
    FWidth, FHeight: integer;
    FTimer: TTimer;
    procedure FTimerTimer(Sender: TObject);
  protected
    procedure RunLogoLabel; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Logo: TLabel read FLogoLabel write FlogoLabel;
    property Width: integer read FWidth write FWidth;
    property Height: integer read FHeight write FHeight;
  end;


  // PPT ����� �����ϴ� class
  TPptPlayer = class
  private
    FpptvPath: string;       // PowerPoint Viewer ���������� �ִ� ����
    FHandle: THandle;        // PPT ��������� �ϴ� Viewer ���α׷��� Handle
    function GetRunning: boolean;
    procedure KillViewer;
  protected
    FOnMemoOut: TMemoOutEvent;
    procedure TriggerMemoOut (msg: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run (FileName: string);
    procedure RunFiles;
    procedure Stop;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property Running: boolean read GetRunning;
  end;


  // ���� ��ϰ��а��: PPT�� �Ϻ��� �����ٸ�
  TPptScheduler = class
  private
    FOldDate: string;
    FPptPlayer: TPptPlayer;
    FTimer: TTimer;
    function GetRunning: boolean;
    procedure FTimerTimer(Sender: TObject);
    procedure RunPptSchedule;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Player: TPptPlayer read FPptPlayer write FPptPlayer;
    property Running: boolean read GetRunning;
  end;


  // MagicInfo ����� �����ϴ� class
  TMagicInfoPlayer = class
  private
    FUseMagicInfo: string;
    function GetRunning: boolean;
  public
    procedure Run (cmd: string);
    procedure Stop;
    property Running: boolean read GetRunning;
    property UseMagicInfo: string read FUseMagicInfo write FUseMagicInfo;
  end;


  // �ٹ���� Main Class
  TAlbum = class
  private
    Fstate: TFileKind;              // ���� ����ǰ� �ִ� �̵�� ����
    FImage: TImage;                 // ���⿡ �̹����� ����Ѵ�
    FWMP: TWindowsMediaPlayer;      // ���⿡ �������� ����Ѵ�
    FjpgTime: integer;              // �̹����� ���ʸ��� �ѱ� ���ΰ�
    FpptTime: integer;              // PPT ������ �󸶵��� ����� ���ΰ�
    Fsec: integer;                  // Timer�Լ� ���Խ� 1�� ����
    FTimer: TTimer;                 // Run �Լ� ����� FTimer�� Enable��
    FIndex: integer;                // FFileList[FIndex]�� ���
    FFileList: TFileList;           // ���ϸ���Ʈ
    Xdir1: TXdir;                   // PlayList �������� Xdir Ȱ��
    logoPlayer: TLogoPlayer;
    pptPlayer: TPptPlayer;
    pptScheduler: TPptScheduler;
    miPlayer: TMagicInfoPlayer;
    scManager: TScheduleManager;
    function GetLogo: TLabel;
    procedure SetLogo(const Value: TLabel);
    function GetMagicInfo: string;
    procedure SetMagicInfo(const Value: string);
    procedure SetContentsFolder (Value: string);
    procedure TriggerMemoOut (msg: string);
    procedure TriggerAlbumState (AState: string; ARunning: boolean);
    procedure GetNextFile (var AFileItem: TFileItem);
    procedure StopMovie;
    procedure RunAlbumList (Sender: TObject); // FTimer�� Enable��Ŵ
    procedure Timer1Timer (Sender: TObject);
  protected
    FOnMemoOut: TMemoOutEvent;      // �޸��� � ����� �޼��� ���
    FOnAlbumState: TMemoOutEvent;   // ������ �����ߴ��� ����¸� MainForm���� �˸���
    FOnImageFile: TMemoOutEvent;    // ȭ�� �ϴܿ� �̹������� �̸� ���
  public
    constructor Create;
    destructor Destroy; override;
    procedure InitialLaunch;        // ���α׷� ó�� ����� ������ �ʵ�����
    procedure Continue;             // FTimer�� Enable��Ų��. ������� avi�� Play��
    procedure Pause;                // FTimer�� Disable��Ų��. ������� img�� ����, avi�� Pause��
    procedure Stop (cmd: string);   // ��� ����� ���߰� ���� ȭ���� ǥ���Ѵ�.
    procedure RunPpt (FileName: string);    // Screen1.ppt �Ǵ� Screen1.pptx ����
    procedure StopPpt;
    procedure RunPptFiles;          // SEND_ADDLIST List ����
    procedure RunPptSchedule;       // SEND_SCHEDULE List ����
    procedure RunMagicInfo (cmd: string);   // MagicInfo Pro �Ǵ� Premium ����
    procedure StopMagicInfo;        // MagicInfo ����
    procedure RunAlbum;             // SEND_ALBUM List ����, AlbumList �о�鿩 ������ ���� �������
    procedure PlayNextFile;         // ���� ������ ����Ѵ� (PlayList �Ǵ� Xdir)
  published
    property Logo: TLabel read GetLogo write SetLogo;
    property Image: TImage read FImage write FImage;
    property WMPlayer: TWindowsMediaPlayer read FWMP write FWMP;
    property MagicInfo: string read GetMagicInfo write SetMagicInfo;
    property OnMemoOut: TMemoOutEvent read FOnMemoOut write FOnMemoOut;
    property OnAlbumState: TMemoOutEvent read FOnAlbumState write FOnAlbumState;
    property OnImageFile: TMemoOutEvent read FOnImageFile write FOnImageFile;
  end;


implementation


// ----------------------------------------------------------------
// ���⼭���� TLogoPlayer �����Լ�
// ----------------------------------------------------------------

constructor TLogoPlayer.Create;
begin
    inherited Create;
    FlogoLabel:= nil;
    FWidth:= Screen.Width;
    FHeight:= Screen.Height;
    Randomize;

    FTimer:= TTimer.Create (nil);
    FTimer.Enabled:= true;
    FTimer.Interval:= 60000;
    FTimer.OnTimer:= FTimerTimer;
end;


destructor TLogoPlayer.Destroy;
begin
    FTimer.Free;
    inherited Destroy;
end;


procedure TLogoPlayer.RunLogoLabel;
begin
    // �����Խ��� �ΰ� ȭ�� ��������� �����ش�
    FlogoLabel.Hide;
    FlogoLabel.Left:= Random (FWidth - FlogoLabel.Width);
    FlogoLabel.Top:= Random (FHeight - FlogoLabel.Height);
    FlogoLabel.Font.Color:= Random ($CCCCCC);
    FlogoLabel.Show;
end;


procedure TLogoPlayer.FTimerTimer(Sender: TObject);
begin
    if (FWidth=0) or (FHeight=0) then exit;
    RunLogoLabel;
end;


procedure TLogoPlayer.Start;
begin
    FLogoLabel.Show;
    FTimer.Enabled:= true;
    // WriteLogFile ('C:\111.txt', 'TLogoPlayer.Start ������');
end;


procedure TLogoPlayer.Stop;
begin
    FTimer.Enabled:= false;
    FLogoLabel.Hide;
    // WriteLogFile ('C:\111.txt', 'TLogoPlayer.Stop ������');
end;




// ----------------------------------------------------------------
// ���⼭���� TPptScheduler �����Լ�
// ----------------------------------------------------------------

constructor TPptScheduler.Create;
begin
    inherited Create;
    ShortDateFormat:= 'yyyy-mm-dd';
    FOldDate:= DateToStr (now);
    FPptPlayer:= nil;

    FTimer:= TTimer.Create (nil);
    FTimer.Enabled:= true;
    FTimer.Interval:= 60000;
    FTimer.OnTimer:= FTimerTimer;
end;


destructor TPptScheduler.Destroy;
begin
    FTimer.Free;
    inherited Destroy;
end;


function TPptScheduler.GetRunning: boolean;
begin
    Result:= FTimer.Enabled;
end;


procedure TPptScheduler.FTimerTimer(Sender: TObject);
var
    CurDate: string;
begin
    // 1�п� �ѹ��� ����� ���� ��¥�� �ٲ������ Check�Ѵ�
    ShortDateFormat:= 'yyyy-mm-dd';
    CurDate:= DateToStr(now);
    if (CurDate = FOldDate) then exit;
    FOldDate:= CurDate;

    // TriggerMemoOut ('��¥�� ����Ǿ���, ������ Check��..');
    RunPptSchedule;
end;


procedure TPptScheduler.Start;
begin
    FTimer.Enabled:= true;
    RunPptSchedule;
end;


procedure TPptScheduler.Stop;
begin
    FTimer.Enabled:= false;
end;


procedure TPptScheduler.RunPptSchedule;
var
    i,j: integer;
    List: TstringList;
    s,t,fn,ext: string;
begin
    // List ������ �����ϴ��� Check
    if (FPptPlayer = nil) then exit;
    if not FileExists (FolderName+ScheduleFileName) then exit;

    // List�� �о���δ�
    List:= TStringList.Create;
    try List.LoadFromFile (FolderName+ScheduleFileName); except end;

    // ���� ��¥�� �� string�� ã�´�
    ShortDateFormat:= 'yyyy-mm-dd';
    s:= '/'+datetostr(now);
    i:= List.IndexOf(s);

    // ���� ��¥�� ������ ���� ��¥�� ã�´�
    if (i<0) then
    for j:= 1 to List.Count do begin
        t:= List[j-1];
        if (t[1] = '/') then
        if (t <= s) then i:= j-1;
    end;

    // �ϴ� ������ PPT�� �����Ѵ�
    FPptPlayer.KillViewer;

    if (i < 0) then begin
        // �������� �̷���¥�� ������ i=-1��, ����Ұ� ����
        // TriggerMemoOut ('���� ��¥�� �ȵǾ� ����� ������ �����ϴ�')
    end
    else begin
        // �ٷ� �����ٿ� �ִ� string�� �����´�
        i:= i + 1;
        if (i < List.Count) then begin
            // ppt ������ ������ ����� �����Ѵ�
            fn:= List[i];
            ext:= LowerCase (ExtractFileExt (fn));
            if (ext='.ppt') or (ext='.pptx')
            then FPptPlayer.Run (ExtractFileName (fn))
        end;
    end;

    List.Free;

    // PPT ���࿩�ο� ���� Logo�� ���̰ų� �����
    // if FpptPlayer.Running then logoPlayer.Stop
    // else logoPlayer.Start;
end;





// ----------------------------------------------------------------
// ���⼭���� TPptPlayer �����Լ�
// ----------------------------------------------------------------

constructor TPptPlayer.Create;
begin
    inherited Create;
    FHandle:= 0;

    // PPT Viewer 2003, 2007, 2010�� ���� �������� ��ΰ� �޶�����
    FpptvPath:= '';
    if FileExists (ProgramFiles+'Microsoft Office\PowerPoint Viewer\PPTVIEW.EXE') then    // 2003
    FpptvPath:=    ProgramFiles+'Microsoft Office\PowerPoint Viewer\' else
    if FileExists (ProgramFiles+'Microsoft Office\Office12\PPTVIEW.EXE') then    // 2007
    FpptvPath:=    ProgramFiles+'Microsoft Office\Office12\' else
    if FileExists (ProgramFiles+'Microsoft Office\Office14\PPTVIEW.EXE') then    // 2010
    FpptvPath:=    ProgramFiles+'Microsoft Office\Office14\';
end;


destructor TPptPlayer.Destroy;
begin
    inherited Destroy;
end;


function TPptPlayer.GetRunning: boolean;
begin
    Result:= CheckProcess ('PPTVIEW.EXE');
    // Result:= (FHandle > 32);    // KillViewer ���� ��������� �߸��Ȱ� ����
end;


procedure TPptPlayer.TriggerMemoOut(msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;


procedure TPptPlayer.Run (FileName: string);
begin
    // ���� PPT Viewer ���α׷��� �����Ų��
    KillViewer;

    // ppt �Ǵ� pptx �߿� 1���� ���ΰ� �����Ѵ�
    if (FileName='Screen1.ppt') then if FileExists (FolderName+'Screen1.pptx') then DeleteFile (FolderName+'Screen1.pptx');
    if (FileName='Screen1.pptx') then if FileExists (FolderName+'Screen1.ppt') then DeleteFile (FolderName+'Screen1.ppt');

    // �� ppt ���Ϸ� ���α׷� �����: �Ʒ�ó�� �ϸ� PPT Viewer ���۽� �ΰ�ȭ�� ���
    // ShellExecute (0, nil, PChar('Screen1.ppt'), nil, nil, SW_NORMAL);

    // �Ʒ��� ���� /S �ɼ��� �ٿ��ָ� �ΰ�ȭ�� ���� PPT�� ���� �ִ�
    if (FpptvPath = '') then TriggerMemoOut ('PPT ��� ���α׷��� ��ġ�Ǿ� ���� �ʽ��ϴ�.')
    else if (not FileExists (FolderName+FileName)) then TriggerMemoOut ('PPT ������ �����ϴ�.')
    else FHandle:= ShellExecute (0, nil, PChar(FpptvPath+'PPTVIEW.EXE'), PChar('/S /F  "' + FolderName+FileName + '"'), nil, SW_NORMAL);
end;


procedure TPptPlayer.RunFiles;
var
    i, c: integer;
    List: TstringList;
    fn, ext: string;
begin
    // List ������ �����ϴ��� Check
    if not FileExists (FolderName+AdditionalFileName) then exit;

    // List�� �о���δ�
    List:= TStringList.Create;

    try
        try
            List.LoadFromFile (FolderName+AdditionalFileName);
        except
            exit;
        end;

        c:= List.Count;
        for i:= 1 to c do begin
            // ppt ������ ������ ����� �����Ѵ�
            ext:= LowerCase (ExtractFileExt (List[i-1]));
            if (ext='.ppt') or (ext='.pptx') then begin
                // ���� PPT Viewer ���α׷��� �����Ų��
                KillViewer;

                // ���� ppt ������ ��ü
                // PPT �Ǵ� PPTX ������ ���Ե� ������ Screen1.ppt(x)�� Rename�� ����� �Ѵ�
                fn:= ExtractFileName (List[i-1]);
                try        DeleteFile (FolderName+'Screen1'+ext);
                finally    RenameFile (FolderName+fn, FolderName+'Screen1'+ext); end;

                // PPT Viewer ���α׷��� �����Ų��
                Run ('Screen1'+ext);
                break;
            end;
        end;
    finally
        List.Free;
    end;
end;


procedure TPptPlayer.Stop;
begin
    KillViewer;
    // ������ PPT ���� ������ ������ �����
    DeleteFile (FolderName+'Screen1.ppt');
    DeleteFile (FolderName+'Screen1.pptx');
end;


procedure TPptPlayer.KillViewer;
begin
    if Running then
    while CheckProcess ('PPTVIEW.EXE') do begin
        KillProcess ('PPTVIEW.EXE'); Sleep(500);
    end;
    FHandle:= 0;
end;





// ----------------------------------------------------------------
// ���⼭���� TMagicInfoPlayer �����Լ�
// ----------------------------------------------------------------

function TMagicInfoPlayer.GetRunning: boolean;
begin
    Result:= CheckProcess ('mnMain.exe') or CheckProcess ('MpWatcher.exe');
end;


procedure TMagicInfoPlayer.Run (cmd: string);
begin
    // ���������� �̹� �������̸� ������
    if Running then exit;
    if (cmd = 'RUN_MIP' ) then UseMagicInfo:= 'Pro';
    if (cmd = 'RUN_MIIP') then UseMagicInfo:= 'Premium';

    // �������� Pro�� ������ �ش�
    if (cmd = 'Pro') or (cmd = 'RUN_MIP') then
    if not CheckProcess ('mnMain.exe') then begin
        ShellExecute (0, nil, PChar(ProgramFiles+'samsung\MagicInfoPro\mnMain.exe'),
        nil, PChar(ProgramFiles+'samsung\MagicInfoPro'), SW_NORMAL);
    end else
    if not CheckProcess ('SignageScheduler.exe') then begin
        ShellExecute (0, nil, PChar(ProgramFiles+'samsung\MagicInfoPro\SignageScheduler.exe'),
        nil, PChar(ProgramFiles+'samsung\MagicInfoPro'), SW_NORMAL);
    end;

    // ��������i Premium�� ������ �ش�
    if (cmd = 'Premium') or (cmd = 'RUN_MIIP') then
    if not CheckProcess ('MpWatcher.exe') then begin
        ShellExecute (0, nil, PChar(ProgramFiles+'MagicInfo Premium\i Player\MpWatcher.exe'),
        nil, PChar(ProgramFiles+'MagicInfo Premium\i Player'), SW_NORMAL);    // v2.0 �ֽŹ���
        ShellExecute (0, nil, PChar(ProgramFiles+'MagicInfo-i Premium\Client\MpWatcher.exe'),
        nil, PChar(ProgramFiles+'MagicInfo-i Premium\Client'), SW_NORMAL);    // v1.0 �������
    end;
end;


procedure TMagicInfoPlayer.Stop;
begin
    // �������� Pro�� �������� �ƴ϶�� ������
    // if (UseMagicInfo = 'nil') then exit;

    // �׷��� User�� ���� �������� ���� �ִ�.
    // ���� Tray���� ����ְ� ESC ���� ����ȭ���� ������ ���� �ִ�.
    // ���� ������� Check���� ������! �����Ų��
    UseMagicInfo:= 'nil';

    // �������� Pro�� �����Ų��
    // if (UseMagicInfo = 'Pro') then ......... ������� Check���� �ʰ� ������ Kill
    if CheckProcess ('mnMain.exe') then begin
        KillProcess ('mnMain.exe');
        KillProcess ('dispticker.exe');
        KillProcess ('SignageScheduler.exe');
        while CheckProcess ('mnMain.exe') do Sleep(500);
        while CheckProcess ('dispticker.exe') do Sleep(500);
        while CheckProcess ('SignageScheduler.exe') do Sleep(500);
    end;

    // ��������i Premium�� �����Ų��
    // if (UseMagicInfo = 'Premium') then ......... ������� Check���� �ʰ� ������ Kill
    if CheckProcess ('MpWatcher.exe') then begin
        KillProcess ('MpWatcher.exe');
        KillProcess ('MpAgent.exe');
        KillProcess ('MpDLAgent.exe');
        KillProcess ('MpTicker.exe');
        KillProcess ('MpPlayer.exe');
        KillProcess ('MpFileTransfer.exe');
        KillProcess ('MpDLFileTransfer.exe');
        KillProcess ('winvnc.exe');
        while CheckProcess ('MpWatcher.exe') do Sleep(500);
        while CheckProcess ('MpAgent.exe') do Sleep(500);
        while CheckProcess ('MpDLAgent.exe') do Sleep(500);
        while CheckProcess ('MpTicke.exe') do Sleep(500);
        while CheckProcess ('MpPlayer.exe') do Sleep(500);
        while CheckProcess ('MpFileTransfer.exe') do Sleep(500);
        while CheckProcess ('MpDLFileTransfer.exe') do Sleep(500);
        while CheckProcess ('winvnc.exe') do Sleep(500);
    end;

    // ���������� ���� PPTVIEW�� ����ǰ� �ִٸ� �����Ų��
    while CheckProcess ('PPTVIEW.EXE') do begin
        KillProcess ('PPTVIEW.EXE'); Sleep(500);
    end;
end;






// ----------------------------------------------------------------------------
// ���⼭���� TAlbum Class
// ----------------------------------------------------------------------------

function TAlbum.GetLogo: TLabel;
begin
    Result:= logoPlayer.Logo;
end;

procedure TAlbum.SetLogo(const Value: TLabel);
begin
    logoPlayer.Logo:= Value;
    logoPlayer.Start;   // ���⼭ �ؾ� �Ѵ�!
end;

function TAlbum.GetMagicInfo: string;
begin
    Result:= miPlayer.UseMagicInfo;
end;

procedure TAlbum.SetMagicInfo(const Value: string);
begin
    miPlayer.UseMagicInfo:= Value;
end;


procedure TAlbum.SetContentsFolder (Value: string);
begin
    if (Value = Xdir1.StartDir) then exit;
    if (Value[length(Value)]<>'\') then Value:= Value + '\';
    Xdir1.Stop; Xdir1.StartDir:= Value;
    Fstate:= non;    // �ٲ� �������� ��� ���� �����ϰ� �Ѵ� (Timer1���� ó��)
end;


procedure TAlbum.TriggerMemoOut(msg: string);
begin
    if Assigned (FOnMemoOut) then FOnMemoOut (msg);
end;

procedure TAlbum.TriggerAlbumState (AState: string; ARunning: boolean);
const
    LastState: string = ' ';
begin
    // LogoPlayer�� PlayNextFile�� �ǳ����� �ϰ� �����Ƿ� ���⼭ �ϸ� �������� �ϰԵ�, ���� �ּ�ó��
    // if ARunning then logoPlayer.Stop else logoPlayer.Start;

    // Network ���ϸ� ���̱� ����, State�� ����Ǿ��� ��쿡�� Server�� �뺸�Ѵ�
    if not ARunning then AState:= '';
    if (AState <> LastState) then begin
        LastState:= AState;
        if Assigned (FOnAlbumState) then FOnAlbumState (AState);
    end;
end;


constructor TAlbum.Create;
begin
    inherited Create;
    Fstate:= non;
    FIndex:= -1;
    FFileList:= TFileList.Create;

    Xdir1:= TXdir.Create (nil);
    Xdir1.Recursive:= true;
    SetContentsFolder (FolderName);

    logoPlayer:= TLogoPlayer.Create;
    // logoPlayer.Start; .....................> ���⼭ �ϸ� ��������!!!
    pptPlayer:= TPptPlayer.Create;
    pptPlayer.OnMemoOut:= TriggerMemoOut;
    pptScheduler:= TPptScheduler.Create;
    pptScheduler.Player:= pptPlayer;
    miPlayer:= TMagicInfoPlayer.Create;
    miPlayer.UseMagicInfo:= 'nil';
    // mp:= TMediaPlayer.Create(nil);
    // mp.Visible:= false;

    // ������ ������ Class ����
    scManager:= TScheduleManager.Create;
    scManager.OnSchedule:= RunAlbumList;
    scManager.OnMemoOut:= TriggerMemoOut;

    // FileList �ϳ��� �����
    FTimer:= TTimer.Create (nil);
    FTimer.Interval:= 1000;
    FTimer.OnTimer:= Timer1Timer;
    FTimer.Enabled:= false;
end;


destructor TAlbum.Destroy;
begin
    FTimer.Free;
    scManager.Free;

    miPlayer.Free;
    pptScheduler.Free;
    pptPlayer.Free;
    logoPlayer.Free;
    
    Xdir1.Free;
    FFileList.Free;
    inherited Destroy;
end;


procedure TAlbum.InitialLaunch;
var
    umi: string;
begin
    umi:= miPlayer.UseMagicInfo;
    // �켱����: MagicInfo > PPT������ > PPT�߰����� > Screen.pptx > AlbumFileList
    if (umi <> 'nil') then RunMagicInfo (umi)
    else if FileExists(FolderName+ScheduleFileName) then RunPptSchedule
    else if FileExists(FolderName+AdditionalFileName) then RunPptFiles
    else if FileExists(FolderName+'Screen1.ppt' ) then RunPpt ('Screen1.ppt' )
    else if FileExists(FolderName+'Screen1.pptx') then RunPpt ('Screen1.pptx')
    else RunAlbum;
end;




// ----------------------------------------------------------------------------
// ���⼭���� PPT �� MagicInfo ��� ���� �Լ�
// ----------------------------------------------------------------------------

procedure TAlbum.Continue;
begin
    FTimer.Enabled:= true;
    if (FState = avi) then FWMP.controls.play;
end;

procedure TAlbum.Pause;
begin
    FTimer.Enabled:= false;
    if (FState = avi) then FWMP.controls.pause;
end;


procedure TAlbum.Stop (cmd: string);
begin
    // Stop All Players
    FTimer.Enabled:= false;
    if (Fstate = avi) then StopMovie;
    FImage.Hide;
    pptPlayer.Stop;
    pptScheduler.Stop;
    miPlayer.Stop;
    logoPlayer.Start;
    Fstate:= non;

    // ������ ������ ������ �����Ѵ�
    // SEND_ALBUM ����� ��� �������� �ǹ����� ����ؼ� ���д�
    if (cmd <> 'SEND_ALBUM') then begin
        Delete_Files (AlbumFileName);
        Delete_Files (AdditionalFileName);
        Delete_Files (ScheduleFileName);
    end;
end;

procedure TAlbum.StopMovie;
begin
    // ������ ������ Hide
    FWMP.close;
    FWMP.Url:= '';
    FWMP.Hide;
end;


procedure TAlbum.RunPpt (FileName: string);
begin
    pptPlayer.Run (FileName);
    TriggerAlbumState ('PPT 1��', pptPlayer.Running);
end;

procedure TAlbum.StopPpt;
begin
    pptPlayer.Stop;
    TriggerAlbumState ('', false);
end;

procedure TAlbum.RunPptFiles;
begin
    pptPlayer.RunFiles;
    TriggerAlbumState ('PPT�߰�����', pptPlayer.Running);
end;

procedure TAlbum.RunPptSchedule;
begin
    pptScheduler.Start;
    TriggerAlbumState ('PPT������', pptScheduler.Running);
end;


procedure TAlbum.RunMagicInfo (cmd: string);
begin
    miPlayer.Run (cmd);
    TriggerAlbumState ('��������', miPlayer.Running);
end;


procedure TAlbum.StopMagicInfo;
begin
    miPlayer.Stop;
    TriggerAlbumState ('', false);
end;


procedure TAlbum.RunAlbumList (Sender: TObject);
var
    i: integer;
begin
    // scManager.OnSchedule �̺�Ʈ�� ���� ȣ��Ǵ� �Լ�
    if (logoPlayer.Logo = nil) then exit;
    if not Assigned(FImage) then exit;
    if not Assigned(FWMP) then exit;

    // ��������: AlbumFileName�� �о���δ�
    // LoadPlayList;  // �����ٱ�� ������

    // ���⺯��: scManager�� ���� �����س� FileList�κ��� �о���δ�
    FFileList.LoadFromList (scManager.NewList);
    // �ٲ� ����Ʈ�� ��� ���� �����ϰ� �Ѵ� (Timer => PlayNextFile���� ó��)
    FIndex:= -1;

    {$IFOPT D+}
    // ���ο� List�� ���ѹ� ����� �ش�
    TriggerMemoOut ('---�����ٿ� ���� ���ο� AlbumList ����');
    TriggerMemoOut (inttostr(FFileList.Count) + '���� ���ϸ�� ���.'#13#10);
    for i:= 1 to FFileList.Count do begin
        TriggerMemoOut (Format('[%d] %s',[i, FFileList.FileItems[i-1].FileName]));
    end;
    {$ENDIF}

    // Timer�� �ѳ����� �ڵ����� �ϳ��� ����ȴ�
    FTimer.Enabled:= (FFileList.Count > 0);
    
    // TriggerAlbumState ('�ٹ����', FTimer.Enabled); => �̷��� �ϸ� '���Ͼ���' �뺸�� ���Ѵ�
    if (FFileList.Count > 0) then
        TriggerAlbumState ('�ٹ����', true)
    else begin
        TriggerAlbumState ('���Ͼ���', true);
        logoPlayer.Start;
    end;
end;


procedure TAlbum.RunAlbum;
begin
    // ���Լ��� ��������
    // from InitialLaunch (���α׷� ���۽�)
    // from ClientForm1   (���� �ٿ�ε� �Ϸ��)

    TriggerMemoOut ('--TAlbum.RunAlbum���� scManager.LoadFromFile ȣ��');
    scManager.LoadFromFile;
    // �̰ɷ� ��: TStringList�� �о� ���� DB���� ����
    // �������� scManager ������ Timer�� ���� �ڵ� ó���ȴ�
end;



// ----------------------------------------------------------------------------
// ���⼭���� PlayList ��� ���� �Լ�
// ----------------------------------------------------------------------------

procedure TAlbum.GetNextFile (var AFileItem: TFileItem);
begin
    AFileItem.FileName:= '';
    AFileItem.FileSize:= 0;
    AFileItem.PlayTime:= 0;
    if (FFileList.Count = 0) then exit;

    // PlayList�� �ִ� ���� �׸��� ����´�
    FIndex:= FIndex + 1;
    if (FIndex >= FFileList.Count) then FIndex:= 0;
    AFileItem.FileName:= FFileList.FileNames[FIndex];
    AFileItem.PlayTime:= FFileList.FileItems[FIndex].PlayTime;
end;


procedure TAlbum.PlayNextFile;
var
    FItem: TFileItem;
    FKind: TFileKind;
    ext: string;
begin
    // ����� ������ ������ ������
    if (FFileList.Count = 0) then exit;

    // ������ 1�� ���̰� �̹� ������̸� ������
    if (FFileList.Count = 1) then
    if (FIndex >= 0) then exit;

    // ������� �ʱ�ȭ: ppt�� ������ ���δ�. �������� ���� ���Ͽ� ���� ó���Ѵ� 
    // if (Fstate = avi) then StopMovie;
    if (Fstate = ppt) then pptPlayer.KillViewer;
    // Fstate:= non;    // ���⼭ non �ع����� �Ʒ� FKind�� ���� ó���ȵ�

    // ���� ������ �����´�.
    GetNextFile (FItem);

    // �̻��� ������ Ȯ���Ѵ�
    if (FItem.FileName = '') or (File_Size(FItem.FileName) < 30) then begin
        TriggerMemoOut ('�߸��� ����, List���� ����: ' + ExtractFileName (FItem.FileName));
        // �߸��� ���� or '404 Not Found' => ������ ������
        FFileList.DeleteFile (FItem.FileName);
        FIndex:= FIndex-1;
        logoPlayer.Start;

        if (Fstate = avi) then StopMovie;   // Fstate�� �ռ� �����Ѵ�
        Fstate:= non;   // �̰� ����� Timer1���� ���� ������ ����Ѵ�
        exit;
    end;

    // ������ ���� �Ǻ�
    TriggerMemoOut ('PlayNextFile: ' + ExtractFileName (FItem.FileName));
    FKind:= FileKind (FItem.FileName);

    // Server�� Album State�� ext�� �뺸
    ext:= UpperCase (ExtractFileExt (FItem.FileName));
    if (ext[1]='.') then Delete (ext, 1, 1);

    // �̹��� ������ ���
    if (FKind = img) then begin
        if (Fstate = avi) then StopMovie;
        Fstate:= img;
        Fsec:= 0;
        if (FItem.PlayTime > 0) then FjpgTime:= FItem.PlayTime else FjpgTime:= 5;
        FImage.Show;

        try
            FImage.Picture.LoadFromFile (FItem.FileName);
            if Assigned (FOnImageFile) then FOnImageFile (ExtractFileName (FItem.FileName));
         // TriggerAlbumState (ext, FImage.Visible);    // Server�� �����뺸
            TriggerAlbumState (ext+' ���', true);
        except
            TriggerMemoOut ('���Ͽ���: ' + ExtractFileName (FItem.FileName));
            FImage.Hide;
            FState:= non;
            FjpgTime:= 0;
        end;
    end

    // PowerPoint ������ ���
    else if (FKind = ppt) then begin
        if (Fstate = avi) then StopMovie;
        FState:= ppt;
        FImage.Hide;
        Fsec:= 0;
        if (FItem.PlayTime > 0) then FpptTime:= FItem.PlayTime else FpptTime:= 60;

        // PPT Viewer�� ������ �ش�. ��������� �ٷ� Skip��Ų��
        pptPlayer.Run (ExtractFileName (FItem.FileName));
        if pptPlayer.Running then Fstate:= ppt else FpptTime:= 1;
        TriggerAlbumState (ext+' ���', pptPlayer.Running);     // Server�� �����뺸
    end

    // ������ ������ ���
    else if (FKind = avi) then begin
        Fstate:= avi;
        FImage.Hide;
        FWMP.Show;

        // ������ 1�� ���̶�� ���ѹݺ��ϰ� �ƴϸ� 1ȸ�� ����Ѵ�
        if (FFileList.Count = 1) then FWMP.settings.setMode('loop', true)
        else FWMP.settings.setMode('loop', false);

        FWMP.URL:= FItem.FileName;    // �ڵ����
     // FWMP.controls.play;

        TriggerAlbumState (ext+' ���', true);
     // TriggerAlbumState (ext, FWMP.playState=wmppsPlaying);
    end

    // ����� ������ ����
    else Fstate:= non;

    // ���� ������¿� ���� Logo�� ���̰ų� �����
    if (Fstate = non) then logoPlayer.Start
    else logoPlayer.Stop;
end;


procedure TAlbum.Timer1Timer (Sender: TObject);
const
    lastState: WMPPlayState = wmppsUndefined;
begin
    // ���� 1�ʸ��� ���ͼ� �ʿ��� ���� ó���Ѵ�
    Fsec:= Fsec + 1;

    // ó�� ���� ���¶�� �������� ���
    if (Fstate = non) then PlayNextFile;

    // �׸��� �����ְ� �ֳ��� ����ð�(�⺻5��) ����� �������� ���
    if (Fstate = img) then
    if (Fsec > FjpgTime) then PlayNextFile;

    // ������ �����ְ� �ֳ��� �� ����� �������� ���
    if (Fstate = avi) then
    if (lastState <> FWMP.playState) then begin
        // ���°� �ٲ� ��쿡�� ó��
        lastState:= FWMP.playState;
        if (FWMP.playState = wmppsStopped) then PlayNextFile;
    end;

    // PPT�� �����ְ� �ֳ��� �ʿ�ð� ����� �������� ���
    if (Fstate = ppt) then
    if (pptPlayer.Running = false) or (Fsec > FpptTime) then PlayNextFile;
end;

end.

