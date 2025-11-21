CREATE TABLE [dbo].[mbolerrorreport]
(
    [SeqNo] bigint IDENTITY(1,1) NOT NULL,
    [MBOLKey] nvarchar(10) NOT NULL,
    [ErrorNo] nvarchar(10) NOT NULL,
    [Type] nvarchar(15) NOT NULL,
    [LineText] nvarchar(MAX) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_MBOLErrorReport] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IX_MBOLErrorReport] ON [dbo].[mbolerrorreport] ([MBOLKey], [ErrorNo]);
GO