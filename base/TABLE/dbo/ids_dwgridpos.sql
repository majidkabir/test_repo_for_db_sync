CREATE TABLE [dbo].[ids_dwgridpos]
(
    [UserId] nvarchar(128) NOT NULL,
    [WindowName] nvarchar(40) NOT NULL DEFAULT (''),
    [DataWindowObjName] nvarchar(40) NOT NULL DEFAULT (''),
    [DWPosition] nvarchar(2000) NULL,
    [DWColor] nvarchar(2000) NULL,
    [WinWidth] int NULL DEFAULT ((0)),
    [WinHeight] int NULL DEFAULT ((0)),
    [WinState] nvarchar(10) NULL,
    [WinCtrlObjName] nvarchar(40) NOT NULL DEFAULT (''),
    [WinCtrlObjProperties] nvarchar(2000) NULL,
    CONSTRAINT [PK_IDS_DWGRIDPOS] PRIMARY KEY ([UserId], [WindowName], [DataWindowObjName], [WinCtrlObjName])
);
GO
