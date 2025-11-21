CREATE TABLE [dbo].[mailqsmsdet]
(
    [QDetid] int IDENTITY(1,1) NOT NULL,
    [Qid] int NOT NULL,
    [C01Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C01] nvarchar(1000) NOT NULL DEFAULT (''),
    [C02Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C02] nvarchar(1000) NOT NULL DEFAULT (''),
    [C03Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C03] nvarchar(1000) NOT NULL DEFAULT (''),
    [C04Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C04] nvarchar(1000) NOT NULL DEFAULT (''),
    [C05Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C05] nvarchar(1000) NOT NULL DEFAULT (''),
    [C06Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C06] nvarchar(1000) NOT NULL DEFAULT (''),
    [C07Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C07] nvarchar(1000) NOT NULL DEFAULT (''),
    [C08Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C08] nvarchar(1000) NOT NULL DEFAULT (''),
    [C09Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C09] nvarchar(1000) NOT NULL DEFAULT (''),
    [C10Name] nvarchar(128) NOT NULL DEFAULT (''),
    [C10] nvarchar(1000) NOT NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL,
    CONSTRAINT [QSMSDetid_MustBeUnique] PRIMARY KEY ([QDetid]),
    CONSTRAINT [FK_MailQSMSDet_MailQSMS] FOREIGN KEY ([Qid]) REFERENCES [dbo].[MailQSMS] ([Qid])
);
GO
