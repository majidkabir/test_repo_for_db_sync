SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Codelkup_CourierMap]
AS
select * from codelkup
WHERE listname='CourierMap'

GO