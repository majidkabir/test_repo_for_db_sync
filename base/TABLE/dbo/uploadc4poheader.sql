CREATE TABLE [dbo].[uploadc4poheader]
(
    [POkey] nvarchar(10) NOT NULL,
    [ExternPOKey] nvarchar(20) NULL,
    [POGROUP] nvarchar(10) NULL,
    [Storerkey] nvarchar(15) NULL,
    [POType] nvarchar(10) NULL,
    [SellerName] nvarchar(45) NULL,
    [MODE] nvarchar(3) NULL,
    [STATUS] nvarchar(3) NULL DEFAULT ('0'),
    [REMARKS] nvarchar(150) NULL,
    [LoadingDate] datetime NULL DEFAULT (getdate()),
    [adddate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_UPLOADC4POHeader] PRIMARY KEY ([POkey])
);
GO

CREATE INDEX [IX_UPLOADC4POHeader_ExtPOKey] ON [dbo].[uploadc4poheader] ([ExternPOKey]);
GO