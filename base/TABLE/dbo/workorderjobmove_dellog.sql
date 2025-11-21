CREATE TABLE [dbo].[workorderjobmove_dellog]
(
    [WOMoveKey] bigint NOT NULL,
    [JobKey] nvarchar(10) NOT NULL,
    [JobLine] nvarchar(5) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [ToLoc] nvarchar(10) NOT NULL,
    [ID] nvarchar(18) NOT NULL,
    [Qty] int NOT NULL,
    [PickMethod] nvarchar(10) NULL,
    [JobReservekey] nvarchar(10) NOT NULL,
    [OriginalLoc] nvarchar(10) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate())
);
GO
