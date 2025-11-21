CREATE TABLE [dbo].[triganticcc]
(
    [CCKey] nvarchar(10) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty_Before] int NULL DEFAULT ((0)),
    [Qty_After] int NULL DEFAULT ((0)),
    [Adddate] datetime NULL,
    [AdjCode] nvarchar(10) NULL,
    [AdjCodeDesc] nvarchar(20) NULL,
    [AdjType] nvarchar(2) NULL,
    CONSTRAINT [PK_TriganticCC] PRIMARY KEY ([CCKey], [Facility], [StorerKey], [SKU])
);
GO
