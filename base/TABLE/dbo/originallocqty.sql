CREATE TABLE [dbo].[originallocqty]
(
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(10) NOT NULL,
    [QtyAllocated] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_OriginAllocQty] PRIMARY KEY ([OrderKey], [OrderLineNumber])
);
GO
