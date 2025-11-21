CREATE TABLE [dbo].[c4_rec_exp]
(
    [Messageh] nvarchar(10) NULL,
    [MessageDate] nvarchar(10) NULL,
    [Rev_Date] nvarchar(10) NULL,
    [PO_Number] nvarchar(10) NULL,
    [Buyer] nvarchar(3) NULL DEFAULT ('888'),
    [SupplyCode] nvarchar(10) NULL,
    [Head] nvarchar(3) NULL DEFAULT ('900'),
    [Line] nvarchar(20) NULL,
    [SKU] nvarchar(20) NULL,
    [Qty] int NULL DEFAULT ('0'),
    [Best_Before_Date] nvarchar(10) NULL,
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [Documentkey] nvarchar(15) NOT NULL,
    [Adddate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_C4_Rec_Exp] PRIMARY KEY ([Documentkey])
);
GO
