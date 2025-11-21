CREATE TABLE [dbo].[rdssizedetail]
(
    [RDSSizeLine] int NOT NULL,
    [SeqNo] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [SizeCode] nvarchar(18) NOT NULL,
    [Sizes] nvarchar(10) NOT NULL,
    [Measurement] nvarchar(10) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSSizeDetail] PRIMARY KEY ([RDSSizeLine], [SizeCode], [SeqNo])
);
GO

CREATE INDEX [IDX_RDSSizeDetail_SizeCode] ON [dbo].[rdssizedetail] ([Storerkey], [SizeCode]);
GO