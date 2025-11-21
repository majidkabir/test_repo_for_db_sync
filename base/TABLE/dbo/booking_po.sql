CREATE TABLE [dbo].[booking_po]
(
    [ExternPokey] nvarchar(20) NULL,
    [SellerName] nvarchar(45) NULL,
    [SellersReference] nvarchar(18) NULL,
    [EffectiveDate] datetime NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL
);
GO
