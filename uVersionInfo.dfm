object Form4: TForm4
  Left = 0
  Top = 0
  Caption = 'Version Info'
  ClientHeight = 289
  ClientWidth = 714
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 714
    Height = 137
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object rgApp: TRadioGroup
      Left = 0
      Top = 30
      Width = 82
      Height = 77
      Caption = 'Application'
      ItemIndex = 0
      Items.Strings = (
        'All'
        'IMiSScan'
        'IMiSView')
      TabOrder = 0
      OnClick = btnReadClick
    end
    object rgVersion: TRadioGroup
      Left = 88
      Top = 31
      Width = 75
      Height = 90
      Caption = 'Version'
      ItemIndex = 0
      Items.Strings = (
        'All'
        '++'
        '+'
        'empty'
        'demo')
      TabOrder = 1
      OnClick = btnReadClick
    end
    object rgLang: TRadioGroup
      Left = 169
      Top = 31
      Width = 210
      Height = 106
      Caption = 'Langugage'
      Columns = 2
      ItemIndex = 0
      Items.Strings = (
        'All'
        'English'
        'Slovenian'
        'Bosnian'
        'Croatian'
        'Croatian-Bosnian'
        'German'
        'German Aus'
        'German Lux'
        'German Swis'
        'German Lih')
      TabOrder = 2
      OnClick = btnReadClick
    end
    object Panel2: TPanel
      Left = 0
      Top = 0
      Width = 714
      Height = 27
      Align = alTop
      AutoSize = True
      TabOrder = 3
      object btnRead: TButton
        Left = 1
        Top = 1
        Width = 75
        Height = 25
        Align = alLeft
        Caption = 'Read'
        TabOrder = 0
        OnClick = btnReadClick
      end
      object btnWrite: TButton
        Left = 76
        Top = 1
        Width = 75
        Height = 25
        Align = alLeft
        Caption = 'Write'
        TabOrder = 1
        OnClick = btnWriteClick
      end
      object btnUpdate: TButton
        Left = 151
        Top = 1
        Width = 75
        Height = 25
        Align = alLeft
        Caption = 'Update to All'
        TabOrder = 2
        OnClick = btnUpdateClick
      end
      object btnSource: TButton
        Left = 226
        Top = 1
        Width = 63
        Height = 25
        Align = alLeft
        Caption = 'Source'
        TabOrder = 3
      end
      object edtSource: TEdit
        Left = 289
        Top = 1
        Width = 300
        Height = 25
        Align = alLeft
        TabOrder = 4
        Text = 'edtSource'
        OnChange = edtSourceChange
      end
      object btnUpdateDPR: TButton
        Left = 589
        Top = 1
        Width = 75
        Height = 25
        Align = alLeft
        Caption = 'Update DPRs'
        TabOrder = 5
        OnClick = btnUpdateDPRClick
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 270
    Width = 714
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object tabAppType: TTabControl
    Left = 0
    Top = 137
    Width = 714
    Height = 133
    Align = alClient
    TabOrder = 2
    Tabs.Strings = (
      'Build'
      'Release')
    TabIndex = 0
    OnChange = tabAppTypeChange
    object StringGrid2: TStringGrid
      Left = 4
      Top = 24
      Width = 706
      Height = 105
      Align = alClient
      ColCount = 3
      RowCount = 2
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goEditing, goTabs, goThumbTracking]
      TabOrder = 0
      OnSelectCell = StringGrid2SelectCell
      OnSetEditText = StringGrid2SetEditText
      RowHeights = (
        24
        24)
    end
  end
end
