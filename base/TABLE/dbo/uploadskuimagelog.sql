CREATE TABLE [dbo].[uploadskuimagelog]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [ImagePath] nvarchar(250) NULL,
    [ImageFolder] nvarchar(100) NULL,
    [ImageFile] nvarchar(100) NULL,
    [MainImageFlag] nvarchar(5) NULL DEFAULT ('Y'),
    [LogDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_UploadSkuImageLog] PRIMARY KEY ([RowRef])
);
GO
