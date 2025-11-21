CREATE TABLE [dbo].[invbalintegritytrace]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [CheckType] nvarchar(60) NOT NULL,
    [LOT] nvarchar(10) NOT NULL DEFAULT (''),
    [LOC] nvarchar(10) NOT NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [A_Qty] int NOT NULL DEFAULT ((0)),
    [A_QtyAllocated] int NOT NULL DEFAULT ((0)),
    [A_QtyPicked] int NOT NULL DEFAULT ((0)),
    [B_Qty] int NOT NULL DEFAULT ((0)),
    [B_QtyAllocated] int NOT NULL DEFAULT ((0)),
    [B_QtyPicked] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_InvBalIntegrityTrace] PRIMARY KEY ([RowID])
);
GO
