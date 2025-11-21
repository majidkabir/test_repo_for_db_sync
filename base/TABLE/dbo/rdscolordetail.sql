CREATE TABLE [dbo].[rdscolordetail]
(
    [RDSColorLine] int NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [SeqNo] nvarchar(10) NOT NULL,
    [ColorCode] nvarchar(18) NOT NULL,
    [ColorAbbrev] nvarchar(10) NOT NULL,
    [Descr] nvarchar(30) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSColorDetail] PRIMARY KEY ([RDSColorLine], [SeqNo])
);
GO

CREATE INDEX [IDX_RDSColorDetail_ColorCode] ON [dbo].[rdscolordetail] ([Storerkey], [ColorCode]);
GO