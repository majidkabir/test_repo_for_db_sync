CREATE TABLE [dbo].[ids_ec_scgdsrn]
(
    [externreceiptkey] nvarchar(20) NULL,
    [pokey] nvarchar(18) NULL,
    [sku] nvarchar(20) NULL,
    [goodqty] int NULL DEFAULT ((0)),
    [badqty] int NULL DEFAULT ((0))
);
GO

CREATE INDEX [IX_ids_ec_scgdsrn] ON [dbo].[ids_ec_scgdsrn] ([externreceiptkey], [pokey], [sku]);
GO