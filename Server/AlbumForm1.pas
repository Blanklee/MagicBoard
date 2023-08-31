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
// ���⼭���� �ʱ�ȭ �� ������� �Լ�
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
// ���⼭���� Private �� Public �Լ�
// ----------------------------------------------------------------------------

function TAlbumForm.Parse_GroupName (s: string): string;
begin
	// '[�׷�1]' ó�� ������ []�� ����'�׷�1'ó�� return�Ѵ�
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
    // ����� List�� ������ �ҷ��´�
    if (AFileName = '') then AFileName:= FolderName+AlbumFileName;
    if not FileExists (AFileName) then exit;
    st:= TStringList.Create;

    // ���� �׸��� ��� Clear��Ų��
    FFileList.Clear;
    for i:= TreeView1.Items.Count-1 downto 2 do
    TreeView1.Items[i].Delete;
    CurNode:= TreeView1.Items[1];

    try
        st.LoadFromFile (AFileName);
        if (st.Count < 4) then exit;

        // ������ �ϳ��� �������鼭 ���� ���������� Update�Ѵ�
        i:= 0;
        repeat
            // Trial ������ ���ϰ����� ������ �Ѽ��ִ�
            if (TrialVersion = 'Trial') then
            if (FFileList.Count >= 5) then begin
                if (Tag = 0) then	// �ѹ��� ����Ѵ�
                ShowMessage ('Trial Version �Դϴ�.'#13#10'������ 5���� ������ �ֽ��ϴ�.');
                Tag:= 1; exit;
            end;

            s:= trim(st[i]); st.Delete(0);
            if (s[1]='/') then continue

            // ��¥ �ð� => TreeView�� �߰�
            else if (s[1]='[') then begin
                CurNode:= TreeView1.Items.AddChild (FirstNode, Parse_GroupName(s));
            end

            // ���������� FileList�� �߰�
            else begin
                New (p);
                p^.FileName:= s;
                p^.FileSize:= File_Size (s, 0);
                p^.DateTime:= File_Age (s);
                p^.PlayTime:= strtoint32 (st[2], 0);
                p^.GroupNode:= CurNode;
                FFileList.Add (p);

                // ó�� �Ϸ�� ������ ������ ������
                st.Delete(0);
                st.Delete(0);
                st.Delete(0);
            end;
        until (st.Count = 0);
    finally
        st.Free;
        UpdateTotalSize;
        // ListView�� Update�� �ش�
        CurNode:= FirstNode;
        TreeView1Change (Self, TreeView1.Items[1]);
        // [�⺻���]�� ������ �ش�
        TreeView1.Items[1].Selected:= true;
        CurNode:= TreeView1.Items[1];
    end;

    // Tree�� ��� ��ģ��
    FirstNode.Expanded:= true;
end;

procedure TAlbumForm.AddFileToList (ANode: TTreeNode; AFileName: string);
var
    p: PFileItem;
    fKind: TFileKind;
begin
	// Trial ������ ���ϰ����� ������ �Ѽ��ִ�
	if (TrialVersion = 'Trial') then
	if (FFileList.Count >= 5) then begin
		if (Tag = 0) then	// �ѹ��� ����Ѵ�
		ShowMessage ('Trial Version �Դϴ�.'#13#10'������ 5���� ������ �ֽ��ϴ�.');
		Tag:= 1; exit;
	end;

    // Note �̼��� or �ֻ��� Node���� �߰��Ҽ� ����
    if (ANode = nil) then exit;
    if (ANode.AbsoluteIndex = 0) then exit;

    // if File_Size (AFileName) > 0 then
    // if Ȯ���ڰ� jpg wmv ppt ���� �̵���� ���� �߰��Ѵ�
    fKind:= FileKind (AFileName);
    if (fKind in [img, avi, ppt]) then begin
        // ���������� FileList�� �߰�
        New (p);
        p^.FileName:= AFileName;
        p^.FileSize:= File_Size (AFileName, 0);
        p^.DateTime:= File_Age (AFileName);
		p^.PlayTime:= 0;
        p^.GroupNode:= ANode;
        FFileList.Add (p);

		// �⺻ ����ð� ����
        if (fKind = img) then p^.PlayTime:= UpDown4.Position;
        if (fKind = ppt) then p^.PlayTime:= 30;

        // ListView�� item�� �߰��Ѵ�
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
    // if Ȯ���ڰ� jpg wmv ppt ���� �̵���� ���� �߰��Ѵ�
    fKind:= FileKind (p^.FileName);
    if (fKind in [img, avi, ppt]) then begin
        // ListView�� item�� �߰��Ѵ�
        item:= ListView1.Items.Add;
        item.Data:= p;	// ���� �Ŵ޾� �д�

        // Ȯ���ڿ� ���� icon�� �ٸ��� �ش�
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

        // �̵�� ���� ǥ��
        item.Caption:= ExtractFileName (p^.FileName);
        if (fKind = img) then item.SubItems.Add ('�̹���');
        if (fKind = avi) then item.SubItems.Add ('������');
        if (fKind = ppt) then item.SubItems.Add ('PPT');
        item.SubItems.Add (inttostr3(p^.FileSize));

        // ������ ����ð��� �׻� �ǽð� Update
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

        // �̹��� �� PPT ����ð� ǥ��
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
	// ���ϰ��� �� �ѿ뷮 ������Ʈ
    FileCount:= 0;
    FTotalSize:= 0;

    for i:= 1 to FFileList.Count do begin
        p:= FFileList.PFileItems[i-1];
        // ���ʿ� ���� �����̸��� �ִ��� Ȯ��
        Dupl:= false;
        for j:= 1 to (i-1) do begin
            q:= FFileList.PFileItems[j-1];
            if (p^.FileName = q^.FileName) then Dupl:= true;
        end;
        // ������ �������� Size�� �ջ�
        if not Dupl then begin
            FTotalSize:= FTotalSize + p^.FileSize;
            FileCount:= FileCount + 1;
        end;
    end;

	labelTotalNum.Caption:= inttostr(FileCount);
	labelTotalSize.Caption:= inttostr3(FTotalSize);
end;






// ----------------------------------------------------------------------------
// ���⼭���� Button Click �� �⺻ Event �Լ�
// ----------------------------------------------------------------------------

procedure TAlbumForm.buttonHelpClick(Sender: TObject);
var
    s: string;
begin
    s:=
    '���� ���ϵ��� �߰��Ϸ��� [�����߰�] ��ư�� Ŭ���ϰų� Insert Ű�� ��������.'#13#13#10 +
    '���� Ž���⿡�� ���ϵ��� Drag && Drop �Ͽ� �߰��� �� �ֽ��ϴ�.'#13#13#13#10 +
    '�������� ������ ���콺�� ������ �Ǹ�, Ctrl Ű�� Shift Ű�� ������ �ϳ��� Ŭ���ص� �˴ϴ�.'#13#13#10 +
    '������ �ٲٷ��� ���ϼ����� Ctrl+�� �Ǵ� Ctrl+�� Ű�� ��������.'#13#13#10 +
    '�ʿ���� ������ Delete Ű�� ������ ��Ͽ��� �����ϼ���.(���������� �����ȵ�)'#13#13#13#10 +
    '���콺 ������ư Ŭ���ϸ� �˾��޴��� ��Ÿ���ϴ�.'#13#13#10;
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
    // �׸��� �����Ѵ�. ���� ������ �������� �ʴ´�.
    if (ListView1.SelCount = 0) then exit;

    for i:= (ListView1.Items.Count-1) downto 0 do
    if (ListView1.Items[i].Selected) then begin
        p:= ListView1.Items[i].Data;
        FFileList.Delete (FFileList.IndexOf(p));
        Dispose (p);
        // �׸��� �����Ѵ�
        ListView1.Items.Delete(i);
    end;

	// ���ϰ����� �ѿ뷮 ������Ʈ
    UpdateTotalSize;
    // ������ ��� UnSelect�Ǵµ� ����ġ 1���� Select���� �ش� (Space Bar�� �����ش�)
    PostMessage (ListView1.Handle, WM_KEYDOWN, VK_SPACE, 0);
end;

procedure TAlbumForm.buttonSaveClick(Sender: TObject);
var
    i, g: integer;
    ANode: TTreeNode;
    st: TStringList;
    p: PFileItem;
begin
    // �ۼ��ߴ� ������ List ���Ϸ� �����Ѵ�
    st:= TStringList.Create;

    // FileList�� ������ StringList�� ����
    for g:= 1 to TreeView1.Items.Count-1 do begin   // g = AbsoluteIndex
        // [��¥ �ð�] ����: g=1�� "�⺻���" ��, �׳� �Ǿտ� �����Ѵ�
        if (g > 1) then st.Add ('[' + TreeView1.Items[g].Text + ']');
        ANode:= TreeView1.Items[g];

        // ������ [��¥] (�ð�) ���� FileItem�� ����
        for i:= 1 to FFileList.Count do begin
            p:= FFileList[i-1];
            if (p^.GroupNode = ANode) then begin
                // �׻� ������ �������� ���� �����Ƿ� ����ũ��,��¥�� �ѹ� Update���ش�
                p^.FileSize:= File_Size (p^.FileName, 0);
                p^.DateTime:= File_Age (p^.FileName);
                // 1�� ���ϴ� 4�پ� ����Ѵ�
                st.Add (p^.FileName);
                st.Add (inttostr(p^.FileSize));
                st.Add (inttostr(p^.DateTime));
                st.Add (inttostr(p^.PlayTime));
            end;
        end;
    end;

    try
        // List ���Ϸ� �����Ѵ�
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
    // [x] [y] �׸��� ���� �ٲ�ġ�� �Ѵ�
    ListView1.Items.BeginUpdate;
    // Assign���� ���簡 �ȵǴ°�: Selected ���δ� ����ó��
    sx:= ListView1.Items[x].Selected;
    sy:= ListView1.Items[y].Selected;

    // Items[]:= �Լ��� Assign�� ȣ���ϹǷ� Object�� ����� �ؾ��Ѵ�
    ix:= TListItem.Create (ListView1.Items);
    iy:= TListItem.Create (ListView1.Items);
    ix.Assign (ListView1.Items[x]);		// ��Copy �����´�
    iy.Assign (ListView1.Items[y]);		// ��Copy �����´�
    ListView1.Items[x]:= iy;	// ��� �����δ� Assign �ۿ��� ��
    ListView1.Items[y]:= ix;	// ��� �����δ� Assign �ۿ��� ��

    // Selected ���θ� �ٲ�ġ���� �ش�
    ListView1.Items[x].Selected:= sy;
    ListView1.Items[y].Selected:= sx;
    ListView1.Items.EndUpdate;

    // FFileList���� �ٲ� ������ �ݿ��� �ش�
    i:= FFileList.IndexOf (ix.Data);
    j:= FFileList.IndexOf (iy.Data);
    p:= FFileList.Items[i];
    FFileList.Items[i]:= FFileList.Items[j];
    FFileList.Items[j]:= p;

    // Object�� Free��Ų��
    ix.Free;
    iy.Free;
end;

procedure TAlbumForm.menuMoveUpClick(Sender: TObject);
var
    i: integer;
begin
    // ���õ� �׸���� ���� �̵�
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
    // ���õ� �׸���� �Ʒ��� �̵�
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
// ���⼭���� ��Ÿ Event �Լ�
// ----------------------------------------------------------------------------

procedure TAlbumForm.cbPreviewClick(Sender: TObject);
begin
    // ����⸸ ó���� �ش�
    // �����ֱ�� ���������� Ŭ���� �ڵ����� ��Ÿ����
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

    // JPG ���Ͽ� ��� ������ �ش�
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
    // �߸��� ���ڸ� �Է��ϸ� UpDown�� ������ ������ �ش�
    if (Sender = editHH) then editHH.Text:= inttostr (strtoint32 (editHH.Text, UpDown1.Position));
    if (Sender = editMM) then editMM.Text:= inttostr (strtoint32 (editMM.Text, UpDown2.Position));
    if (Sender = editSS) then editSS.Text:= inttostr (strtoint32 (editSS.Text, UpDown3.Position));
    // �̵�� �ð��� �ݿ��� �ش�
    UpDown1Click (Sender, btNext);
end;

procedure TAlbumForm.UpDown1Click(Sender: TObject; Button: TUDBtnType);
var
    i: integer;
    p: PFileItem;
begin
    // 01:03:45 �������� ������ �Ѵ� (���ڴ� ���ڸ���)
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
// ���⼭���� ListView�� Event �Լ�
// ----------------------------------------------------------------------------

procedure TAlbumForm.cbSelectAllClick(Sender: TObject);
var
    i: integer;
begin
    // ListView�� �׸�� ��μ��� or �������
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
// ���⼭���� TreeView �����Լ�
// ----------------------------------------------------------------------------

procedure TAlbumForm.InitTreeView;
begin
    FirstNode:= TreeView1.Items.GetFirstNode;
    CurNode:= TreeView1.Items.AddChild (FirstNode, '[�⺻���]');
    FirstNode.Expand (true);
end;

function TAlbumForm.FindTreeNode (ANode: TTreeNode; Text: string): TTreeNode;
var
    i: integer;
begin
    // ANode �Ʒ��� ���� Text�� ã�´�
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

    // TreeNode ������ ����
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
    // �Ϲݱ׷��� ������ �����ϵ��� ���
    if (Node.AbsoluteIndex <= 1) then TreeView1.ReadOnly:= true
    else TreeView1.ReadOnly:= false;

    // �ٸ� Node�� �������� ���� ó��
    if (Node = CurNode) then exit;
    CurNode:= Node;

    cbSelectAll.Checked:= false;
    ListView1.Clear;
  	for i:= 1 to FFileList.Count do begin
        // �ش� Group�̸� ListView�� Add
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

    // ���� Node �Ǵ� �ֻ��� Node�δ� Drop�Ұ�
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
        // ��� Node�� Drop�ƴ���
        ANode:= TreeView1.DropTarget;
        if (ANode = nil) then exit;

        // ���õ� ListItem���� �ϳ��� Group����
        for i:= 1 to ListView1.Items.Count do begin
            item:= ListView1.Items[i-1];
            if (item.Selected) then begin
                // �׷��� �ٲپ� �ش�
                p:= item.Data;
                p^.GroupNode:= ANode;
                // p�� �ǵڷ� �Ű��ش� (���׷��� ���� Item�麸�� ���ʿ� �߰��� �ش�)
                FFileList.Move (FFileList.IndexOf(p), FFileList.Count-1);
            end;
        end;

        // ���õ� ListItem���� Delete�Ѵ�
        for i:= ListView1.Items.Count downto 1 do begin
            item:= ListView1.Items[i-1];
            if item.Selected then item.Delete;
        end;

        // ANode.Selected:= true;	// ��� Node�� ����
        TreeView1.SetFocus;
    end;
end;

procedure TAlbumForm.TreeView1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
    ANode: TTreeNode;
begin
    // �˾��޴� Ŭ���� ����� ó���ϱ� ����
    if (Button = mbRight) then begin
        ANode:= TreeView1.GetNodeAt(X, Y);
        if (ANode <> nil) then ANode.Selected:= true;

        // "��ü" �׷��� ���� ������ �Ұ���
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
    // Text �������̸� ����ó�� ����
    // if ANode.EditText then exit; .....> �̻��ϰ� ��
    // if NodeEditing then Memo1.Lines.Add ('���⼭ True') else Memo1.Lines.Add ('���⼭ False');
    if NodeEditing then exit;

    // �⺻��� �׷��� �����Ұ�
    if (ANode.AbsoluteIndex <= 1) then exit;

    // �ش� ListItem�� ������ ��� ���ư��ٰ� ����� �Բ�����
    if (ListView1.Items.Count = 0) then
        ANode.Delete
    else if MessageDlg (#13#10'�ش� ���ϸ���� �Բ� ���ŵ˴ϴ�', mtWarning, mbOkCancel, 0) = mrOk then begin
        // �ش� Items ��� ����
        for i:= FFileList.Count downto 1 do
            if (FFileList.FileItems[i-1].GroupNode = ANode) then
            FFileList.DeleteItem (i-1);

        // TreeNode ����
        ListView1.Clear;
        ANode.Delete;
    end;
end;

end.

