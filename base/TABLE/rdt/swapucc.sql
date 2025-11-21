CREATE TABLE [rdt].[swapucc]
(
    [Func] int NULL,
    [UCC] nvarchar(20) NULL,
    [NewUCC] nvarchar(20) NULL,
    [ReplenGroup] nvarchar(10) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [UCCStatus] nvarchar(1) NULL,
    [NewUCCStatus] nvarchar(1) NULL
);
GO
