CREATE TABLE [dbo].[itrnucc]
(
    [ITrnUCCKey] int IDENTITY(1,1) NOT NULL,
    [ItrnKey] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [FromStatus] nvarchar(10) NULL DEFAULT (' '),
    [ToStatus] nvarchar(10) NULL DEFAULT (' '),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_ITrnUCC] PRIMARY KEY ([ITrnUCCKey])
);
GO

CREATE INDEX [IDX_ITrnUCC_ItrnKey] ON [dbo].[itrnucc] ([ItrnKey]);
GO
CREATE INDEX [IDX_ITrnUCC_UCCNo_StorerKey] ON [dbo].[itrnucc] ([UCCNo], [StorerKey]);
GO