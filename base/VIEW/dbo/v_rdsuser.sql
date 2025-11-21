SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_rdsUser]
as
SElect
UserId	,
Password	,
FirstName	,
LastName	,
DefaultStorer	,
MenuID	,
LastLogin	,
AddDate	,
AddWho	,
EditDate	,
EditWho	
FROM rdsUser with (NOLOCK)


GO