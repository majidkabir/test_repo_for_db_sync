CREATE TABLE [dbo].[storersodefaultdate]
(
    [rowref] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [OrderType] nvarchar(10) NULL,
    [CompareDate] nvarchar(15) NOT NULL DEFAULT ('AddDate'),
    [Operator] nvarchar(2) NOT NULL,
    [CutOffTime] nvarchar(5) NOT NULL DEFAULT ('00:00'),
    [MinQty] int NOT NULL DEFAULT ((0)),
    [MaxQty] int NOT NULL DEFAULT ((0)),
    [ProcessTime] int NOT NULL,
    [ProcessType] nvarchar(1) NOT NULL DEFAULT ('D'),
    [Priority] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_StorerDespatchDate_1] PRIMARY KEY ([rowref])
);
GO
