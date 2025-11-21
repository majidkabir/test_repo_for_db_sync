CREATE TABLE [dbo].[rdscolor]
(
    [RDSColorLine] int NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [ColorCode] nvarchar(18) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSColor] PRIMARY KEY ([RDSColorLine])
);
GO

CREATE INDEX [IDX_RDSColor_ColorCode] ON [dbo].[rdscolor] ([Storerkey], [ColorCode]);
GO