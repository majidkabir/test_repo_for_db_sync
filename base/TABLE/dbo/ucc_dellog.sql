CREATE TABLE [dbo].[ucc_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [Storerkey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [UCC_RowRef] int NULL,
    CONSTRAINT [PK_ucc_dellog] PRIMARY KEY ([Rowref])
);
GO
