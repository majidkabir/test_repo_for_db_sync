CREATE TABLE [dbo].[rdsstylecolor]
(
    [LinesNo] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Style] nvarchar(20) NOT NULL,
    [Color] nvarchar(10) NOT NULL,
    [Descr] nvarchar(30) NOT NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSStyleColor] PRIMARY KEY ([Storerkey], [Style], [LinesNo])
);
GO

CREATE INDEX [IDX_RDSStyleColor_Color] ON [dbo].[rdsstylecolor] ([Storerkey], [Style], [Color]);
GO