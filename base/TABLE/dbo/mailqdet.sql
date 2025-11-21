CREATE TABLE [dbo].[mailqdet]
(
    [QDetid] int IDENTITY(1,1) NOT NULL,
    [Qid] int NULL,
    [C01] nvarchar(1000) NOT NULL,
    [C02] nvarchar(1000) NOT NULL,
    [C03] nvarchar(1000) NOT NULL,
    [C04] nvarchar(1000) NOT NULL,
    [C05] nvarchar(1000) NOT NULL,
    [C06] nvarchar(1000) NOT NULL,
    [C07] nvarchar(1000) NOT NULL,
    [C08] nvarchar(1000) NOT NULL,
    [C09] nvarchar(1000) NOT NULL,
    [C10] nvarchar(1000) NOT NULL,
    [C11] nvarchar(1000) NOT NULL,
    [C12] nvarchar(1000) NOT NULL,
    [C13] nvarchar(1000) NOT NULL,
    [C14] nvarchar(1000) NOT NULL,
    [C15] nvarchar(1000) NOT NULL,
    [OrderKey] nvarchar(50) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [QDetid_MustBeUnique] PRIMARY KEY ([QDetid]),
    CONSTRAINT [FK_MailQDet_MailQ] FOREIGN KEY ([Qid]) REFERENCES [dbo].[MailQ] ([Qid])
);
GO

CREATE INDEX [IX_MailQDet_OrderKey] ON [dbo].[mailqdet] ([OrderKey]);
GO