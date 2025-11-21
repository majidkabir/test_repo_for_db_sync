CREATE TABLE [dbo].[webservicecfg]
(
    [RowID] int IDENTITY(1,1) NOT NULL,
    [DataProcess] nvarchar(10) NOT NULL DEFAULT (''),
    [Descr] nvarchar(100) NOT NULL DEFAULT (''),
    [WebRequestURL] nvarchar(500) NOT NULL DEFAULT (''),
    [WebRequestContentType] nvarchar(100) NOT NULL DEFAULT (''),
    [WebRequestMethod] nvarchar(10) NOT NULL DEFAULT (''),
    [WebRequestEncoding] nvarchar(30) NOT NULL DEFAULT (''),
    [WebRequestTimeOut] int NOT NULL DEFAULT ((120000)),
    [IniFilePath] nvarchar(225) NOT NULL DEFAULT (''),
    [CountryCode] nvarchar(2) NOT NULL DEFAULT (''),
    [ReqBodyEncodeFormat] nvarchar(30) NOT NULL DEFAULT (''),
    [RespBodyDecodeFormat] nvarchar(30) NOT NULL DEFAULT (''),
    [ReqBodyEncodeDataOnly] nvarchar(20) NOT NULL DEFAULT ('0'),
    [RespBodyDecodeDataOnly] nvarchar(20) NOT NULL DEFAULT ('0'),
    [PostingSPName] nvarchar(200) NOT NULL DEFAULT (''),
    [EPServerType] nvarchar(10) NOT NULL DEFAULT (''),
    [NetworkCredentialUserName] nvarchar(100) NOT NULL DEFAULT (''),
    [NetworkCredentialPassword] nvarchar(100) NOT NULL DEFAULT (''),
    [ActiveFlag] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_WebServiceCfg] PRIMARY KEY ([RowID])
);
GO
