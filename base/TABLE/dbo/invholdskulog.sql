CREATE TABLE [dbo].[invholdskulog]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Facility] nvarchar(10) NOT NULL,
    [PreHoldQty] int NULL,
    [OnHoldQty] int NULL,
    [TranStatus] nvarchar(10) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [Msgtext] nvarchar(100) NULL,
    [Lottable02] nvarchar(18) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_InvHoldSkuLog] PRIMARY KEY ([StorerKey], [Sku], [Facility], [Lottable02])
);
GO
