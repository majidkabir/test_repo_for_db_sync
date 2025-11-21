SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* this Ciew cannot use SELECT * , which as compute column/Allaise column (, [ItemCube] = [cube]    )  */
/* 20201010  TTLING01 add new column  [DriverName], [VehicleNo]    */
/* 2021-02-22  kocy  make change to able SELECT * with added compute column/Allaise column (, [ItemCube] = [cube]    ) */
CREATE   VIEW [dbo].[V_MBOLDETAIL]
AS
SELECT *
, [ItemCube] = [Cube]
FROM [dbo].[MBOLDETAIL] (NOLOCK)

GO