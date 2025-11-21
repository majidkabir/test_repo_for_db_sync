CREATE TABLE [dbo].[rdssize]
(
    [RDSSizeLine] int NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [SizeCode] nvarchar(18) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSSize] PRIMARY KEY ([RDSSizeLine])
);
GO

CREATE INDEX [IDX_RDSSize_SizeCode] ON [dbo].[rdssize] ([Storerkey], [SizeCode]);
GO