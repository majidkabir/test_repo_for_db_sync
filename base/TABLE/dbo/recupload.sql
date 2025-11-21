CREATE TABLE [dbo].[recupload]
(
    [STORERKEY] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [Qty] int NULL,
    [LOC] nvarchar(10) NULL,
    [Flag] nvarchar(2) NULL DEFAULT ('N'),
    [Message] nvarchar(50) NULL DEFAULT (' ')
);
GO
