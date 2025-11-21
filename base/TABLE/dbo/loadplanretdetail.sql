CREATE TABLE [dbo].[loadplanretdetail]
(
    [LoadKey] nvarchar(10) NOT NULL,
    [LoadLineNumber] nvarchar(5) NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL,
    [ExternReceiptKey] nvarchar(20) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Weight] float NOT NULL DEFAULT ((0.0)),
    [Cube] float NOT NULL DEFAULT ((0.0)),
    [ExternLoadKey] nvarchar(30) NULL DEFAULT (' '),
    [ExternLineNo] nvarchar(20) NULL DEFAULT (' '),
    CONSTRAINT [PK_LoadPlanRetDetail] PRIMARY KEY ([LoadKey], [LoadLineNumber])
);
GO
