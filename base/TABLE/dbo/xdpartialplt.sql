CREATE TABLE [dbo].[xdpartialplt]
(
    [Rowid] int IDENTITY(1,1) NOT NULL,
    [DropId] nvarchar(10) NOT NULL,
    [ConsigneeKey] nvarchar(15) NOT NULL,
    [DeliveryDate] datetime NOT NULL,
    [Col1] nvarchar(30) NULL,
    [Col2] nvarchar(30) NULL,
    [Col3] nvarchar(30) NULL,
    [Col4] nvarchar(30) NULL,
    [Col5] nvarchar(30) NULL,
    [Col6] nvarchar(30) NULL,
    [Col7] nvarchar(30) NULL,
    [Col8] nvarchar(30) NULL,
    [Col9] nvarchar(30) NULL,
    [Col10] nvarchar(30) NULL,
    [CumWeight] float NULL DEFAULT ((0)),
    [CumCube] float NULL DEFAULT ((0)),
    CONSTRAINT [PK_XDPARTIALPLT] PRIMARY KEY ([Rowid])
);
GO

CREATE INDEX [IX_XDPARTIALPLT] ON [dbo].[xdpartialplt] ([ConsigneeKey], [DeliveryDate], [Col1]);
GO