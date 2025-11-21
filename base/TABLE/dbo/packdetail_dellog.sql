CREATE TABLE [dbo].[packdetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [LabelNo] nvarchar(20) NOT NULL,
    [LabelLine] nvarchar(5) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [Storerkey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [QTY] int NULL,
    CONSTRAINT [PK_packdetail_dellog] PRIMARY KEY ([Rowref])
);
GO
