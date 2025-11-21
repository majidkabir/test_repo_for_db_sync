SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/  
/* DB: KRWMS                                                                  */  
/* Purpose: User need to calculate loc occupancy for billing                  */  
/* Requester: KR DC5 Coleman Team                                             */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2022-11-28 1.0  Min        Created                                         */
/* 2022-12-06 1.1  Min        Added InvDate as Param                          */  
/* 2022-12-06 1.1  JAREKLIM   FINE TUNE AND DEPLOY  https://jiralfl.atlassian.net/browse/WMS-21253 */  
/* 2022-12-19 1.2  JAREKLIM   Add need Column  https://jiralfl.atlassian.net/browse/WMS-21253 */  
/******************************************************************************/  
--EXEC BI.isp_CM_Loc_Occupancy_Daily '2022-12-01'
CREATE   PROCEDURE [BI].[isp_CM_Loc_Occupancy_Daily](
	@cInventoryDate DATE
)
AS

BEGIN
	IF OBJECT_ID('tempdb..#TEMP_level','u') IS NOT NULL  DROP TABLE #TEMP_level;
	CREATE TABLE #TEMP_level(
		inventorydate	date,
		locationgroup nvarchar(40),
		locbay nvarchar(40),
		level nvarchar(40)
	)
	INSERT INTO #TEMP_level(
		inventorydate,
		locationgroup,
		locbay,
		level
	)

SELECT a.inventorydate,
	   b.locationgroup,
	   b.locbay,
	   substring(b.Loc,8,1) 
FROM BI.V_dailyinventory AS A WITH (NOLOCK)
JOIN BI.V_loc AS b WITH (NOLOCK)
on a.loc = b.loc
WHERE b.locationgroup <> '' 
  AND b.facility = 'CM' 
  AND a.storerkey = 'coleman' 
  AND (a.qty-a.qtypicked) <> '0'
  AND a.InventoryDate >= @cInventoryDate
GROUP BY a.inventorydate,b.locationgroup,b.locbay,substring(b.Loc,8,1)
ORDER BY a.inventorydate

END


SELECT inventorydate as [DATE]
	  , (Cast(Count(1) AS FLOAT)/2) AS [LEVEL POSITION] -- 1.2
	  , count(1) as[0.5 LEVEL] 
FROM #TEMP_level
GROUP BY inventorydate
ORDER BY inventorydate


GO