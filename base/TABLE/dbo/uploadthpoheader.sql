CREATE TABLE [dbo].[uploadthpoheader]
(
    [POkey] nvarchar(10) NULL,
    [ExternPOKey] nvarchar(20) NULL,
    [POGROUP] nvarchar(10) NULL,
    [Storerkey] nvarchar(15) NULL,
    [POType] nvarchar(10) NULL,
    [SellerName] nvarchar(45) NULL,
    [MODE] nvarchar(3) NULL,
    [STATUS] nvarchar(3) NULL,
    [REMARKS] nvarchar(150) NULL,
    [LoadingDate] datetime NULL,
    [adddate] datetime NULL
);
GO

CREATE INDEX [IX_UPLOADTHPOHEADER_ExternPOKey] ON [dbo].[uploadthpoheader] ([STATUS], [ExternPOKey]);
GO
CREATE INDEX [IX_UPLOADTHPOHEADER_POKey] ON [dbo].[uploadthpoheader] ([POkey]);
GO