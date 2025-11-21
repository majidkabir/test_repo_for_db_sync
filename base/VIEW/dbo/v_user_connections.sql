SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_user_connections]
AS 
	SELECT login_name, login_date
   FROM AUTSecure..user_connections (nolock)



GO