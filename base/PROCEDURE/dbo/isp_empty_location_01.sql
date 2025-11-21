SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store Procedure: isp_empty_location_01                                     */
/* Creation Date: 08-APR-2017                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose: For CN LIT datawindow                                             */
/*                                                                            */
/*                                                                            */
/* Called By:  r_dw_empty_location_01                                         */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/* 16-JUN-2017  CSCHONG   1.0   WMS-2088 - Revise report requirement (CS01)   */
/******************************************************************************/

CREATE PROC [dbo].[isp_empty_location_01]
@c_Facility nvarchar(5),
@c_Storerkey nvarchar(10),
@c_NoofCopy  NVARCHAR(5),
@c_Putawayzone NVARCHAR(10),
@c_loclevel    NVARCHAR(50) = ''
AS

BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE  @c_SQL             NVARCHAR(4000),          
            @c_SQLJOIN         NVARCHAR(4000),
            @c_SQLfilter       NVARCHAR(4000),   -- CS01  
            @c_sqlOrderBy      NVARCHAR(4000)    --CS01

IF ISNULL(@c_Storerkey,'') = '' OR ISNULL(@c_facility,'') = '' OR ISNULL(@c_NoofCopy,0) = 0
BEGIN
	GOTO QUIT_SP
END

create table #EmptyLoc_Label
( RowId          INT IDENTITY(1,1) NOT NULL,
 facility            NVARCHAR(5),
 Storerkey           nvarchar(10),
 Location            nvarchar(20),
 PutawayZone         nvarchar(10),
 LocCategory         nvarchar(10),
 loclevel            NVARCHAR(10) )         --CS01
 
 /*CS01 Start*/
 SET @c_SQLfilter = ''  
 
 SET @c_sqlOrderBy  = ' ORDER BY Logicallocation'         
 IF ISNULL(@c_loclevel,'') <> ''
 BEGIN
 	
 	SET @c_SQLfilter = 'AND LocLevel NOT IN (' + @c_loclevel + ')'
 	
 END
 
 /*CS01 End*/
  
  IF CONVERT(INT,ISNULL(@c_NoofCopy,0)) >= 1
  BEGIN 
  SET @c_SQLJOIN = +' SELECT TOP '+ @c_NoofCopy +' facility, ''' + @c_Storerkey + ''',loc,PutawayZone, LocationCategory,loclevel'     --CS01
                   +' FROM LOC WITH (NOLOCK) '
                   +' WHERE Facility = ''' + @c_Facility + ''' '
                   + 'AND LOC NOT IN (SELECT Loc FROM LOTXLOCXID WHERE Qty <> 0 and Storerkey = ''' + @c_Storerkey + ''' ) '
                  -- + ' ORDER BY Logicallocation'                 --CS01

SET @c_SQL='INSERT INTO #EmptyLoc_Label (facility,Storerkey,Location,PutawayZone,LocCategory,loclevel)'          --CS01
--SELECT facility,@c_Storerkey,loc,PutawayZone, LocationCategory 
--FROM Loc 
--WHERE Facility =  @c_Facility
--AND Loc NOT IN (SELECT Loc FROM LOTXLOCXID WHERE Qty <> 0 and Storerkey = @c_Storerkey) 
----AND loc.PutawayZone = CASE WHEN isnull(@c_Putawayzone,'') <> '' THEN @c_Putawayzone ELSE LOC.PickZone END 
--ORDER BY LogicalLocation

SET @c_SQL = @c_SQL + @c_SQLJOIN + CHAR(13) + @c_SQLfilter + CHAR(13) + @c_sqlOrderBy             --CS01
      
EXEC sp_executesql @c_SQL    

 --WHILE @n_NoofCopy > 1
 --BEGIN
 --	INSERT INTO #EmptyLoc_Label (facility,Storerkey,Location,PutawayZone,LocCategory)
 --	SELECT facility,Storerkey,Location,PutawayZone,LocCategory
 --	FROM #EmptyLoc_Label
 --	WHERE RowId = 1
 	
 	
 --	SET @n_NoofCopy = @n_NoofCopy - 1
 	
 --END
 END

SELECT * FROM #EmptyLoc_Label
ORDER BY RowId

QUIT_SP:
END       

GO