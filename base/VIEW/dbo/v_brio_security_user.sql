SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE view [dbo].[V_BRIO_SECURITY_USER] as 
select * from AUTSecure..Brio_Security_User

GO