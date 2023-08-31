unit AlbumForm1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, FileDrop, ExtCtrls, ExtDlgs, BlankUtils,
  ImgList, jpeg, Menus, ShellApi, Globals, OleCtrls, WMPLib_TLB, Mask,
  Buttons, FileList;

type
  TAlbumForm = class(TForm)
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    Label1: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    labelTotalNum: TLabel;
    labelTotalSize: TLabel;
    buttonHelp: TButton;
    buttonOpen: TButton;
    buttonDelete: TButton;
    buttonSave: TButton;
    buttonOk: TButton;
    buttonCancel: TButton;
    PopupMenu1: TPopupMenu;
    menuDelete: TMenuItem;
    menuMoveUp: TMenuItem;
    menuMoveDown: TMenuItem;
    FileDrop1: TFileDrop;
    OpenDialog1: TOpenDialog;
    ImageList1: TImageList;
    cbPreview: TCheckBox;
    Image1: TImage;
    ImagePpt: TImage;
    WMP1: TWindowsMediaPlayer;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel7: TPanel;
    PanelPpt: TPanel;
    editJpg: TEdit;
    editHH: TEdit;
    editMM: TEdit;
    editSS: TEdit;
    UpDown1: TUpDown;
    UpDown2: TUpDown;
    UpDown3: TUpDown;
    UpDown4: TUpDown;
    TreeView1: TTreeView;
    ListView1: TListView;
    Splitter1: TSplitter;
    cbSelectAll: TCheckBox;
    DatePicker1: TDateTimePicker;
    TimePicker1: TDateTimePicker;
    sbAdd1: TSpeedButton;
    PopupMenu2: TPopupMenu;
    pmenuRenameGroup: TMenuItem;
    pmenuDeleteGroup: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure buttonHelpClick(Sender: TObject);
    procedure FileDrop1Drop(Sender: TObject);
    procedure buttonOpenClick(Sender: TObject);
    procedure buttonDeleteClick(Sender: TObject);
    procedure buttonSaveClick(Sender: TObject);
    procedure menuMoveUpClick(Sender: TObject);
    procedure menuMoveDownClick(Sender: TObject);
    procedure cbSelectAllClick(Sender: TObject);
    procedure ListView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure ListView1DblClick(Sender: TObject);
    procedure cbPreviewClick(Sender: TObject);
    procedure editJpgChange(Sender: TObject);
    procedure editSSChange(Sender: TObject);
    procedure UpDown1Click(Sender: TObject; Button: TUDBtnType);
    procedure sbAdd1Click(Sender: TObject);
    procedure TreeView1Collapsing(Sender: TObject; Node: TTreeNode; var AllowCollapse: Boolean);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure TreeView1DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure TreeView1DragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure TreeView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeView1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TreeView1Editing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
    procedure TreeView1Edited(Sender: TObject; Node: TTreeNode; var S: String);
    procedure TreeView1CancelEdit (Sender: TObject; Node: TTreeNode);
    procedure pmenuRenameGroupClick(Sender: TObject);
    procedure pmenuDeleteGroupClick(Sender: TObject);
  private
    FTotalSize: int64;
    FFileList: TFileList;
    CurNode, FirstNode: TTreeNode;
    NodeEditing: boolean;
    function Parse_GroupName (s: string): string;
    procedure AddFileToList (ANode: TTreeNode; AFileName: string);
    procedure AddToListView (p: PFileItem);
    procedure UpdateTotalSize;
    procedure ExchangeItem (x, y: integer);
    procedure InitTreeView;
    function FindTreeNode (ANode: TTreeNode; Text: string): TTreeNode;
    procedure DeleteTreeNode (ANode: TTreeNode);
  public
    property TotalSize: int64 read FTotalSize;
    procedure LoadFromAlbumListFile (AFileName: string='');
  end;

var
  AlbumForm: TAlbumForm;

implementation


{$R *.dfm}


// ----------------------------------------------------------------------------
// 여기서부터 초기화 및 종료관련 함수
// ----------------------------------------------------------------------------

procedure TAlbumForm.FormCreate(Sender: TObject);
begin
    FTotalSize:= 0;
    DatePicker1.Date:= now;
    InitTreeView;
    FFileList:= TFileList.Create;
//  LoadFromAlbumListFile;
    NodeEditing:= false;
    TreeView1.OnCancelEdit:= TreeView1CancelEdit;
end;

procedure TAlbumForm.FormDestroy(Sender: TObject);
begin
    FFileList.Free;
end;

procedure TAlbumForm.FormHide(Sender: TObject);
begin
    WMP1.Close;
end;



// ----------------------------------------------------------------------------
// 여기서부터 Private 및 Public 함수
// ----------------------------------------------------------------------------

function TAlbumForm.Parse_GroupName (s: string): string;
begin
	// '[그룹1]' 처럼 들어오면 []를 떼고'그룹1'처럼 return한다
	Result:= '';
	if (length(s) < 2) then exit;
	if (s[1]='[') or (s[1]='(') then begin
    	Delete (s, 1, 1);
	    Delete (s, Pos(']',s), 99);
	    Delete (s, Pos(')',s), 99);
    	Result:= s;
    end;
end;

procedure TAlbumForm.LoadFromAlbumListFile (AFileName: string='');
var
    i: integer;
    s: string;
    st: TStringList;
    p: PFileItem;
begin
    // 저장된 List가 있으면 불러온다
    if (AFileName = '') then AFileName:= FolderName+AlbumFileName;
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    // 기존 항목을 모두 Clear시킨다
    FFileList.Clear;
    for i:= TreeView1.Items.Count-1 downto 2 do
    TreeView1.Items[i].Delete;
    CurNode:= TreeView1.Items[1];

    try
        st.LoadFromFile (AFileName);
        if (st.Count < 4) then exit;

        // 파일을 하나씩 가져오면서 실제 파일정보로 Update한다
        i:= 0;
        repeat
            // Trial 버전은 파일갯수에 제한을 둘수있다
            if (TrialVersion = 'Trial') then
            if (FFileList.Count >= 5) then begin
                if (Tag = 0) then	// 한번만 출력한다
                ShowMessage ('Trial Version 입니다.'#13#10'파일을 5개만 넣을수 있습니다.');
                Tag:= 1; exit;
            end;

            s:= trim(st[i]); st.Delete(0);
            if (s[1]='/') then continue

            // 날짜 시각 => TreeView에 추가
            else if (s[1]='[') then begin
                CurNode:= TreeView1.Items.AddChild (FirstNode, Parse_GroupName(s));
            end

            // 파일정보를 FileList에 추가
            else begin
                New (p);
                p^.FileName:= s;
                p^.FileSize:= File_Size (s, 0);
                p^.DateTime:= File_Age (s);
                p^.PlayTime:= strtoint32 (st[2], 0);
                p^.GroupNode:= CurNode;
                FFileList.Add (p);

                // 처리 완료된 정보는 삭제해 버린다
                st.Delete(0);
                st.Delete(0);
                st.Delete(0);
            end;
        until (st.Count = 0);
    finally
        st.Free;
        UpdateTotalSize;
        // ListView를 Update해 준다
        CurNode:= FirstNode;
        TreeView1Change (Self, TreeView1.Items[1]);
        // [기본재생]을 선택해 준다
        TreeView1.Items[1].Selected:= true;
        CurNode:= TreeView1.Items[1];
    end;

    // Tree를 모두 펼친다
    FirstNode.Expanded:= true;
end;

procedure TAlbumForm.AddFileToList (ANode: TTreeNode; AFileName: string);
var
    p: PFileItem;
    fKind: TFileKind;
begin
	// Trial 버전은 파일갯수에 제한을 둘수있다
	if (TrialVersion = 'Trial') then
	if (FFileList.Count >= 5) then begin
		if (Tag = 0) then	// 한번만 출력한다
		ShowMessage ('Trial Version 입니다.'#13#10'파일을 5개만 넣을수 있습니다.');
		Tag:= 1; exit;
	end;

    // Note 미선택 or 최상위 Node에는 추가할수 없음
    if (ANode = nil) then exit;
    if (ANode.AbsoluteIndex = 0) then exit;

    // if File_Size (AFileName) > 0 then
    // if 확장자가 jpg wmv ppt 등의 미디어일 때만 추가한다
    fKind:= FileKind (AFileName);
    if (fKind in [img, avi, ppt]) then begin
        // 파일정보를 FileList에 추가
        New (p);
        p^.FileName:= AFileName;
        p^.FileSize:= File_Size (AFileName, 0);
        p^.DateTime:= File_Age (AFileName);
		p^.PlayTime:= 0;
        p^.GroupNode:= ANode;
        FFileList.Add (p);

		// 기본 재생시간 설정
        if (fKind = img) then p^.PlayTime:= UpDown4.Position;
        if (fKind = ppt) then p^.PlayTime:= 30;

        // ListView에 item을 추가한다
        AddToListView (p);
    end;
end;

procedure TAlbumForm.AddToListView (p: PFileItem);
var
    t: integer;
    ext, ptime: string;
    item: TListItem;
    fKind: TFileKind;
begin
    // if 확장자가 jpg wmv ppt 등의 미디어일 때만 추가한다
    fKind:= FileKind (p^.FileName);
    if (fKind in [img, avi, ppt]) then begin
        // ListView에 item을 추가한다
        item:= ListView1.Items.Add;
        item.Data:= p;	// 여기 매달아 둔다

        // 확장자에 따라 icon을 다르게 준다
        ext:= UpperCase (ExtractFileExt (p^.FileName));
        if (fKind = img) then begin
            item.ImageIndex:= 0;
            if (ext='.JPG')  then item.ImageIndex:= 4;
            if (ext='.JPEG') then item.ImageIndex:= 4;
            if (ext='.BMP')  then item.ImageIndex:= 1;
            if (ext='.WMF')  then item.ImageIndex:= 2;
        end;
        if (fKind = avi) then item.ImageIndex:= 5;
        if (fKind = ppt) then begin
            item.ImageIndex:= 7;
            if (ext='.PPT')  then item.ImageIndex:= 6;
        end;

        // 미디어 종류 표시
        item.Caption:= ExtractFileName (p^.FileName);
        if (fKind = img) then item.SubItems.Add ('이미지');
        if (fKind = avi) then item.SubItems.Add ('동영상');
        if (fKind = ppt) then item.SubItems.Add ('PPT');
        item.SubItems.Add (inttostr3(p^.FileSize));

        // 동영상 재생시간은 항상 실시간 Update
        if (fKind = avi) then
        if File_Exists (p^.FileName) then
        try
            WMP1.currentPlayList.appendItem (WMP1.mediaCollection.add (p^.FileName));
            WMP1.controls.currentItem:= WMP1.currentPlaylist.Item[0];
            ptime:= WMP1.currentMedia.durationString;
            WMP1.currentPlaylist.clear;
        except
            ptime:= '--:--';
        end;

        // 이미지 및 PPT 재생시간 표시
        t:= p^.PlayTime;
        if (fKind = img) then
            ptime:= Format ('%0.2d:%0.2d', [t div 60, t mod 60])
        else if (fKind = ppt) then
            ptime:= Format ('%0.2d:%0.2d:%0.2d', [t div 3600, (t mod 3600) div 60, t mod 60]);

        if (p^.FileSize <= 0) then ptime:= '--:--';
        item.SubItems.Add (ptime);
    end;
end;

procedure TAlbumForm.UpdateTotalSize;
var
    i,j: integer;
    Dupl: boolean;
    p,q: PFileItem;
    FileCount: integer;
begin
	// 파일갯수 및 총용량 업데이트
    FileCount:= 0;
    FTotalSize:= 0;

    for i:= 1 to FFileList.Count do begin
        p:= FFileList.PFileItems[i-1];
        // 앞쪽에 같은 파일이름이 있는지 확인
        Dupl:= false;
        for j:= 1 to (i-1) do begin
            q:= FFileList.PFileItems[j-1];
            if (p^.FileName = q^.FileName) then Dupl:= true;
        end;
        // 같은게 없었으면 Size에 합산
        if not Dupl then begin
            FTotalSize:= FTotalSize + p^.FileSize;
            FileCount:= FileCount + 1;
        end;
    end;

	labelTotalNum.Caption:= inttostr(FileCount);
	labelTotalSize.Caption:= inttostr3(FTotalSize);
end;






// ----------------------------------------------------------------------------
// 여기서부터 Button Click 및 기본 Event 함수
// ----------------------------------------------------------------------------

procedure TAlbumForm.buttonHelpClick(Sender: TObject);
var
    s: string;
begin
    s:=
    '보낼 파일들을 추가하려면 [파일추가] 버튼을 클릭하거나 Insert 키를 누르세요.'#13#13#10 +
    '또한 탐색기에서 파일들을 Drag && Drop 하여 추가할 수 있습니다.'#13#13#13#10 +
    '여러파일 선택은 마우스로 긁으면 되며, Ctrl 키나 Shift 키를 누르고 하나씩 클릭해도 됩니다.'#13#13#10 +
    '순서를 바꾸려면 파일선택후 Ctrl+↑ 또는 Ctrl+↓ 키를 누르세요.'#13#13#10 +
    '필요없는 파일은 Delete 키를 눌러서 목록에서 삭제하세요.(실제파일은 삭제안됨)'#13#13#13#10 +
    '마우스 오른버튼 클릭하면 팝업메뉴가 나타납니다.'#13#13#10;
    ShowMessage (s);
end;

procedure TAlbumForm.FileDrop1Drop(Sender: TObject);
var
    i: integer;
begin
    for i:= 1 to FileDrop1.FileCount do
    AddFileToList (TreeView1.Selected, FileDrop1.Files[i-1]);

    UpdateTotalSize;
    ListView1.SetFocus;
end;

procedure TAlbumForm.buttonOpenClick(Sender: TObject);
var
    i: integer;
begin
    if (OpenDialog1.Execute) then
    for i:= 1 to OpenDialog1.Files.Count do
    AddFileToList (TreeView1.Selected, OpenDialog1.Files[i-1]);

    UpdateTotalSize;
    ListView1.SetFocus;
end;

procedure TAlbumForm.buttonDeleteClick(Sender: TObject);
var
    i: integer;
    p: PFileItem;
begin
    // 항목을 제거한다. 실제 파일은 제거하지 않는다.
    if (ListView1.SelCount = 0) then exit;

    for i:= (ListView1.Items.Count-1) downto 0 do
    if (ListView1.Items[i].Selected) then begin
        p:= ListView1.Items[i].Data;
        FFileList.Delete (FFileList.IndexOf(p));
        Dispose (p);
        // 항목을 삭제한다
        ListView1.Items.Delete(i);
    end;

	// 파일갯수와 총용량 업데이트
    UpdateTotalSize;
    // 삭제후 모두 UnSelect되는데 현위치 1개를 Select시켜 준다 (Space Bar를 눌러준다)
    PostMessage (ListView1.Handle, WM_KEYDOWN, VK_SPACE, 0);
end;

procedure TAlbumForm.buttonSaveClick(Sender: TObject);
var
    i, g: integer;
    ANode: TTreeNode;
    st: TStringList;
    p: PFileItem;
begin
    // 작성했던 내용을 List 파일로 저장한다
    st:= TStringList.Create;

    // FileList의 내용을 StringList로 저장
    for g:= 1 to TreeView1.Items.Count-1 do begin   // g = AbsoluteIndex
        // [날짜 시간] 저장: g=1은 "기본재생" 임, 그냥 맨앞에 저장한다
        if (g > 1) then st.Add ('[' + TreeView1.Items[g].Text + ']');
        ANode:= TreeView1.Items[g];

        // 각각의 [날짜] (시간) 별로 FileItem을 저장
        for i:= 1 to FFileList.Count do begin
            p:= FFileList[i-1];
            if (p^.GroupNode = ANode) then begin
                // 그새 파일을 수정했을 수도 있으므로 파일크기,날짜를 한번 Update해준다
                p^.FileSize:= File_Size (p^.FileName, 0);
                p^.DateTime:= File_Age (p^.FileName);
                // 1개 파일당 4줄씩 기록한다
                st.Add (p^.FileName);
                st.Add (inttostr(p^.FileSize));
                st.Add (inttostr(p^.DateTime));
                st.Add (inttostr(p^.PlayTime));
            end;
        end;
    end;

    try
        // List 파일로 저장한다
        st.SaveToFile (FolderName+AlbumFileName);
    finally
        st.Free;
    end;
end;

procedure TAlbumForm.ExchangeItem (x, y: integer);
var
    ix, iy: TListItem;
    sx, sy: boolean;
    i, j: integer;
    p: Pointer;
begin
    // [x] [y] 항목을 서로 바꿔치기 한다
    ListView1.Items.BeginUpdate;
    // Assign에서 복사가 안되는것: Selected 여부는 별도처리
    sx:= ListView1.Items[x].Selected;
    sy:= ListView1.Items[y].Selected;

    // Items[]:= 함수가 Assign을 호출하므로 Object를 만들어 해야한다
    ix:= TListItem.Create (ListView1.Items);
    iy:= TListItem.Create (ListView1.Items);
    ix.Assign (ListView1.Items[x]);		// 한Copy 떠놓는다
    iy.Assign (ListView1.Items[y]);		// 한Copy 떠놓는다
    ListView1.Items[x]:= iy;	// 요게 실제로는 Assign 작용을 함
    ListView1.Items[y]:= ix;	// 요게 실제로는 Assign 작용을 함

    // Selected 여부를 바꿔치기해 준다
    ListView1.Items[x].Selected:= sy;
    ListView1.Items[y].Selected:= sx;
    ListView1.Items.EndUpdate;

    // FFileList에도 바뀐 순서를 반영해 준다
    i:= FFileList.IndexOf (ix.Data);
    j:= FFileList.IndexOf (iy.Data);
    p:= FFileList.Items[i];
    FFileList.Items[i]:= FFileList.Items[j];
    FFileList.Items[j]:= p;

    // Object를 Free시킨다
    ix.Free;
    iy.Free;
end;

procedure TAlbumForm.menuMoveUpClick(Sender: TObject);
var
    i: integer;
begin
    // 선택된 항목들을 위로 이동
    if (ListView1.SelCount = 0) then exit;
    if (ListView1.Items.Count < 2) then exit;

    with ListView1 do
    for i:= 1 to (Items.Count-1) do
    if (Items[i].Selected) then
    if (Items[i-1].Selected = false) then begin
        ExchangeItem (i, i-1);
    end;
end;

procedure TAlbumForm.menuMoveDownClick(Sender: TObject);
var
    i: integer;
begin
    // 선택된 항목들을 아래로 이동
    if (ListView1.SelCount = 0) then exit;
    if (ListView1.Items.Count < 2) then exit;

    with ListView1 do
    for i:= (Items.Count-1) downto 1 do
    if (Items[i-1].Selected) then
    if (Items[i].Selected = false) then begin
        ExchangeItem (i-1, i);
    end;
end;







// ----------------------------------------------------------------------------
// 여기서부터 기타 Event 함수
// ----------------------------------------------------------------------------

procedure TAlbumForm.cbPreviewClick(Sender: TObject);
begin
    // 숨기기만 처리해 준다
    // 보여주기는 컨텐츠파일 클릭시 자동으로 나타난다
    if (cbPreview.Checked = false) then begin
        WMP1.close;
        WMP1.Hide;
        Image1.Hide;
        ImagePpt.Hide;
    end;
end;

procedure TAlbumForm.editJpgChange(Sender: TObject);
var
    i,t: integer;
    p: PFileItem;
begin
    t:= strtoint32 (editJpg.Text, 5);
    UpDown4.Position:= t;

    // JPG 파일에 모두 적용해 준다
    for i:= 1 to ListView1.Items.Count do
    if ListView1.Items[i-1].Selected then begin
        p:= ListView1.Items[i-1].Data;
        if (FileKind(p^.FileName) <> img) then continue;
        if not File_Exists (p^.FileName) then continue;
        p^.PlayTime:= t;
        ListView1.Items[i-1].SubItems[2]:= Format ('%0.2d:%0.2d', [t div 60, t mod 60]);
    end;
end;

procedure TAlbumForm.editSSChange(Sender: TObject);
begin
    // 잘못된 문자를 입력하면 UpDown의 값으로 교정해 준다
    if (Sender = editHH) then editHH.Text:= inttostr (strtoint32 (editHH.Text, UpDown1.Position));
    if (Sender = editMM) then editMM.Text:= inttostr (strtoint32 (editMM.Text, UpDown2.Position));
    if (Sender = editSS) then editSS.Text:= inttostr (strtoint32 (editSS.Text, UpDown3.Position));
    // 미디어 시간에 반영해 준다
    UpDown1Click (Sender, btNext);
end;

procedure TAlbumForm.UpDown1Click(Sender: TObject; Button: TUDBtnType);
var
    i: integer;
    p: PFileItem;
begin
    // 01:03:45 형식으로 저장을 한다 (숫자는 두자릿수)
    for i:= 1 to ListView1.Items.Count do
    if ListView1.Items[i-1].Selected then begin
        p:= ListView1.Items[i-1].Data;
        if (FileKind(p^.FileName) <> ppt) then continue;
        if not File_Exists (p^.FileName) then continue;
        // p^.PlayTime:= editHH.Text+':'+editMM.Text+':'+editSS.Text;
        p^.PlayTime:= UpDown1.Position*3600 + UpDown2.Position*60 + UpDown3.Position;
        ListView1.Items[i-1].SubItems[2]:= Format ('%0.2d:%0.2d:%0.2d', [UpDown1.Position, UpDown2.Position, UpDown3.Position]);
    end;
end;






// ----------------------------------------------------------------------------
// 여기서부터 ListView의 Event 함수
// ----------------------------------------------------------------------------

procedure TAlbumForm.cbSelectAllClick(Sender: TObject);
var
    i: integer;
begin
    // ListView의 항목들 모두선택 or 모두해제
    for i:= ListView1.Items.Count downto 1 do ListView1.Items[i-1].Selected:= cbSelectAll.Checked;
    ListView1.SetFocus;
end;


procedure TAlbumForm.ListView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_DELETE) then buttonDeleteClick (Sender);
    if (Key = VK_INSERT) then buttonOpenClick (Sender);
    if (Key = VK_UP) and (Shift = [ssCtrl]) then menuMoveUpClick (Sender);
    if (Key = VK_DOWN) and (Shift = [ssCtrl]) then menuMoveDownClick (Sender);
end;


procedure TAlbumForm.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
    p: PFileItem;
    fk: TFileKind;
begin
    if (cbPreview.Checked) then
    if (Selected = false) then begin
        WMP1.close;
        WMP1.Hide;
        Image1.Hide;
        ImagePpt.Hide;
        exit;
    end;

    // Memo1.Lines.Add (item.Caption);
    // if not Selected then exit;
    if (ListView1.SelCount <> 1) then exit;

    // p:= item.Data;
    p:= ListView1.Selected.Data;
    if not File_Exists (p^.FileName) then exit;

    fk:= FileKind (p^.FileName);
    case fk of
        img: begin  // ShowImage;
            if cbPreview.Checked then Image1.Show;
            try
                if cbPreview.Checked then
                Image1.Picture.LoadFromFile (p^.FileName);
                UpDown4.Position:= p^.PlayTime;
            except
                UpDown4.Position:= 5;
            end;
        end;

        avi: if cbPreview.Checked then begin  // ShowMovie;
            WMP1.Show;
            WMP1.URL:= p^.FileName;
            WMP1.controls.play;
        end;

        ppt: begin  // ShowPpt;
            if cbPreview.Checked then ImagePpt.Show;
            UpDown1.Position:= p^.PlayTime div 3600;
            UpDown2.Position:= p^.PlayTime mod 3600 div 60;
            UpDown3.Position:= p^.PlayTime mod 60;
        end;
    end;
end;


procedure TAlbumForm.ListView1DblClick(Sender: TObject);
var
    p: PFileItem;
begin
    if (ListView1.SelCount = 0) then exit;
    p:= ListView1.Selected.Data;
    if FileKind (p^.FileName) = ppt then
    ShellExecute (0, nil, PChar('"'+p^.FileName+'"'), nil, nil, SW_NORMAL);
end;







// ----------------------------------------------------------------------------
// 여기서부터 TreeView 관련함수
// ----------------------------------------------------------------------------

procedure TAlbumForm.InitTreeView;
begin
    FirstNode:= TreeView1.Items.GetFirstNode;
    CurNode:= TreeView1.Items.AddChild (FirstNode, '[기본재생]');
    FirstNode.Expand (true);
end;

function TAlbumForm.FindTreeNode (ANode: TTreeNode; Text: string): TTreeNode;
var
    i: integer;
begin
    // ANode 아래를 뒤져 Text를 찾는다
    Result:= nil;
    for i:= 1 to ANode.Count do
    if (ANode.Item[i-1].Text = Text) then
    Result:= ANode.Item[i-1];
end;

procedure TAlbumForm.TreeView1Collapsing(Sender: TObject; Node: TTreeNode; var AllowCollapse: Boolean);
begin
    AllowCollapse:= false;
end;

procedure TAlbumForm.sbAdd1Click(Sender: TObject);
var
    d,t,s: string;
    ANode: TTreeNode;
begin
    ShortDateFormat:= 'YYYY.MM.DD';
    d:= DateToStr(DatePicker1.Date);
    ShortDateFormat:= 'HH:mm';
    t:= DateToStr(TimePicker1.Time);
    s:= d + ' ' + t;

    // TreeNode 삽입후 정렬
    if (FindTreeNode (FirstNode, s) = nil) then begin
        ANode:= TreeView1.Items.AddChild (FirstNode, s);
        TreeView1.AlphaSort;
        ANode.Selected:= true;
        TreeView1.SetFocus;
     end;
end;

procedure TAlbumForm.TreeView1Change(Sender: TObject; Node: TTreeNode);
var
    i: integer;
    p: PFileItem;
begin
    // 일반그룹은 편집이 가능하도록 허용
    if (Node.AbsoluteIndex <= 1) then TreeView1.ReadOnly:= true
    else TreeView1.ReadOnly:= false;

    // 다른 Node를 선택했을 때만 처리
    if (Node = CurNode) then exit;
    CurNode:= Node;

    cbSelectAll.Checked:= false;
    ListView1.Clear;
  	for i:= 1 to FFileList.Count do begin
        // 해당 Group이면 ListView에 Add
        p:= FFileList[i-1];
        if (Node = p^.GroupNode) then AddToListView (p);
    end;
end;

procedure TAlbumForm.TreeView1DragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var
    ANode: TTreeNode;
begin
//  Accept:= (Source is TListView) and (CurNode.DropTarget = false);
    Accept:= (Source is TListView);
    if (Accept = false) then exit;

    // 현재 Node 또는 최상위 Node로는 Drop불가
    ANode:= TreeView1.DropTarget;
    if (ANode = nil) then exit;
    if (ANode = CurNode) or (ANode = FirstNode) then Accept:= false;
end;

procedure TAlbumForm.TreeView1DragDrop(Sender, Source: TObject; X, Y: Integer);
var
    i: integer;
    ANode: TTreeNode;
    item: TListItem;
    p: PFileItem;
begin
    if (Sender = TreeView1) and (Source = ListView1) then begin
        // 어느 Node로 Drop됐는지
        ANode:= TreeView1.DropTarget;
        if (ANode = nil) then exit;

        // 선택된 ListItem들을 하나씩 Group변경
        for i:= 1 to ListView1.Items.Count do begin
            item:= ListView1.Items[i-1];
            if (item.Selected) then begin
                // 그룹을 바꾸어 준다
                p:= item.Data;
                p^.GroupNode:= ANode;
                // p를 맨뒤로 옮겨준다 (새그룹의 기존 Item들보다 뒤쪽에 추가해 준다)
                FFileList.Move (FFileList.IndexOf(p), FFileList.Count-1);
            end;
        end;

        // 선택된 ListItem들을 Delete한다
        for i:= ListView1.Items.Count downto 1 do begin
            item:= ListView1.Items[i-1];
            if item.Selected then item.Delete;
        end;

        // ANode.Selected:= true;	// 대상 Node를 선택
        TreeView1.SetFocus;
    end;
end;

procedure TAlbumForm.TreeView1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    ANode: TTreeNode;
begin
    // 팝업메뉴 클릭시 제대로 처리하기 위함
    if (Button = mbRight) then begin
        ANode:= TreeView1.GetNodeAt(X, Y);
        if (ANode <> nil) then ANode.Selected:= true;

        // "전체" 그룹은 수정 삭제가 불가능
        if (ANode = nil) or (ANode.AbsoluteIndex <= 1) then begin
            pmenuRenameGroup.Enabled:= false;
            pmenuDeleteGroup.Enabled:= false;
        end
        else begin
            pmenuRenameGroup.Enabled:= true;
            pmenuDeleteGroup.Enabled:= true;
        end;
    end;
end;

procedure TAlbumForm.pmenuRenameGroupClick(Sender: TObject);
begin
    if (CurNode <> nil) then CurNode.EditText;
end;

procedure TAlbumForm.pmenuDeleteGroupClick(Sender: TObject);
begin
    DeleteTreeNode (TreeView1.Selected);
end;

procedure TAlbumForm.TreeView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    if (Key = VK_F2) then if (CurNode <> nil) then CurNode.EditText;
    if (Key = VK_DELETE) then DeleteTreeNode (TreeView1.Selected);
end;

procedure TAlbumForm.TreeView1Editing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
begin
    NodeEditing:= true;
    buttonCancel.Cancel:= false;
    // Memo1.Lines.Add ('OnEditing: Editing = True');
end;

procedure TAlbumForm.TreeView1Edited(Sender: TObject; Node: TTreeNode; var S: String);
begin
    NodeEditing:= false;
    buttonCancel.Cancel:= true;
    // Memo1.Lines.Add ('OnEdited: Editing = False');
end;

procedure TAlbumForm.TreeView1CancelEdit (Sender: TObject; Node: TTreeNode);
begin
    NodeEditing:= false;
    buttonCancel.Cancel:= true;
    // Memo1.Lines.Add ('OnCancelEdit: Editing = False');
end;

procedure TAlbumForm.DeleteTreeNode (ANode: TTreeNode);
var
    i: integer;
begin
    // Text 편집중이면 삭제처리 안함
    // if ANode.EditText then exit; .....> 이상하게 됨
    // if NodeEditing then Memo1.Lines.Add ('여기서 True') else Memo1.Lines.Add ('여기서 False');
    if NodeEditing then exit;

    // 기본재생 그룹은 삭제불가
    if (ANode.AbsoluteIndex <= 1) then exit;

    // 해당 ListItem이 있으면 모두 날아간다고 경고후 함께삭제
    if (ListView1.Items.Count = 0) then
        ANode.Delete
    else if MessageDlg (#13#10'해당 파일목록이 함께 제거됩니다', mtWarning, mbOkCancel, 0) = mrOk then begin
        // 해당 Items 모두 삭제
        for i:= FFileList.Count downto 1 do
            if (FFileList.FileItems[i-1].GroupNode = ANode) then
            FFileList.DeleteItem (i-1);

        // TreeNode 삭제
        ListView1.Clear;
        ANode.Delete;
    end;
end;

end.

