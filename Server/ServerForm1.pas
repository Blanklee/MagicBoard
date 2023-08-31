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
// ���⼭���� �ʱ�ȭ �� ������� �Լ�
// ----------------------------------------------------------------------------

procedure TMainForm1.FormCreate(Sender: TObject);
begin
    Memo1.Lines.Add (MyCopyRight);
    InitComponents;     // �������� �ʱ�ȭ
    InitClientList;     // ClientList.txt�� �о� CheckBox�� �����
    LoadFromIniFile;    // �������� �о�´�
    Server1.Open;       // Listening ����
    HttpServer1.Start;  // ������ ���۽���
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
    // �������� (ExtractFilePath�� \�� �ٴ´�)
    FFileName:= '';
    MagicInfoVersion:= 'Pro';
    HttpServer1.DocDir:= FolderName;
    ForceCurrentDirectory:= true;    // �������� �ʱⰪ�� ����������
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

    // ClientList.txt�� �о���δ�.
    st.Clear;
    if (FileExists(FolderName+'ClientList.txt')) then
    try st.LoadFromFile (FolderName+'ClientList.txt'); except end;
    if (st.Count = 0) then begin
        Memo1.Lines.Add ('ClientList.txt ������ ���� �����ϼ���.');
        st.Add ('�����1');
    end;

    // �ϳ��� �����ͼ� ó���Ѵ�.
    for i:= 1 to st.Count do begin
        s:= trim(st[i-1]);
        if (s='') then continue
        else if (s[1]='/') then continue

        else begin
            // �ϳ��� ������ �м��Ѵ�
            Parse_ClientItem (s, name, ip, mac);
            c:= c + 1;  // Client Number Counter
            if (c > MAX_CLIENTS) then break;
            clMax:= c;  // ���� Create�� ����

            if (cl[c] = nil) then begin
                // Client ����
                cl[c]:= TClient.Create (ListView1, 2);
                cl[c].Number:= c;
                cl[c].Name:= name;
                cl[c].IpAddr:= ip;
                cl[c].MacAddr:= mac;
                {$IFOPT D+}
                cl[c].OnMemoOut:= Memo_Out_Detail;
                {$ENDIF}
                
                // ListItem ����
                item:= ListView1.Items.Add;
                item.SubItems.Add ('');
                item.SubItems.Add ('');
                item.SubItems.Add ('');
                item.SubItems.Add ('');
                cl[c].li:= item;
                item.Data:= cl[c];
                SetItem_All (item, name, false, '', '');
                // ProgressBar�� ��ġ
                cl[c].Bar.Top:= item.Top+2;
            end;
        end;

        // Trial ������ Client ������ ������ �Ѽ��ִ�
        if (TrialVersion = 'Trial') then
        if (clMax >= 1) then begin
            Memo1.Lines.Add ('Trial Version �Դϴ�. Client�� 1���� ����� �ֽ��ϴ�.');
            break;
        end;
    end;

    // ������ ��� ���߾� �ش�
    ListView1ColumnDragged (Self);
    Memo_Out_Detail (inttostr(clMax)+' ���� Client�� �����Ǿ����ϴ�.');
    st.Free;
end;

procedure TMainForm1.SaveClientList;
var
    i: integer;
    st: TStringList;
begin
    st:= TStringList.Create;
	st.Add ('// �̸�	IP�ּ�		MAC�ּ�');

    // �׷� ������ ����
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
// ���⼭���� ���� Private �Լ�
// ----------------------------------------------------------------------------

function TMainForm1.AnyClientSelected: boolean;
begin
    // ListItem�� �Ѱ��� ���õǾ�����
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
    // s = '���Ա�    192.168.0.100    AABB99887766'
    name:= ''; ip:= ''; mac:= '';   // �ʱ�ȭ
    if (s = '') then exit;

    // Name�� �о�´�
    p:= pos (#9, s);
    if (p = 0) then name:= s else name:= Copy (s, 1, p-1);
    if (p = 0) then exit else Delete (s, 1, p);

    // ip�� �о�´�
    if (s = '') then exit;
    p:= pos (#9, s);
    if (p = 0) then ip:= s else ip:= Copy (s, 1, p-1);
    if (p = 0) then exit else Delete (s, 1, p);

    // mac�� �о�´�
    mac:= s;
end;

procedure TMainForm1.SetItem_All (item: TListItem; name: string; pwr_on: boolean; operate, sent: string);
var
    icon: integer;
    s: string;
begin
    // ��ȿ�� �˻�
    if (item = nil) then exit;

    // ���� ������ �������� Set �Ѵ�.
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
// ���⼭���� Button Click �� �⺻ Event �Լ�
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
    // ������ ����Ϳ� ���� ������Ŷ�� ������
    if (MessageDlg('������ ������� ������ �ӱ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    for i:= 1 to clMax do
    if cl[i].Selected then begin
        SendMagicPacket (cl[i].MacAddr);
    end;

    if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� �����ѱ� ��ȣ�� �����Ͽ����ϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuRebootClick(Sender: TObject);
var
    i: integer;
begin
    if (MessageDlg('������ ����͸� ����� �ұ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    for i:= 1 to clMax do cl[i].SendTextIfSelected ('PWR_REBOOT');
    if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� ����� ��ȣ�� �����Ͽ����ϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuPwrOffClick(Sender: TObject);
var
    i: integer;
begin
    if (MessageDlg('������ ������� ������ �����?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    for i:= 1 to clMax do cl[i].SendTextIfSelected ('PWR_OFF');
    if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� �������� ��ȣ�� �����Ͽ����ϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuSendPptClick(Sender: TObject);
var
    i: integer;
    size: int64;
    cmd: string;
begin
    // PPT ������ ã�� ������.
    if (not pptOpenDialog.Execute) then exit;
    FFileName:= pptOpenDialog.FileName;
    if (MessageDlg('������ ����ͷ� PPT ������ �������?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    if (UpperCase(ExtractFileExt(FFileName)) = '.PPT') then cmd:= 'SEND_PPT' else cmd:= 'SEND_PPTX';

    size:= File_Size (FFileName, 1);
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].TotalSize:= size;
        Memo_Out_Detail ('������ FileSize = ' + inttostr3(size));
        cl[i].SendTextIfSelected (cmd);
    end;

    if AnyClientSelected then Memo1.Lines.Add ('������ ����ͷ� PPT ������ �����մϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuSendPptFilesClick(Sender: TObject);
var
    i: integer;
    size: int64;
begin
    // ������ ã�� ������.
    if (not fileOpenDialog.Execute) then exit;
    // ���õ� ���ϸ���� fileOpenDialog.Files�� ����ִ�. ���Ϸ� �����Ѵ�.
    FilesList.Text:= fileOpenDialog.Files.Text;
    FilesList.SaveToFile (FolderName+AdditionalFileName);
    if (MessageDlg('������ ����ͷ� ������ �������?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    size:= GetTotalSize (FilesList);
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].TotalSize:= size;
        Memo_Out_Detail ('������ TotalSize = ' + inttostr3(size));
        cl[i].SendTextIfSelected ('SEND_ADDLIST');
    end;

    if AnyClientSelected then Memo1.Lines.Add ('������ ����ͷ� ������ �����մϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuSendPptScheduleClick(Sender: TObject);
var
    i: integer;
    size: int64;
begin
    // ���ϸ�� �� ���������� â�� ����
    if (SchForm.ShowModal <> mrOk) then exit;
    FilesList.LoadFromFile (FolderName+ScheduleFileName);
    if (MessageDlg('������ ����ͷ� ������ �������?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    size:= GetTotalSize (FilesList);
    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].TotalSize:= size;
        Memo_Out_Detail ('������ TotalSize = ' + inttostr3(size));
        cl[i].SendTextIfSelected ('SEND_SCHEDULE');
    end;

    if AnyClientSelected then Memo1.Lines.Add ('������ ����ͷ� ������ �����մϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuSendAlbumClick(Sender: TObject);
begin
    // AlbumList_File.txt�� �о���δ�
    AlbumForm.LoadFromAlbumListFile;
    // AlbumForm�� ����
    LaunchAlbumForm;
end;

procedure TMainForm1.LaunchAlbumForm;
var
    i: integer;
begin
    // �����ٹ� â�� ����
    if (AlbumForm.ShowModal <> mrOk) then exit;
    // if (AlbumForm.FileList.Count = 0) then exit;
    if (AlbumForm.TotalSize <= 0) then exit;

    // ���õ� ���ϸ���� AlbumFileName ���Ϸ� ����Ǿ� �ִ�.
    if (MessageDlg('������ ����ͷ� ������ �������?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;

    for i:= 1 to clMax do
    if cl[i].Selected then begin
        cl[i].InitTotalSize;
        cl[i].SendTextIfSelected ('SEND_ALBUM');
        // ������б� ȫ���� �ǰ� �ݿ�: �� ����ͺ� �������� ���� ����
        CopyFile (PChar(FolderName+AlbumFileName), PChar(ScheduleFolder+inttostr(i)+'.txt'), false);
    end;

    if AnyClientSelected then Memo1.Lines.Add ('������ ����ͷ� ������ �����մϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
end;

procedure TMainForm1.menuStopAlbumClick(Sender: TObject);
var
    i: integer;
begin
    if (MessageDlg('������ ����Ϳ� ����� �����ұ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
    for i:= 1 to clMax do cl[i].SendTextIfSelected ('STOP_ALBUM');
    if AnyClientSelected then Memo1.Lines.Add ('������ ������� ����� �����մϴ�.')
    else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');

    // ������ ������� ����¸� Clear�Ѵ�
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
        if (MessageDlg('������ ����Ϳ� �������� Pro�� �����ұ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('RUN_MIP');
        if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� �������� Pro�� �����մϴ�.')
        else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
    end

    // MagicInfo i Premium
    else begin
        if (MessageDlg('������ ����Ϳ� �������� Premium-i�� �����ұ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('RUN_MIIP');
        if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� �������� Premium-i�� �����մϴ�.')
        else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
    end;
end;

procedure TMainForm1.menuStopMagicInfoClick(Sender: TObject);
var
    i: integer;
begin
    // MagicInfo Pro
    if (MagicInfoVersion = 'Pro') then begin
        if (MessageDlg('������ ����Ϳ� �������� Pro�� �����ұ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('STOP_MIP');
        if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� �������� Pro�� �����մϴ�.')
        else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
    end

    // MagicInfo i Premium
    else begin
        if (MessageDlg('������ ����Ϳ� ��������i Premium�� �����ұ��?', mtConfirmation, mbOkCancel, 0) = mrCancel) then exit;
        for i:= 1 to clMax do cl[i].SendTextIfSelected ('STOP_MIIP');
        if AnyClientSelected then Memo1.Lines.Add ('������ ����Ϳ� ��������i Premium�� �����մϴ�.')
        else Memo1.Lines.Add ('������ ����Ͱ� �����ϴ�.');
    end;
end;

procedure TMainForm1.menuConfigMagicInfoClick(Sender: TObject);
begin
    // �ʱⰪ ����
    if (MagicInfoVersion = 'Pro') then MagicInfoForm.RadioGroup1.ItemIndex:= 0
    else MagicInfoForm.RadioGroup1.ItemIndex:= 1;
    // ��ȭ���� ����
    if (MagicInfoForm.ShowModal <> mrOk) then exit;
    // ����� �ݿ�
    if (MagicInfoForm.RadioGroup1.ItemIndex = 0) then MagicInfoVersion:= 'Pro'
    else MagicInfoVersion:= 'Premium';
end;

procedure TMainForm1.pmenuRemoteClick(Sender: TObject);
var
    item: TListItem;
    c: TClient;
    ip: string;
begin
    // �˾��� ����� ���� ���������� Tag�μ� �˾Ƴ���.
    item:= ListView1.Selected;
    if (item = nil) then exit;
    c:= item.Data;

    // ListItem�� SBB�� IP�ּҰ� �����Ƿ� �ٷ� ó���Ѵ�
    ip:= c.IpAddr;      // Client�� IP�ּ�
    if (ip > '') and (ip <> '0.0.0.0') then begin
        if (MessageDlg ('"vncviewer '+ip+'"  ������� �������� �մϴ�.'#13#13#10
        +'���콺�� Ű���� ���۽� ������ҿ� �״�� ����˴ϴ�.'#13#13#10
        +'���������� �Ͻðڽ��ϱ�?'#13#10, mtInformation, mbOkCancel, 0) = mrCancel) then exit;

        // ���� IP�� ������ �õ��Ѵ�. vncviewer.exe�� ���� ������ �־�� �Ѵ�.
        ShellExecute (0, nil, PChar(FolderName+'vncviewer.exe'), PChar(ip), nil, SW_NORMAL);
    end;
end;

procedure TMainForm1.pmenuInfoClick(Sender: TObject);
var
    item: TListItem;
    c: TClient;
    s: string;
begin
    // �˾��� ����� ���� ���������� �˾Ƴ���.
    item:= ListView1.Selected;
    if (item = nil) then exit;
    c:= item.Data;

    s:= '�� Client ����'#13#10#10
    + 'Client �̸� = ' + item.Caption + #13#10#10
    + 'Client ��ȣ = ' + inttostr(c.Number) + #13#10#10
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
    // �˾��� ����� ���� ���������� �˾Ƴ���.
    item:= ListView1.Selected;
    if (item = nil) then exit;
    c:= item.Data;

    // ������ ������ ������ AlbumForm�� ��� �����ش�
    AFileName:= ScheduleFolder+inttostr(c.Number)+'.txt';
    if FileExists (AFileName) then begin
        // AlbumList_File.txt�� �о���δ�
        AlbumForm.LoadFromAlbumListFile (AFileName);
        // AlbumForm�� ����
        LaunchAlbumForm;
    end;
end;




// ----------------------------------------------------------------------------
// ���⼭���� WebServer �����Լ�
// ----------------------------------------------------------------------------

procedure Parse_Parameter (Param: string; var num: integer; var value1, value2: string);
const
    MAX_LEN = 4095;  // Parameter�� value�� ������ �ִ� �ִ����
var
    l,p,q: integer;
    s,t: string;
begin
    // �Է� Param: 'num=1' �Ǵ� 'num=1&mac=AABB99887766'
    // ��� num: 1
    // ��� mac: 'AABB99887766'

    // ���ϰ� �ʱ�ȭ
    num:= -1;
    value1:= '';
    value2:= '';

    // ��ȿ�� �˻�: num=1���� 9���� ����, Param�� �ʹ���� ����ó��
    l:= length(Param);
    if (l<5) or (l>MAX_LEN) then exit;
    if (Copy(Param,1,4) <> 'num=') then exit;
    if (Param[5] < '0') or (Param[5] > '9') then exit;

    // �ϳ��� �ɰ��� num�� mac�� �����´�
    repeat
        if (Param = '') then exit;
        // & �պκ��� s�� �߶�� �м�
        p:= pos ('&', Param);
        if (p=0) then p:= MAX_LEN;
        s:= Copy (Param, 1, p-1);
        Delete (Param, 1, p);

        // = �յڷ� �߶� �м��Ѵ�
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
    // Client�� Access�ϱ� ���� ����
    Conn:= THttpConnection(Client);
    Path:= Conn.Path;
    Param:= Conn.Params;

    // ��� Client���� �˾Ƴ��� Tag�� ������ �д�
    Parse_Parameter (Param, i, s, mac);  // i�� �˾ƿ��� �ȴ�
    Conn.Tag:= i;

    // ��û ���뿡 ���� ó���Ѵ�
    s:= Path; if (Param > '') then s:= s + '?' + Param;
    {$IFOPT D+}
    ShortDateFormat:= '[hh:nn:ss.zzz] ';
    Memo_Out_Detail (DateToStr(now) + Conn.GetPeerAddr + '���� ' + s);
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
        Parse_Parameter (Param, i, s, mac);  // s�� �˾ƿ��� �ȴ�
        // ?num=3&pathname=D:\earth.jpg ó�� ������ �ش� ������ �����ش� (������)
        s:= UrlDecode (s);
        if File_Exists(s) then Conn.Document:= s;
    end

    else if (Path = '/complete.html') then begin
        // �߰����� ������ �Ϸ������ �뺸�ȴ�
        Parse_Parameter (Param, i, s, mac);  // i�� �˾ƿ��� �ȴ�
        if (i <= 0) or (i > clMAX) then exit;
        if (cl[i] = nil) then exit;
        cl[i].li.SubItems[2]:= '100%';
        cl[i].Bar.Position:= cl[i].Bar.Max;
        Memo_Out_Detail ('['+cl[i].Name + '] ���� ������ �Ϸ�Ǿ����ϴ�.');
    end;
end;


procedure TMainForm1.HttpServer1SendFile(Sender: TObject; DocSize, DataSent: Int64);
var
    i: integer;
    Conn: THttpConnection;
begin
    // 1460 Bytes ������ �����ϱ� ProgressBar ���� ���� ȭ�鿡 �����ֱ� ������ ���ۼӵ� ��ü�� ������
    // ���� �Ź� ó���ʰ� �� 16KB �Ǵ� 64KB ������ ��� ó���Ѵ�.
    // Test��� 1460B * 10ȸ�� �ѹ����� ó��, ���� ���ǿ��� ������ ó�� => ����� ������, ���⿡�� ������
    if not ((DocSize = DataSent) or (DataSent div 1460 mod 10 = 0)) then exit;

    // Http�� ������ ���������� ����� ���´�.
    Conn:= THttpConnection(Sender);
    if (Conn.Path = '/getfile.html') or (Conn.Path = '/ppt.html') then begin
        i:= Conn.Tag;
        // Memo_Out_Detail (Conn.Path + ' from ' + inttostr(i));
        if (i > 0) then begin
            // ����% �� ProgressBar�� ���۷� �ø���
            cl[i].ProgressTotalSent (DocSize, DataSent);

            // Memo_Out_Detail (
            // Format('i=%d, DocSize=%d, DataSend=%d, FLastSent=%d, Delta=%d, TotalSent=%d, TotalSize=%d, ProgPos=%d, ProgMax=%d',
            //  [i, DocSize, DataSent, FLastSent, Delta, c.TotalSent, c.TotalSize, c.Bar.Position, c.Bar.Max]));
        end;
    end;
end;





// ----------------------------------------------------------------------------
// ���⼭���� Socket �����Լ�
// ----------------------------------------------------------------------------

procedure TMainForm1.Server1ClientError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
    Memo_Out_Detail ('Socket���� Exception �߻�');
    ErrorCode:= 0;    // ���̻� Exception�� �߻����� �ʰ� �Ѵ�
    Server1ClientDisconnect (Sender, Socket);
end;

procedure TMainForm1.Server1ClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
var
    cl: TClient;
begin
    // �̸� ����ص� Socket.Data�� ���� � ������ �˾Ƴ���
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
    // Client�� ù �����ϸ� ����� �����´�
    s:= Socket.ReceiveText;
    // Memo_Out_Detail ('����: ' + s);

    // 15�ʸ��� ����Ȯ�ο�
    if (s = 'HellO') then begin
        Socket.SendText ('GooD');
        if (Socket.Data <> nil) then
        SetItem_On (TClient(Socket.Data).li, true);
    end

    // ���� �����: num=1&mac=AABB99887766 ó�� ���´�
    else if (Copy(s,1,4) = 'num=') then begin
        Parse_Parameter (s, i, mac, album);
        // if not (i in [1..clMax]) then exit;
        if (i <= 0) or (i > clMAX) then exit;    // ��ȣ�� ��ȿ�� �˻�
        if (cl[i] = nil) then exit;

        // ���� ������ �����Ѵ�
        // if (mac > '') then ..... mac='HellO'�� �����⵵ �Ѵ�!
        if (length(mac)=12) then cl[i].MacAddr:= mac;
        cl[i].IpAddr:= Socket.RemoteAddress;
        cl[i].Socket:= Socket;
        Socket.Data:= cl[i];
        SaveToIniFile;

        // i�� Client�� ��� ������ ǥ��
        SetItem_On (i, true);
        // �ٹ� ����� ǥ��
        cl[i].li.SubItems[1]:= album;
        Memo_Out_Detail (inttostr(i)+'�� '+cl[i].Name+'�� �����: '+album);
    end

    // Client���� Album ����¸� �뺸�ؿ�
    else if (Copy(s,1,11)='AlbumState=') then begin
        if (Socket.Data <> nil) then begin
            // album:= Copy (s, 12, 99);
            Delete (s,1,11);
            c:= TClient(Socket.Data);
            c.li.SubItems[1]:= s;
            Memo_Out_Detail (inttostr(c.Number)+'�� '+c.Name+'�� �����: '+s);
        end;
    end

    // GetFilesClient���� �޾ƾ��� �ѿ뷮�� Server�� �뺸
    else if (Copy(s,1,10)='TotalSize=') then begin
        if (Socket.Data <> nil) then begin
            // �ش� Client�� �ѿ뷮�� �����Ѵ�
            Delete (s,1,10);
            ts:= strtoint64 (s, 0);
            c:= TClient(Socket.Data);
            c.TotalSize:= ts;
            Memo_Out_Detail (inttostr(c.Number)+'�� '+c.Name+'�� ���� �ѿ뷮: '+inttostr3(ts));
        end;
    end;
end;




// ----------------------------------------------------------------------------
// ���⼭���� ListView �����Լ�
// ----------------------------------------------------------------------------

procedure TMainForm1.ListView1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    item: TListItem;
begin
    // item�� Check�ϸ� Select�ǰ� �Ѵ�
    item:= ListView1.GetItemAt (X, Y);
    if (item <> nil) then item.Selected:= item.Checked;
end;

procedure TMainForm1.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
    // Item �����ϸ� CheckBox�� �Բ� Check�ǰ� �Ѵ�.
    Item.Checked:= Selected;
end;

procedure TListView.WndProc(var Message: TMessage);
begin
    inherited;
    case Message.Msg of
        WM_VSCROLL: begin
            // ListView�� Scroll�� ������ ���� Event�� => MainForm���� ó���� �ְ��ߴ�
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
    // Column ũ�⸦ ������ ������ ProgressBar ��ġ�� ��� �Ű��ش�
    // ComCtrls.pas ����: Column ũ�⸦ �����Ҷ� Event�� �ϳ� �߻����� ����� �����ߴ�
    // Event Handler�� ���� ������ ������ �����Ƽ� OnColumnDragged�� Ȱ���Ͽ���

    // ����� Column���� Width�� ��� ���Ѵ�
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
    // ListView�� ���� ��ũ���ϸ� ProgressBar�� ��ġ�� �Ű��ش�
    // Event Handler�� ���� ������ ������ �����Ƽ� OnDataHint�� Ȱ���Ͽ���
    for i:= 1 to clMax do begin
        cl[i].Bar.Top:= cl[i].li.Position.Y + 2;
        cl[i].Bar.Visible:= (cl[i].Bar.Top > 15);
    end;
end;

end.

