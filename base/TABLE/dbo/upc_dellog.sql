CREATE TABLE [dbo].[upc_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [UPC] nvarchar(30) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [SKU] nvarchar(20) NULL,
    CONSTRAINT [PK_upc_dellog] PRIMARY KEY ([Rowref])
);
GO
