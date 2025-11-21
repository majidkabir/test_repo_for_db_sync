CREATE TABLE [api].[transactionlog]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [UserName] nvarchar(128) NULL,
    [Module] nvarchar(200) NULL,
    [AddDate] datetime NULL,
    CONSTRAINT [PK_API.TransactionLog] PRIMARY KEY ([RowRefNo])
);
GO
