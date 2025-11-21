CREATE TABLE [dbo].[lotxlocxid_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Loc] nvarchar(10) NOT NULL DEFAULT ('UNKNOWN'),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_lotxlocxid_dellog] PRIMARY KEY ([Rowref])
);
GO
