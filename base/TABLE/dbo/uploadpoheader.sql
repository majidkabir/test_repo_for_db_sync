CREATE TABLE [dbo].[uploadpoheader]
(
    [POkey] nvarchar(10) NULL,
    [ExternPOKey] nvarchar(20) NULL,
    [POGROUP] nvarchar(10) NULL,
    [Storerkey] nvarchar(15) NULL,
    [POType] nvarchar(10) NULL,
    [SellerName] nvarchar(45) NULL,
    [MODE] nvarchar(3) NULL,
    [STATUS] nvarchar(3) NULL DEFAULT ('0'),
    [REMARKS] nvarchar(150) NULL,
    [LoadingDate] datetime NULL DEFAULT (getdate()),
    [adddate] datetime NULL DEFAULT (getdate())
);
GO

CREATE INDEX [IX_externpokey] ON [dbo].[uploadpoheader] ([ExternPOKey]);
GO
CREATE INDEX [IX_pokey] ON [dbo].[uploadpoheader] ([POkey]);
GO
CREATE INDEX [IX_status] ON [dbo].[uploadpoheader] ([STATUS]);
GO