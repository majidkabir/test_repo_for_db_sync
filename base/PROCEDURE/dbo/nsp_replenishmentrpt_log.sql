SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: nsp_ReplenishmentRpt_LOG                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 13-Apr-2011  SPChin        SOS#212281 - Performance tuning           */
/* 14-May-2019  WLCHOOI       Add return field and pass in Storerkey    */  
/*                            (Optional) (WL01)                         */
/************************************************************************/

CREATE PROC [dbo].[nsp_ReplenishmentRpt_LOG]
     @c_zone01    NVARCHAR(10)
   , @c_zone02    NVARCHAR(10)
   , @c_zone03    NVARCHAR(10)
   , @c_zone04    NVARCHAR(10)
   , @c_zone05    NVARCHAR(10)
   , @c_zone06    NVARCHAR(10)
   , @c_zone07    NVARCHAR(10)
   , @c_zone08    NVARCHAR(10)
   , @c_zone09    NVARCHAR(10)
   , @c_zone10    NVARCHAR(10)
   , @c_zone11    NVARCHAR(10)
   , @c_zone12    NVARCHAR(10)
   , @c_Storerkey NVARCHAR(15) = '' --Optional (WL01)
AS
BEGIN

   SET NOCOUNT ON -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_thfont NVARCHAR(1)

   SELECT @c_thfont = NSQLValue
   FROM NSQLConfig WITH (NOLOCK)
   WHERE ConfigKey = 'IDSTHFONT'

   IF(@c_zone02 = 'ALL')
   BEGIN
      -- SOS#212281
   	SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
   	       SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CaseCnt, PACKUOM1, PACKUOM3,
             ReplenishmentKey, R.Remark, R.Confirmed, ISNULL(@c_thfont, 0), R.ReplenishmentGroup   --WL01
   	FROM REPLENISHMENT R WITH (NOLOCK)
   	JOIN SKU WITH (NOLOCK) ON (SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey)
   	JOIN LOC WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
   	JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   	LEFT JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWPENDREPLONLY'  --WL01
                                   AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report_log' AND ISNULL(CLR.Short,'') <> 'N')--WL01
   	WHERE Loc.Facility = @c_zone01
      AND (LEN(ISNULL(RTRIM(R.ReplenNo),'')) = 0 OR CLR.Code IS NOT NULL)             --WL01
      AND R.Confirmed = CASE WHEN CLR.Code IS NOT NULL THEN 'N' ELSE R.Confirmed END  --WL01
      AND R.Storerkey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                   R.StorerKey ELSE @c_StorerKey END    
   END
   ELSE
   BEGIN
      -- SOS#212281
   	SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,
   	       SKU.Descr, R.Priority, LOC.PutawayZone, PACK.CaseCnt, PACKUOM1, PACKUOM3,
             ReplenishmentKey, R.Remark, R.Confirmed, ISNULL(@c_thfont, 0), R.ReplenishmentGroup   --WL01
   	FROM REPLENISHMENT R WITH (NOLOCK)
   	JOIN SKU WITH (NOLOCK) ON (SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey)
   	JOIN LOC WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
   	JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
   	LEFT JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWPENDREPLONLY'  --WL01
                                   AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report_log' AND ISNULL(CLR.Short,'') <> 'N')--WL01
   	WHERE (LEN(ISNULL(RTRIM(R.ReplenNo),'')) = 0 OR CLR.Code IS NOT NULL) --WL01
      AND LOC.putawayzone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07,
                              @c_zone08, @c_zone09, @c_zone10, @c_zone11, @c_zone12)
      AND Loc.Facility = @c_zone01
      AND R.Storerkey = CASE WHEN @c_StorerKey = 'ALL' OR @c_StorerKey = '' THEN  
                                   R.StorerKey ELSE @c_StorerKey END
      AND R.Confirmed = CASE WHEN CLR.Code IS NOT NULL THEN 'N' ELSE R.Confirmed END  --WL01
   END
END

GO