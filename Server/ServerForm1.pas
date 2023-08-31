unit ServerForm1;

interface

uses
    WinTypes, WinProcs, Messages, SysUtils, Classes, Graphics, Forms,
    Buttons, Menus, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs, ExtDlgs,
    IniFiles, ShellApi, ScktComp, WSocket, WinSock, HttpSrv,
    jpeg, BlankUtils, Client, Globals, ImgList, ToolWin;

const
    // ImageIndex
    ICON_NONE = -1;
    ICON_GRAY  = 2;
    ICON_GREEN = 4;
    ICON_CLOCK = 6;

type
  TListView = class (ComCtrls.TListView)
  protected
    procedure WndProc (var Message: TMessage); override;
  end;

  TMainForm1 = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    ListView1: TListView;
    ImageList1: TImageList;
    cbSelectAll: TCheckBox;
    Memo1: TMemo;
    PopupMenu1: TPopupMenu;
    pmenuRemote: TMenuItem;
    pmenuInfo: TMenuItem;
    pmenuSchedule: TMenuItem;
    MainMenu1: TMainMenu;
    menuFile: TMenuItem;
    menuPwrOn: TMenuItem;
    menuReboot: TMenuItem;
    menuPwrOff: TMenuItem;
    menuSave: TMenuItem;
    menuAbout: TMenuItem;
    menuExit: TMenuItem;
    menuDID: TMenuItem;
    menuSendPpt: TMenuItem;
    menuSendPptFiles: TMenuItem;
    menuSendPptSchedule: TMenuItem;
    menuSendAlbum: TMenuItem;
    menuStopAlbum: TMenuItem;
    menuMagicInfo: TMenuItem;
    menuSendMagicInfo: TMenuItem;
    menuStopMagicInfo: TMenuItem;
    menuConfigMagicInfo: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    ToolBar1: TToolBar;
    sbPwrOn: TSpeedButton;
    sbPwrOff: TSpeedButton;
    sbSendPpt: TSpeedButton;
    sbSendAlbum: TSpeedButton;
    sbStopAlbum: TSpeedButton;
    sbN1: TSpeedButton;
    jpgOpenDialog: TOpenPictureDialog;
    pptOpenDialog: TOpenDialog;
    fileOpenDialog: TOpenDialog;
    Server1: TServerSocket;
    HttpServer1: THttpServer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbSelectAllClick(Sender: TObject);
    procedure pmenuRemoteClick(Sender: TObject);
    procedure pmenuInfoClick(Sender: TObject);
    procedure HttpServer1GetDocument(Sender, Client: TObject; var Flags: THttpGetFlag);
    procedure HttpServer1SendFile(Sender: TObject; DocSize, DataSent: Int64);
    procedure Server1ClientError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure Server1ClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Server1ClientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure menuSaveClick(Sender: TObject);
    procedure menuAboutClick(Sender: TObject);
    procedure menuExitClick(Sender: TObject);
    procedure menuPwrOnClick(Sender: TObject);
    procedure menuRebootClick(Sender: TObject);
    procedure menuPwrOffClick(Sender: TObject);
    procedure menuSendPptClick(Sender: TObject);
    procedure menuSendPptFilesClick(Sender: TObject);
    procedure menuSendPptScheduleClick(Sender: TObject);
    procedure menuSendAlbumClick(Sender: TObject);
    procedure menuStopAlbumClick(Sender: TObject);
    procedure menuSendMagicInfoClick(Sender: TObject);
    procedure menuStopMagicInfoClick(Sender: TObject);
    procedure menuConfigMagicInfoClick(Sender: TObject);
    procedure ListView1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure ListView1ColumnDragged(Sender: TObject);
    procedure ListView1DataHint(Sender: TObject; StartIndex, EndIndex: Integer);
    procedure pmenuScheduleClick(Sender: TObject);
  private
    clMax: integer;
    FFileName: string;
    MagicInfoVersion: string;
    FilesList: TStringList;
    cl: array[1..MAX_CLIENTS] of TClient;
    procedure InitComponents;
    procedure InitClientList;
    procedure SaveClientList;
    procedure LoadFromIniFile;
    procedure SaveToIniFile;
    function AnyClientSelected: boolean;
    function GetTotalSize (AList: TStringList): int64;
    procedure LaunchAlbumForm;
    procedure Memo_Out_Detail (msg: string);
    procedure Parse_ClientItem (s: string; var name, ip, mac: string);
    procedure SetItem_All (item: TListItem; name: string; pwr_on: boolean; operate, sent: string);
    procedure SetItem_On (i: integer; pwr_on: boolean); overload;
    procedure SetItem_On (item: TListItem; pwr_on: boolean); overload;
  public
    { Public declarations }
  end;

var
  MainForm1: TMainForm1;



implementation


{$R *.DFM}

uses
  AlbumForm1, SchForm1, MagicInfoForm1;


// ----------------------------------------------------------------------------
// 여기서부터 초기화 및 종료관련 함수
// ----------------------------------------------------------------------------

procedure TMainForm1.FormCreate(Sender: TObject);
begin
    Memo1.Lines.Add (MyCopyRight);
    InitComponents;     // 각종변수 초기화
    InitClientList;     // ClientList.txt를 읽어 CheckBox를 만든다
    LoadFromIniFile;    // 설정값을 읽어온다
    Server1.Open;       // Listening 시작
    HttpServer1.Start;  // 웹서버 동작시작
end;

procedure TMainForm1.FormDestroy(Sender: TObject);
var
    i: integer;
begin
    Server1.Close;
    HttpServer1.Stop;
    SaveToIniFile;
    SaveClientList;
    for i:= 1 to clMax do cl[i].Free;
    FilesList.Free;
    ListView1.Clear;
end;

procedure TMainForm1.InitComponents;
var
    i: integer;
begin
    // 현재폴더 (ExtractFilePath는 \가 붙는다)
    FFileName:= '';
    MagicInfoVersion:= 'Pro';
    HttpServer1.DocDir:= FolderName;
    ForceCurrentDirectory:= true;    // 폴더상자 초기값은 현재폴더로
    FilesList:= TStringList.Create;
    for i:= 1 to MAX_CLIENTS do cl[i]:= nil;
end;

procedure TMainForm1.InitClientList;
var
    i, c: integer;
    s, name, ip, mac: string;
    st: TStringList;
    item: TListItem;
begin
    c:= 0; clMax:= 0;
    st:= TStringList.Create;

    // ClientList.txt를 읽어들인다.
    st.Clear;
    if (FileExists(FolderName+'ClientList.txt')) then
    try st.LoadFromFile (FolderName+'ClientList.txt'); except end;
    if (st.Count = 0) then begin
        Memo1.Lines.Add ('ClientList.txt 파일을 먼저 편집하세요.');
        st.Add ('모니터1');
    end;

    // 하나씩 가져와서 처리한다.
    for i:= 1 to st.Count do begin
        s:= trim(st[i-1]);
        if (s='') then continue
        else if (s[1]='/') then continue

        else begin
            // 하나씩 가져와 분석한다
            Parse_ClientItem (s, name, ip, mac);
            c:= c + 1;  // Client Number Counter
            if (c > MAX_CLIENTS) then break;
            clMax:= c;  // 실제 Create된 갯수

            if (cl[c] = nil) then begin
                // Client 생성
                cl[c]:= TClient.Create (ListView1, 2);
                cl[c].Number:= c;
                cl[c].Name:= name;
                cl[c].IpAddr:= ip;
                cl[c].MacAddr:= mac;
                {$IFOPT D+}
                cl[c].OnMemoOut:= Memo_Out_Detail;
                {$ENDIF}
                
                // ListItem 생성
                item:= ListView1.Items.Add;
                item.SubItems.Add ('');
                item.SubItems.Add ('');
                item.SubItems.Add ('');
                item.SubItems.Add ('');
                cl[c].li:= item;
                item.Data:= cl[c];
                SetItem_All (item, name, false, '', '');
                // ProgressBar의 위치
                cl[c].Bar.Top:= item.Top+2;
            end;
        end;

        // Trial 버전은 Client 갯수에 제한을 둘수있다
        if (TrialVersion = 'Trial') then
        if (clMax >= 1) then begin
            Memo1.Lines.Add ('Trial Version 입니다. Client를 1개만 만들수 있습니다.');
            break;
        end;
    end;

    // 왼쪽을 모두 맞추어 준다
    ListView1ColumnDragged (Self);
    Memo_Out_Detail (inttostr(clMax)+' 개의 Client가 생성되었습니다.');
    st.Free;
end;

procedure TMainForm1.SaveClientList;
var
    i: integer;
    st: TStringList;
begin
    st:= TStringList.Create;
	st.Add ('// 이름	IP주소		MAC주소');

    // 그룹 미포함 저장
    for i:= 1 to clMax do if (cl[i] <> nil) then
    st.Add (cl[i].Name + #9 + cl[i].IpAddr + #9 + cl[i].MacAddr);

    try st.SaveToFile (FolderName+'ClientList.txt'); except end;
    st.Free;
end;

procedure TMainForm1.LoadFromIniFile;
var
    IniFile: TIniFile;
begin
    IniFile:= TIniFile.Create (FolderName+IniFileName);
    try
        try
            Server1.Port:= IniFile.ReadInteger ('Options', 'ServerPort', 51111);
            HttpServer1.Port:= IniFile.ReadString ('Options', 'HttpPort', '8001');
            cbSelectAll.Checked:= IniFile.ReadBool ('Options', 'BoxChecked', true);
            MagicInfoVersion:= IniFile.ReadString ('Options', 'MagicInfoVersion', 'Pro');
            menuSendPptFiles.Visible:= IniFile.ReadBool ('Visible', 'PptFiles', true);
            menuSendPptSchedule.Visible:= IniFile.ReadBool ('Visible', 'PptSchedule', true);
            menuMagicInfo.Visible:= IniFile.ReadBool ('Visible', 'MagicInfo', true);
        except
        end;
    finally
        IniFile.Free;
    end;
end;

procedure TMainForm1.SaveToIniFile;
var
    IniFile: TIniFile;
begin
    IniFile:= TIniFile.Create (FolderName+IniFileName);
    if (IniFile = nil) then exit;
    try
        try
            IniFile.WriteInteger('Options', 'ServerPort', Server1.Port);
            IniFile.WriteString ('Options', 'HttpPort', HttpServer1.Port);
            IniFile.WriteBool   ('Options', 'BoxChecked', cbSelectAll.Checked);
            IniFile.WriteString ('Options', 'MagicInfoVersion', MagicInfoVersion);
            IniFile.WriteBool ('Visible', 'PptFiles', menuSendPptFiles.Visible);
            IniFile.WriteBool ('Visible', 'PptSchedule', menuSendPptSchedule.Visible);
            IniFile.WriteBool ('Visible', 'MagicInfo', menuMagicInfo.Visible);
        except
        end;
    finally
        IniFile.Free;
    end;
end;



// ----------------------------------------------------------------------------
// 여기서부터 내부 Private 함수
// ----------------------------------------------------------------------------

function TMainForm1.AnyClientSelected: boolean;
begin
    // ListItem이 한개라도 선택되었는지
    Result:= (ListView1.SelCount > 0);
end;

function TMainForm1.GetTotalSize (AList: TStringList): int64;
var
    i: integer;
    fn: string;
begin
    Result:= 0;
    for i:= 1 to AList.Count do begin
        fn:= trim (AList[i-1]);
        if (fn[1] in ['/','*','[','(']) then continue;
        Result:= Result + File_Size (fn, 0);
    end;
end;

procedure TMainForm1.Memo_Out_Detail (msg: string);
begin
    {$IFOPT D+}
    Memo1.Lines.Add (msg);
    SendMessage(Memo1.Handle, EM_SCROLLCARET, 0, 0);
    {$ENDIF}
end;

procedure TMainForm1.Parse_ClientItem (s: string; var name, ip, mac: string);
var
    p: integer;
begin
    // s = '출입구    192.168.0.100    AABB99887766'
    name:= ''; ip:= ''; mac:= '';   // 초기화
    if (s = '') then exit;

    // Name을 읽어온다
    p:= pos (#9, s);
    if (p = 0) then name:= s else name:= Copy (s, 1, p-1);
    if (p = 0) then exit else Delete (s, 1, p);

    // ip를 읽어온다
    if (s = '') then exit;
    p:= pos (#9, s);
    if (p = 0) then ip:= s else ip:= Copy (s, 1, p-1);
    if (p = 0) then exit else Delete (s, 1, p);

    // mac을 읽어온다
    mac:= s;
end;

procedure TMainForm1.SetItem_All (item: TListItem; name: string; pwr_on: boolean; operate, sent: string);
var
    icon: integer;
    s: string;
begin
    // 유효성 검사
    if (item = nil) then exit;

    // 값에 변동이 있을때만 Set 한다.
    if (item.Caption <> name) then item.Caption:= name;
    if (item.ImageIndex <> 1) then item.ImageIndex:= 1;
    if (item.Data <> nil) then TClient(item.Data).PWR_ON:= pwr_on;

    if pwr_on then s:= 'ON' else s:= 'OFF';
    if (item.SubItems[0] <> s) then item.SubItems[0]:= s;
    if pwr_on then icon:= ICON_GREEN else icon:= ICON_GRAY;
    if (item.SubItemImages[0] <> icon) then item.SubItemImages[0]:= icon;

    if (item.SubItems[1] <> operate) then item.SubItems[1]:= operate;
    if (item.SubItems[2] <> sent) then item.SubItems[2]:= sent;
end;

procedure TMainForm1.SetItem_On (item: TListItem; pwr_on: boolean);
var
    icon: integer;
    s: string;
begin
    if (item = nil) then exit;
    if (item.Data <> nil) then begin
        if TClient(item.Data).PWR_ON = pwr_on then exit;
        TClient(item.Data).PWR_ON:= pwr_on;
    end;

    if pwr_on then s:= 'ON' else s:= 'OFF';
    if (item.SubItems[0] <> s) then item.SubItems[0]:= s;
    if pwr_on then icon:= ICON_GREEN else icon:= ICON_GRAY;
    if (item.SubItemImages[0] <> icon) then item.SubItemImages[0]:= icon;
end;

procedure TMainForm1.SetItem_On (i: integer; pwr_on: boolean);
begin
    SetItem_On (cl[i].li, pwr_on);
end;





// ----------------------------------------------------------------------------
// 여기서부터 Button Click 및 기본 Event 함수
// ----------------------------------------------------------------------------

procedure TMainForm1.cbSelectAllClick(Sender: TObject);
var
    i: integer;
begin
    for i:= 1 to ListView1.Items.Count do
    ListView1.Items.Item[i-1].Selected:= cbSelectAll.Checked;
end;

procedure TMainForm1.menuSaveClick(Sender: TObject);
begin
    SaveClientList;
end;

procedure TMainForm1.menuAboutClick(Sender: TObject);
begin
    ShowMessage (MyCopyRight);
end;

procedure TMainForm1.menuExitClick(Sender: TObject);
begin
    Close;
end;

procedure TMainForm1.menuPwrOnClick(Sender: TObject);
var
    i: integer;
begin
    // 선택한 모니터에 대해 매직패킷을 보낸다
    if (MessageDlg('선택한 모니터의 전원을 켤까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    for i:= 1 to clMax do
    if cl[i].Selected then begin
        SendMagicPacket (cl[i].MacAddr);
    end;

    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 전원켜기 신호를 전송하였습니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuRebootClick(Sender: TObject);
var
    i: integer;
begin
    if (MessageDlg('선택한 모니터를 재부팅 할까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    for i:= 1 to clMax do cl[i].SendTextIfSelected ('PWR_REBOOT');
    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 재부팅 신호를 전송하였습니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuPwrOffClick(Sender: TObject);
var
    i: integer;
begin
    if (MessageDlg('선택한 모니터의 전원을 끌까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    for i:= 1 to clMax do cl[i].SendTextIfSelected ('PWR_OFF');
    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 전원끄기 신호를 전송하였습니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuSendPptClick(Sender: TObject);
var
    i: integer;
    size: int64;
    cmd: string;
begin
    // PPT 파일을 찾아 보낸다.
    if (not pptOpenDialog.Execute) then exit;
    FFileName:= pptOpenDialog.FileName;
    if (MessageDlg('선택한 모니터로 PPT 파일을 보낼까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    if (UpperCase(ExtractFileExt(FFileName)) = '.PPT') then cmd:= 'SEND_PPT' else cmd:= 'SEND_PPTX';

    size:= File_Size (FFileName, 1);
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].TotalSize:= size;
        Memo_Out_Detail ('전송할 FileSize = ' + inttostr3(size));
        cl[i].SendTextIfSelected (cmd);
    end;

    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터로 PPT 파일을 전송합니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuSendPptFilesClick(Sender: TObject);
var
    i: integer;
    size: int64;
begin
    // 파일을 찾아 보낸다.
    if (not fileOpenDialog.Execute) then exit;
    // 선택된 파일목록은 fileOpenDialog.Files에 들어있다. 파일로 저장한다.
    FilesList.Text:= fileOpenDialog.Files.Text;
    FilesList.SaveToFile (FolderName+AdditionalFileName);
    if (MessageDlg('선택한 모니터로 파일을 보낼까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    size:= GetTotalSize (FilesList);
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].TotalSize:= size;
        Memo_Out_Detail ('전송할 TotalSize = ' + inttostr3(size));
        cl[i].SendTextIfSelected ('SEND_ADDLIST');
    end;

    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터로 파일을 전송합니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuSendPptScheduleClick(Sender: TObject);
var
    i: integer;
    size: int64;
begin
    // 파일목록 및 스케줄편집 창을 띄운다
    if (SchForm.ShowModal <> mrOk) then exit;
    FilesList.LoadFromFile (FolderName+ScheduleFileName);
    if (MessageDlg('선택한 모니터로 파일을 보낼까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    size:= GetTotalSize (FilesList);
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].TotalSize:= size;
        Memo_Out_Detail ('전송할 TotalSize = ' + inttostr3(size));
        cl[i].SendTextIfSelected ('SEND_SCHEDULE');
    end;

    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터로 파일을 전송합니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuSendAlbumClick(Sender: TObject);
begin
    // AlbumList_File.txt를 읽어들인다
    AlbumForm.LoadFromAlbumListFile;
    // AlbumForm을 띄운다
    LaunchAlbumForm;
end;

procedure TMainForm1.LaunchAlbumForm;
var
    i: integer;
begin
    // 매직앨범 창을 띄운다
    if (AlbumForm.ShowModal <> mrOk) then exit;
    // if (AlbumForm.FileList.Count = 0) then exit;
    if (AlbumForm.TotalSize <= 0) then exit;

    // 선택된 파일목록은 AlbumFileName 파일로 저장되어 있다.
    if (MessageDlg('선택한 모니터로 파일을 보낼까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].SendTextIfSelected ('SEND_ALBUM');
        // 동양대학교 홍보과 의견 반영: 각 모니터별 스케줄을 개별 저장
        CopyFile (PChar(FolderName+AlbumFileName), PChar(ScheduleFolder+inttostr(i)+'.txt'), false);
    end;

    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터로 파일을 전송합니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
end;

procedure TMainForm1.menuStopAlbumClick(Sender: TObject);
var
    i: integer;
begin
    if (MessageDlg('선택한 모니터에 재생을 중지할까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    for i:= 1 to clMax do cl[i].SendTextIfSelected ('STOP_ALBUM');
    if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터의 재생을 중지합니다.')
    else Memo1.Lines.Add ('선택한 모니터가 없습니다.');

    // 선택한 모니터의 운영상태를 Clear한다
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].li.SubItems[1]:= '';
        cl[i].li.SubItems[2]:= '';
    end;
end;

procedure TMainForm1.menuSendMagicInfoClick(Sender: TObject);
var
    i: integer;
begin
    // MagicInfo Pro
    if (MagicInfoVersion = 'Pro') then begin
        if (MessageDlg('선택한 모니터에 매직인포 Pro를 실행할까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('RUN_MIP');
        if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 매직인포 Pro를 실행합니다.')
        else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
    end

    // MagicInfo i Premium
    else begin
        if (MessageDlg('선택한 모니터에 매직인포 Premium-i를 실행할까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('RUN_MIIP');
        if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 매직인포 Premium-i를 실행합니다.')
        else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
    end;
end;

procedure TMainForm1.menuStopMagicInfoClick(Sender: TObject);
var
    i: integer;
begin
    // MagicInfo Pro
    if (MagicInfoVersion = 'Pro') then begin
        if (MessageDlg('선택한 모니터에 매직인포 Pro를 종료할까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('STOP_MIP');
        if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 매직인포 Pro를 종료합니다.')
        else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
    end

    // MagicInfo i Premium
    else begin
        if (MessageDlg('선택한 모니터에 매직인포i Premium을 종료할까요?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('STOP_MIIP');
        if AnyClientSelected then Memo1.Lines.Add ('선택한 모니터에 매직인포i Premium을 종료합니다.')
        else Memo1.Lines.Add ('선택한 모니터가 없습니다.');
    end;
end;

procedure TMainForm1.menuConfigMagicInfoClick(Sender: TObject);
begin
    // 초기값 설정
    if (MagicInfoVersion = 'Pro') then MagicInfoForm.RadioGroup1.ItemIndex:= 0
    else MagicInfoForm.RadioGroup1.ItemIndex:= 1;
    // 대화상자 실행
    if (MagicInfoForm.ShowModal <> mrOk) then exit;
    // 결과값 반영
    if (MagicInfoForm.RadioGroup1.ItemIndex = 0) then MagicInfoVersion:= 'Pro'
    else MagicInfoVersion:= 'Premium';
end;

procedure TMainForm1.pmenuRemoteClick(Sender: TObject);
var
    item: TListItem;
    c: TClient;
    ip: string;
begin
    // 팝업이 어느놈에 의해 눌러졌는지 Tag로서 알아낸다.
    item:= ListView1.Selected;
    if (item = nil) then exit;
    c:= item.Data;

    // ListItem에 SBB의 IP주소가 있으므로 바로 처리한다
    ip:= c.IpAddr;      // Client의 IP주소
    if (ip > '') and (ip <> '0.0.0.0') then begin
        if (MessageDlg ('"vncviewer '+ip+'"  명령으로 원격접속 합니다.'#13#13#10
        +'마우스나 키보드 조작시 공공장소에 그대로 노출됩니다.'#13#13#10
        +'원격접속을 하시겠습니까?'#13#10, mtInformation, mbOkCancel, 0) = mrCancel) then exit;

        // 원격 IP로 접속을 시도한다. vncviewer.exe가 같은 폴더에 있어야 한다.
        ShellExecute (0, nil, PChar(FolderName+'vncviewer.exe'), PChar(ip), nil, SW_NORMAL);
    end;
end;

procedure TMainForm1.pmenuInfoClick(Sender: TObject);
var
    item: TListItem;
    c: TClient;
    s: string;
begin
    // 팝업이 어느놈에 의해 눌러졌는지 알아낸다.
    item:= ListView1.Selected;
    if (item = nil) then exit;
    c:= item.Data;

    s:= '■ Client 정보'#13#10#10
    + 'Client 이름 = ' + item.Caption + #13#10#10
    + 'Client 번호 = ' + inttostr(c.Number) + #13#10#10
    + 'IP Address = '  + c.IpAddr + #13#10#10
    + 'MAC Address = ' + c.MacAddr + #13#10#10;

    ShowMessage (s);
end;

procedure TMainForm1.pmenuScheduleClick(Sender: TObject);
var
    item: TListItem;
    c: TClient;
    AFileName: string;
begin
    // 팝업이 어느놈에 의해 눌러졌는지 알아낸다.
    item:= ListView1.Selected;
    if (item = nil) then exit;
    c:= item.Data;

    // 스케줄 파일이 있으면 AlbumForm을 띄워 보여준다
    AFileName:= ScheduleFolder+inttostr(c.Number)+'.txt';
    if FileExists (AFileName) then begin
        // AlbumList_File.txt를 읽어들인다
        AlbumForm.LoadFromAlbumListFile (AFileName);
        // AlbumForm을 띄운다
        LaunchAlbumForm;
    end;
end;




// ----------------------------------------------------------------------------
// 여기서부터 WebServer 관련함수
// ----------------------------------------------------------------------------

procedure Parse_Parameter (Param: string; var num: integer; var value1, value2: string);
const
    MAX_LEN = 4095;  // Parameter나 value가 가질수 있는 최대길이
var
    l,p,q: integer;
    s,t: string;
begin
    // 입력 Param: 'num=1' 또는 'num=1&mac=AABB99887766'
    // 출력 num: 1
    // 출력 mac: 'AABB99887766'

    // 리턴값 초기화
    num:= -1;
    value1:= '';
    value2:= '';

    // 유효성 검사: num=1부터 9까지 가능, Param이 너무길면 오류처리
    l:= length(Param);
    if (l<5) or (l>MAX_LEN) then exit;
    if (Copy(Param,1,4) <> 'num=') then exit;
    if (Param[5] < '0') or (Param[5] > '9') then exit;

    // 하나씩 쪼개어 num과 mac을 가져온다
    repeat
        if (Param = '') then exit;
        // & 앞부분을 s로 잘라와 분석
        p:= pos ('&', Param);
        if (p=0) then p:= MAX_LEN;
        s:= Copy (Param, 1, p-1);
        Delete (Param, 1, p);

        // = 앞뒤로 잘라 분석한다
        q:= pos ('=', s);
        if (q > 0) then begin
            t:= Copy (s, 1, q);
            if (t='num=') then num:= strtoint32 (Copy(s,q+1,99), 0) else
            if (t='mac=') then value1:= Copy(s,q+1,12) else
            if (t='album=') then value2:= Copy(s,q+1,MAX_LEN) else
            if (t='pathname=') then value1:= Copy(s,q+1,MAX_LEN);
        end;
    until (Param = '');
end;


procedure TMainForm1.HttpServer1GetDocument(Sender, Client: TObject; var Flags: THttpGetFlag);
var
    i: integer;
    Conn: THttpConnection;
    Path, Param, s, mac: string;
begin
    // Client를 Access하기 위한 변수
    Conn:= THttpConnection(Client);
    Path:= Conn.Path;
    Param:= Conn.Params;

    // 어느 Client인지 알아내어 Tag에 보관해 둔다
    Parse_Parameter (Param, i, s, mac);  // i만 알아오면 된다
    Conn.Tag:= i;

    // 요청 내용에 따라 처리한다
    s:= Path; if (Param > '') then s:= s + '?' + Param;
    {$IFOPT D+}
    ShortDateFormat:= '[hh:nn:ss.zzz] ';
    Memo_Out_Detail (DateToStr(now) + Conn.GetPeerAddr + '에서 ' + s);
    {$ENDIF}

    if (Path = '/jpg.html') then begin
        Conn.Document:= FFileName;    // OpenPictureDialog1.FileName;
    end

    else if (Path = '/ppt.html') then begin
        Conn.Document:= FFileName;    // OpenDialog1.FileName;
    end

    else if (Path = '/albumlist.html') then begin
        Conn.Document:= FolderName + AlbumFileName;
    end

    else if (Path = '/addlist.html') then begin
        Conn.Document:= FolderName + AdditionalFileName;
    end

    else if (Path = '/schedule.html') then begin
        Conn.Document:= FolderName + ScheduleFileName;
    end

    else if (Path = '/getfile.html') then begin
        Parse_Parameter (Param, i, s, mac);  // s만 알아오면 된다
        // ?num=3&pathname=D:\earth.jpg 처럼 들어오면 해당 파일을 보내준다 (절대경로)
        s:= UrlDecode (s);
        if File_Exists(s) then Conn.Document:= s;
    end

    else if (Path = '/complete.html') then begin
        // 추가파일 전송이 완료됐을때 통보된다
        Parse_Parameter (Param, i, s, mac);  // i만 알아오면 된다
        if (i <= 0) or (i > clMAX) then exit;
        if (cl[i] = nil) then exit;
        cl[i].li.SubItems[2]:= '100%';
        cl[i].Bar.Position:= cl[i].Bar.Max;
        Memo_Out_Detail ('['+cl[i].Name + '] 파일 전송이 완료되었습니다.');
    end;
end;


procedure TMainForm1.HttpServer1SendFile(Sender: TObject; DocSize, DataSent: Int64);
var
    i: integer;
    Conn: THttpConnection;
begin
    // 1460 Bytes 단위로 보내니까 ProgressBar 등을 통해 화면에 보여주기 때문에 전송속도 자체가 느려짐
    // 따라서 매번 처리않고 약 16KB 또는 64KB 단위로 끊어서 처리한다.
    // Test결과 1460B * 10회에 한번씩만 처리, 파일 막판에는 무조건 처리 => 상당히 빨라짐, 보기에도 괜찮음
    if not ((DocSize = DataSent) or (DataSent div 1460 mod 10 = 0)) then exit;

    // Http로 파일을 보낼때마다 여기로 들어온다.
    Conn:= THttpConnection(Sender);
    if (Conn.Path = '/getfile.html') or (Conn.Path = '/ppt.html') then begin
        i:= Conn.Tag;
        // Memo_Out_Detail (Conn.Path + ' from ' + inttostr(i));
        if (i > 0) then begin
            // 숫자% 및 ProgressBar에 전송률 올린다
            cl[i].ProgressTotalSent (DocSize, DataSent);

            // Memo_Out_Detail (
            // Format('i=%d, DocSize=%d, DataSend=%d, FLastSent=%d, Delta=%d, TotalSent=%d, TotalSize=%d, ProgPos=%d, ProgMax=%d',
            //  [i, DocSize, DataSent, FLastSent, Delta, c.TotalSent, c.TotalSize, c.Bar.Position, c.Bar.Max]));
        end;
    end;
end;





// ----------------------------------------------------------------------------
// 여기서부터 Socket 관련함수
// ----------------------------------------------------------------------------

procedure TMainForm1.Server1ClientError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
    Memo_Out_Detail ('Socket에서 Exception 발생');
    ErrorCode:= 0;    // 더이상 Exception이 발생하지 않게 한다
    Server1ClientDisconnect (Sender, Socket);
end;

procedure TMainForm1.Server1ClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
var
    cl: TClient;
begin
    // 미리 등록해둔 Socket.Data를 보고 어떤 놈인지 알아낸다
    if (Socket.Data <> nil) then begin
        cl:= TClient (Socket.Data);
        SetItem_On (cl.li, false);
        cl.SetDisConnected;
    end;
end;

procedure TMainForm1.Server1ClientRead(Sender: TObject; Socket: TCustomWinSocket);
var
    s, mac, album: string;
    i: integer;
    ts: int64;
    c: TClient;
begin
    // Client가 첫 접속하면 여기로 보내온다
    s:= Socket.ReceiveText;
    // Memo_Out_Detail ('수신: ' + s);

    // 15초마다 연결확인용
    if (s = 'HellO') then begin
        Socket.SendText ('GooD');
        if (Socket.Data <> nil) then
        SetItem_On (TClient(Socket.Data).li, true);
    end

    // 최초 연결시: num=1&mac=AABB99887766 처럼 들어온다
    else if (Copy(s,1,4) = 'num=') then begin
        Parse_Parameter (s, i, mac, album);
        // if not (i in [1..clMax]) then exit;
        if (i <= 0) or (i > clMAX) then exit;    // 번호의 유효성 검사
        if (cl[i] = nil) then exit;

        // 각종 정보를 저장한다
        // if (mac > '') then ..... mac='HellO'가 들어오기도 한다!
        if (length(mac)=12) then cl[i].MacAddr:= mac;
        cl[i].IpAddr:= Socket.RemoteAddress;
        cl[i].Socket:= Socket;
        Socket.Data:= cl[i];
        SaveToIniFile;

        // i번 Client가 살아 있음을 표시
        SetItem_On (i, true);
        // 앨범 운영상태 표시
        cl[i].li.SubItems[1]:= album;
        Memo_Out_Detail (inttostr(i)+'번 '+cl[i].Name+'의 운영상태: '+album);
    end

    // Client에서 Album 운영상태를 통보해옴
    else if (Copy(s,1,11)='AlbumState=') then begin
        if (Socket.Data <> nil) then begin
            // album:= Copy (s, 12, 99);
            Delete (s,1,11);
            c:= TClient(Socket.Data);
            c.li.SubItems[1]:= s;
            Memo_Out_Detail (inttostr(c.Number)+'번 '+c.Name+'의 운영상태: '+s);
        end;
    end

    // GetFilesClient에서 받아야할 총용량을 Server로 통보
    else if (Copy(s,1,10)='TotalSize=') then begin
        if (Socket.Data <> nil) then begin
            // 해당 Client의 총용량을 저장한다
            Delete (s,1,10);
            ts:= strtoint64 (s, 0);
            c:= TClient(Socket.Data);
            c.TotalSize:= ts;
            Memo_Out_Detail (inttostr(c.Number)+'번 '+c.Name+'의 받을 총용량: '+inttostr3(ts));
        end;
    end;
end;




// ----------------------------------------------------------------------------
// 여기서부터 ListView 관련함수
// ----------------------------------------------------------------------------

procedure TMainForm1.ListView1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    item: TListItem;
begin
    // item을 Check하면 Select되게 한다
    item:= ListView1.GetItemAt (X, Y);
    if (item <> nil) then item.Selected:= item.Checked;
end;

procedure TMainForm1.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    // Item 선택하면 CheckBox도 함께 Check되게 한다.
    Item.Checked:= Selected;
end;

procedure TListView.WndProc(var Message: TMessage);
begin
    inherited;
    case Message.Msg of
        WM_VSCROLL: begin
            // ListView를 Scroll할 때마다 오는 Event임 => MainForm에서 처리해 주게했다
            if Assigned(OnDataHint) then OnDataHint(Self,0,0);
           {for i:= 1 to MainForm2.clMax do begin
                MainForm2.cl[i].Bar.Top:= Self.Items[i-1].Position.Y + 2;
                MainForm2.cl[i].Bar.Visible:= (MainForm2.cl[i].Bar.Top > 15);
            end;
            //MainForm2.Memo1.Lines.Add(inttostr(Self.Items[0].Position.Y)) }
        end;
    end;
end;

procedure TMainForm1.ListView1ColumnDragged(Sender: TObject);
var
    i,p: integer;
begin
    // Column 크기를 변경할 때마다 ProgressBar 위치도 모두 옮겨준다
    // ComCtrls.pas 수정: Column 크기를 변경할때 Event를 하나 발생시켜 여기로 오게했다
    // Event Handler를 따로 만들어야 하지만 귀찮아서 OnColumnDragged를 활용하였다

    // 변경된 Column들의 Width를 모두 더한다
    p:= 0;
    for i:= 1 to 4 do
    p:= p + ListView1.Column[i-1].Width;

    for i:= 1 to clMax do
    cl[i].Bar.Left:= p + 2;
end;

procedure TMainForm1.ListView1DataHint(Sender: TObject; StartIndex, EndIndex: Integer);
var
    i: integer;
begin
    // ListView를 수직 스크롤하면 ProgressBar의 위치도 옮겨준다
    // Event Handler를 따로 만들어야 하지만 귀찮아서 OnDataHint를 활용하였다
    for i:= 1 to clMax do begin
        cl[i].Bar.Top:= cl[i].li.Position.Y + 2;
        cl[i].Bar.Visible:= (cl[i].Bar.Top > 15);
    end;
end;

end.

