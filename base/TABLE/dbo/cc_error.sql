CREATE TABLE [dbo].[cc_error]
(
    [StorerKey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [Lot] nvarchar(10) NULL,
    [ID] nvarchar(18) NULL,
    [Loc] nvarchar(10) NULL,
    [Qty] int NULL,
    [Remark] nvarchar(255) NULL,
    [AddDate] datetime NULL DEFAULT (getdate())
);
GO

CREATE INDEX [IX_CC_Error_Idx] ON [dbo].[cc_error] ([StorerKey], [Sku], [Lot], [Loc], [ID]);
GO