CREATE TABLE [dbo].[channelattributeconfig]
(
    [ChannelConfig_ID] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(50) NOT NULL,
    [C_AttributeLabel01] nvarchar(50) NOT NULL DEFAULT (''),
    [C_AttributeLabel02] nvarchar(50) NULL DEFAULT (''),
    [C_AttributeLabel03] nvarchar(50) NULL DEFAULT (''),
    [C_AttributeLabel04] nvarchar(50) NULL DEFAULT (''),
    [C_AttributeLabel05] nvarchar(50) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_ChannelAttributeConfig] PRIMARY KEY ([ChannelConfig_ID])
);
GO
