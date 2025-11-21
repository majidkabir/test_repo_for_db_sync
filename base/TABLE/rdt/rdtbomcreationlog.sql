CREATE TABLE [rdt].[rdtbomcreationlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NULL,
    [ParentSKU] nvarchar(18) NULL,
    [ComponentSKU] nvarchar(20) NULL,
    [Style] nvarchar(20) NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [SequenceNo] nvarchar(10) NULL,
    [UserName] nvarchar(128) NULL,
    [MobileNo] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PKrdtBOMCreationLog] PRIMARY KEY ([RowRef])
);
GO
