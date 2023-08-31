object MainForm: TMainForm
  Left = 519
  Top = 177
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsNone
  Caption = #47588#51649#44172#49884#54032
  ClientHeight = 340
  ClientWidth = 670
  Color = clBtnFace
  Font.Charset = HANGEUL_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #44404#47548
  Font.Style = []
  OldCreateOrder = False
  Position = poDefault
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnMouseMove = FormMouseMove
  PixelsPerInch = 96
  TextHeight = 12
  object LogoLabel: TLabel
    Left = 384
    Top = 88
    Width = 80
    Height = 16
    Caption = #47588#51649#44172#49884#54032
    Color = clBlack
    Font.Charset = HANGEUL_CHARSET
    Font.Color = 13421772
    Font.Height = -16
    Font.Name = #44404#47548
    Font.Style = []
    ParentColor = False
    ParentFont = False
    Visible = False
  end
  object Image1: TImage
    Left = 264
    Top = 152
    Width = 81
    Height = 81
    Stretch = True
    OnMouseMove = FormMouseMove
  end
  object TrialLabel: TLabel
    Left = 384
    Top = 8
    Width = 275
    Height = 21
    Caption = '  '#47588#51649#44172#49884#54032' Trial '#48260#51204'  '
    Color = clBlack
    Font.Charset = HANGEUL_CHARSET
    Font.Color = clWhite
    Font.Height = -21
    Font.Name = #44404#47548#52404
    Font.Style = []
    ParentColor = False
    ParentFont = False
    Visible = False
  end
  object curFile: TLabel
    Left = 16
    Top = 314
    Width = 33
    Height = 13
    Caption = #54028#51068':'
    Font.Charset = HANGEUL_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = #44404#47548
    Font.Style = [fsBold]
    ParentFont = False
    Transparent = True
    Visible = False
  end
  object Memo1: TMemo
    Left = 8
    Top = 144
    Width = 241
    Height = 121
    TabStop = False
    ImeName = 'Microsoft Office IME 2007'
    Lines.Strings = (
      '[DebugMemo]')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    Visible = False
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 249
    Height = 129
    TabOrder = 0
    Visible = False
    object GroupBox1: TGroupBox
      Left = 8
      Top = 8
      Width = 233
      Height = 113
      Caption = #47588#51649#44172#49884#54032' '#49444#51221
      TabOrder = 0
      TabStop = True
      object Label1: TLabel
        Left = 16
        Top = 28
        Width = 83
        Height = 12
        Caption = #49436#48260#51032' IP '#51452#49548':'
      end
      object Label2: TLabel
        Left = 16
        Top = 52
        Width = 87
        Height = 12
        Caption = 'LFD'#48264#54840'(1~99):'
      end
      object Edit1: TEdit
        Left = 112
        Top = 24
        Width = 105
        Height = 20
        ImeName = 'Microsoft Office IME 2007'
        TabOrder = 0
      end
      object Edit2: TEdit
        Left = 112
        Top = 48
        Width = 105
        Height = 20
        ImeName = 'Microsoft Office IME 2007'
        TabOrder = 1
      end
      object saveButton: TButton
        Left = 16
        Top = 76
        Width = 89
        Height = 25
        Caption = #51200#51109' '#48143' '#48152#50689
        Default = True
        TabOrder = 2
        OnClick = saveButtonClick
      end
      object exitButton: TButton
        Left = 168
        Top = 76
        Width = 49
        Height = 25
        Caption = #51333' '#47308
        TabOrder = 4
        OnClick = exitButtonClick
      end
      object aboutButton: TButton
        Left = 112
        Top = 76
        Width = 49
        Height = 25
        Caption = #51221#48372'..'
        TabOrder = 3
        OnClick = aboutButtonClick
      end
    end
  end
  object WMP1: TWindowsMediaPlayer
    Left = 351
    Top = 152
    Width = 81
    Height = 81
    TabStop = False
    TabOrder = 8
    OnMouseMove = WMP1MouseMove
    ControlData = {
      0003000008000200000000000500000000000000F03F03000000000005000000
      00000000000008000200000000000300010000000B00FFFF0300000000000B00
      000008000200000000000300320000000B00000008000A0000006E006F006E00
      650000000B00FFFF0B0000000B00FFFF0B0000000B0000000800020000000000
      0800020000000000080002000000000008000200000000000B0000005F080000
      5F080000}
  end
  object Edit3: TEdit
    Left = 264
    Top = 8
    Width = 105
    Height = 20
    TabStop = False
    ImeName = 'Microsoft Office IME 2007'
    ReadOnly = True
    TabOrder = 2
    Visible = False
  end
  object Edit4: TEdit
    Left = 264
    Top = 32
    Width = 105
    Height = 20
    TabStop = False
    ImeName = 'Microsoft Office IME 2007'
    ReadOnly = True
    TabOrder = 3
    Visible = False
  end
  object Edit5: TEdit
    Left = 264
    Top = 56
    Width = 105
    Height = 20
    TabStop = False
    ImeName = 'Microsoft Office IME 2007'
    ReadOnly = True
    TabOrder = 4
    Visible = False
  end
  object cbClient: TCheckBox
    Left = 384
    Top = 32
    Width = 81
    Height = 17
    Caption = #53685#49888#47700#49464#51648
    Checked = True
    Font.Charset = HANGEUL_CHARSET
    Font.Color = clWhite
    Font.Height = -12
    Font.Name = #44404#47548
    Font.Style = []
    ParentFont = False
    State = cbChecked
    TabOrder = 6
    Visible = False
    OnClick = cbClientClick
  end
  object cbAlbum: TCheckBox
    Left = 384
    Top = 56
    Width = 81
    Height = 17
    Caption = #50536#48276#47700#49464#51648
    Checked = True
    Font.Charset = HANGEUL_CHARSET
    Font.Color = clWhite
    Font.Height = -12
    Font.Name = #44404#47548
    Font.Style = []
    ParentFont = False
    State = cbChecked
    TabOrder = 7
    Visible = False
    OnClick = cbClientClick
  end
  object nextButton: TButton
    Left = 264
    Top = 88
    Width = 105
    Height = 25
    Caption = 'Play Next File'
    TabOrder = 5
    Visible = False
    OnClick = nextButtonClick
  end
  object Timer1: TTimer
    Interval = 30000
    OnTimer = Timer1Timer
    Left = 264
    Top = 240
  end
end
