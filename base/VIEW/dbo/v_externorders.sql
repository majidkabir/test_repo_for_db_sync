SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW dbo.V_ExternOrders
as
Select * 
from DBO.ExternOrders (NOLOCK)

GO