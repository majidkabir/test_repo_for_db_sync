CREATE TABLE [dbo].[physicalparameters]
(
    [PhysicalParmKey] int NOT NULL DEFAULT (' '),
    [StorerKeyMin] nvarchar(15) NOT NULL DEFAULT (' '),
    [StorerKeyMax] nvarchar(15) NOT NULL DEFAULT (' '),
    [SkuMin] nvarchar(20) NOT NULL DEFAULT (' '),
    [SkuMax] nvarchar(20) NOT NULL DEFAULT (' '),
    CONSTRAINT [PKPhysicalParameters] PRIMARY KEY ([PhysicalParmKey])
);
GO
