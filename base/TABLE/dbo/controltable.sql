CREATE TABLE [dbo].[controltable]
(
    [type] nvarchar(1) NOT NULL DEFAULT ('I'),
    [filename] nvarchar(12) NOT NULL DEFAULT (' '),
    [trandate] datetime NOT NULL DEFAULT (getdate()),
    [rec_upload] int NOT NULL DEFAULT ((0)),
    [rec_posted] int NOT NULL DEFAULT ((0)),
    [totalqty] int NOT NULL DEFAULT ((0)),
    [addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname())
);
GO

CREATE INDEX [IX_ControlTable_Idx] ON [dbo].[controltable] ([type], [filename]);
GO