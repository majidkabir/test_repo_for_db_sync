CREATE TABLE [dbo].[itrnhdr]
(
    [HeaderType] nvarchar(2) NOT NULL,
    [ItrnKey] nvarchar(10) NOT NULL,
    [HeaderKey] nvarchar(10) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKITRNHDR] PRIMARY KEY ([HeaderType], [ItrnKey], [HeaderKey])
);
GO
