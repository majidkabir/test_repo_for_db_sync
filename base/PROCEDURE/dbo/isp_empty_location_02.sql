SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store Procedure: isp_empty_location_02                                     */
/* Creation Date: 06-OCT-2020                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose: WMS-15317 MYSûUNILEVERûRemove Putaway Zone pagebreak              */
/*                                                                            */
/*                                                                            */
/* Called By:  r_dw_empty_location_02                                         */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/******************************************************************************/

CREATE PROC [dbo].[isp_empty_location_02]
@c_loc_start       NVARCHAR(10),
@c_loc_end         NVARCHAR(10),
@c_type_start      NVARCHAR(10),
@c_type_end        NVARCHAR(10),
@c_zone_start      NVARCHAR(10),
@c_zone_end        NVARCHAR(10),
@C_Facility_Start  NVARCHAR(10),
@C_Facility_End    NVARCHAR(10)
AS

BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT putawayzone=UPPER(LOC.putawayzone),
         loc=UPPER(LOC.loc),
         locationtype=UPPER(LOC.locationtype)
   FROM LOC WITH (NOLOCK) 
   LEFT JOIN LOTXLOCXID WITH (NOLOCK) ON LOC.loc = LOTXLOCXID.loc
   WHERE ( putawayzone BETWEEN @c_zone_start AND @c_zone_end )
     AND ( LOC.loc BETWEEN @c_loc_start AND @c_loc_end )
     AND ( locationtype BETWEEN @c_type_start AND @c_type_end )
     AND ( Loc.Facility BETWEEN @C_Facility_Start AND @C_Facility_End )
   GROUP BY LOC.putawayzone,
            LOC.loc,
            LOC.locationtype
   HAVING (SUM(LOTXLOCXID.qty) = 0 OR SUM(LOTXLOCXID.qty) IS NULL)
   ORDER BY LOC.PUTAWAYZONE,
            LOC.loc,
            LOC.locationtype

QUIT_SP:
END       

GO