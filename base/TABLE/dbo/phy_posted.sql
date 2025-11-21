CREATE TABLE [dbo].[phy_posted]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [QtyTeamA] int NOT NULL DEFAULT ((0)),
    [QtyLOTxLOCxID] int NOT NULL DEFAULT ((0)),
    [ErrorMessage] nvarchar(255) NULL,
    CONSTRAINT [PKPHY_POSTED] PRIMARY KEY ([StorerKey], [Sku])
);
GO
