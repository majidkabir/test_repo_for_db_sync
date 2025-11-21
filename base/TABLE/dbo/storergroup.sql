CREATE TABLE [dbo].[storergroup]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [StorerGroup] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_StorerGroup] PRIMARY KEY ([StorerGroup], [StorerKey])
);
GO
