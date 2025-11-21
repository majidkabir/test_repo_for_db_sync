CREATE TABLE [dbo].[modulereports]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [PB_WindowName] nvarchar(50) NOT NULL,
    [Rpt_ID] nvarchar(8) NOT NULL,
    [MenuTitle] nvarchar(20) NOT NULL DEFAULT (''),
    [MenuSeqNo] int NOT NULL DEFAULT ((99)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_ModuleReports] PRIMARY KEY ([RowID])
);
GO
