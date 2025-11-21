CREATE TABLE [dbo].[couriersortingcode]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [ShipperKey] nvarchar(15) NOT NULL DEFAULT (''),
    [State] nvarchar(45) NULL DEFAULT (''),
    [City] nvarchar(45) NULL DEFAULT (''),
    [Province] nvarchar(45) NULL DEFAULT (''),
    [Zip] nvarchar(18) NULL DEFAULT (''),
    [SortingCode1] nvarchar(100) NULL DEFAULT (''),
    [SortingCode2] nvarchar(100) NULL DEFAULT (''),
    [SortingCode3] nvarchar(100) NULL DEFAULT (''),
    [EffectiveDate] datetime NULL,
    [Comment] nvarchar(255) NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    CONSTRAINT [PK_CourierSortingCode] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_CourierSortingCode_DF01] ON [dbo].[couriersortingcode] ([ShipperKey], [Zip]);
GO