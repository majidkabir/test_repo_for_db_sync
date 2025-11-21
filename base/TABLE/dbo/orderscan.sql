CREATE TABLE [dbo].[orderscan]
(
    [Loadkey] nvarchar(10) NOT NULL,
    [Orderkey] nvarchar(10) NOT NULL,
    [UserID] nvarchar(128) NOT NULL,
    [ScanDate] datetime NOT NULL DEFAULT (getdate()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_ORDERSCAN] PRIMARY KEY ([Loadkey], [Orderkey])
);
GO
