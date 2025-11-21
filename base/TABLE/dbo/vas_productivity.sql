CREATE TABLE [dbo].[vas_productivity]
(
    [VASPRODKEY] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [Dep] nvarchar(15) NOT NULL DEFAULT (''),
    [Productivity] float NOT NULL DEFAULT ((0)),
    [Type] nvarchar(10) NOT NULL DEFAULT (''),
    [MaxKITQty] int NOT NULL DEFAULT ((0)),
    [Machine] nvarchar(20) NOT NULL DEFAULT (''),
    [MachineNo] nvarchar(10) NOT NULL DEFAULT (''),
    [MaxCapacity] int NOT NULL DEFAULT ((0)),
    [MachineQty] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_VAS_Productivity_1] PRIMARY KEY ([VASPRODKEY])
);
GO
