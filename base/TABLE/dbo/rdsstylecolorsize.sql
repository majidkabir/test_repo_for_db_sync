CREATE TABLE [dbo].[rdsstylecolorsize]
(
    [SeqNo] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [UPC] nvarchar(30) NOT NULL,
    [Style] nvarchar(20) NOT NULL,
    [Color] nvarchar(10) NOT NULL,
    [Sizes] nvarchar(10) NOT NULL,
    [Measurement] nvarchar(10) NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_RDSStyleColorSize] PRIMARY KEY ([Storerkey], [Style], [Color], [SeqNo])
);
GO

CREATE INDEX [IDX_RDSStyleColorSize_Size] ON [dbo].[rdsstylecolorsize] ([Storerkey], [Style], [Color], [Sizes], [Measurement]);
GO
CREATE INDEX [IDX_RDSStyleColorSize_UPC] ON [dbo].[rdsstylecolorsize] ([Storerkey], [UPC]);
GO