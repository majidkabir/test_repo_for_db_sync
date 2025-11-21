SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_rdsRole]
as
SElect
RoleID	,
RoleDesc	,
AddDate	,
AddWho
from rdsRole with (NOLOCK)



GO