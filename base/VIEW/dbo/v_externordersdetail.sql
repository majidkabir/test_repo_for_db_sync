SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW V_ExternOrdersDetail
as
Select * 
from dbo.ExternOrdersDetail (NOLOCK)

GO