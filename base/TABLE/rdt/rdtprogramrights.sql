CREATE TABLE [rdt].[rdtprogramrights]
(
    [UserName] nvarchar(128) NOT NULL,
    [ProgramID] int NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtProgramRights] PRIMARY KEY ([UserName], [ProgramID])
);
GO
