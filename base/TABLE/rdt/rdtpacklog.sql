CREATE TABLE [rdt].[rdtpacklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [Weight] float NOT NULL,
    [Status] nvarchar(1) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL,
    [Adddate] datetime NOT NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [EditDate] datetime NOT NULL,
    [EditWho] nvarchar(128) NOT NULL,
    CONSTRAINT [PK_rdtPackLog] PRIMARY KEY ([RowRef])
);
GO
