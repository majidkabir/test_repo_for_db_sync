CREATE TABLE [dbo].[skuxloc_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Loc] nvarchar(10) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_skuxloc_dellog] PRIMARY KEY ([Rowref])
);
GO
