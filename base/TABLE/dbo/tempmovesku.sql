CREATE TABLE [dbo].[tempmovesku]
(
    [MoveKey] nvarchar(10) NULL,
    [StorerKey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [Lot] nvarchar(10) NULL,
    [FromID] nvarchar(18) NULL,
    [FromLoc] nvarchar(10) NULL,
    [ToLoc] nvarchar(10) NULL,
    [Qty] int NULL,
    [ToID] nvarchar(18) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname())
);
GO
