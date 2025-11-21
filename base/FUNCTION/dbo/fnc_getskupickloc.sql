SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************************/
/* Function: fnc_GetSkuPickLoc                                                      */
/* Creation Date: 06-Apr-2020                                                       */
/* Copyright: LF Logistics                                                          */
/* Written by:                                                                      */
/*                                                                                  */
/* Purpose: WMS-12782 - Get pick loc of the sku                                     */
/*        :                                                                         */
/* Called By: CROSS APPLY dbo.fnc_GetSkuPickLoc(t.StorerKey,t.Sku,t.locationtype, t.facility, 'Y')*/
/*          : OUTER APPLY                                                           */
/*            multiple Locationtype can be delimited by comma.                      */
/*            facility is optional.                                                 */
/*            @c_top1 Y=Return top 1 record, N or empty return all records.         */
/* PVCS Version: 1.0                                                                */
/*                                                                                  */
/* Version: 7.0                                                                     */
/*                                                                                  */
/* Data Modifications:                                                              */
/*                                                                                  */
/* Updates:                                                                         */
/* Date         Author    Ver Purposes                                              */
/************************************************************************************/
CREATE FUNCTION [dbo].fnc_GetSkuPickLoc(@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_LocationType NVARCHAR(100), @c_Facility NVARCHAR(5))
RETURNS TABLE
AS 
RETURN
(
   SELECT TOP 1 SL.Storerkey, SL.Sku, SL.Loc, L.LocationType, L.Pickzone, L.PutawayZone, L.Facility
   FROM SKUXLOC SL (NOLOCK)
   JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc
   WHERE SL.Storerkey = @c_Storerkey
   AND SL.Sku = @c_Sku
   AND SL.LocationType IN(SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_LocationType))
   AND (L.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '')
   GROUP BY SL.Storerkey, SL.Sku, SL.Loc, L.LocationType, L.Pickzone, L.PutawayZone, L.Facility, L.LogicalLocation
   ORDER BY L.LogicalLocation, SL.Loc
)


GO