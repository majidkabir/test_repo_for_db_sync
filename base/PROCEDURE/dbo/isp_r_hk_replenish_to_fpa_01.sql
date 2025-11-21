SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenish_to_fpa_01                        */
/* Creation Date: 10-Aug-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Replenishment Report FPA (refer to r_dw_replenish_to_fpa)    */
/*                                                                       */
/* Called By: RCM - Popup Replenishment FPA Report in Loadplan/Waveplan  */
/*            Datawidnow r_hk_replenish_to_fpa_01                        */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 26/10/2017   Michael  1.1  Reassign DropID to Flow Rack Locations     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_replenish_to_fpa_01] (
       @as_Key_Type  NVARCHAR(13)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TEMP_FLOWRACKLOC') IS NOT NULL
      DROP TABLE #TEMP_FLOWRACKLOC
   IF OBJECT_ID('tempdb..#TEMP_REPLENPICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_REPLENPICKDETAIL

   DECLARE @cDataWidnow     NVARCHAR(40)
         , @n_StartTCnt     INT
         , @c_Type          NVARCHAR(2)
         , @c_Key           NVARCHAR(10)
         , @c_FR_PAZone     NVARCHAR(10)
         , @c_FR_StartLoc   NVARCHAR(20)
         , @c_PickdetailKey NVARCHAR(18)
         , @c_DropID        NVARCHAR(20)
         , @c_Loc           NVARCHAR(10)

   SELECT @cDataWidnow     = 'r_hk_replenish_to_fpa_01'
        , @n_StartTCnt     = @@TRANCOUNT
        , @c_Key           = LEFT(@as_Key_Type, 10)
        , @c_Type          = RIGHT(@as_Key_Type, 2)

   BEGIN TRY
      EXEC nsp_ReplenishToFPA @as_Key_Type
      WITH RESULT SETS NONE
   END TRY
   BEGIN CATCH
   END CATCH

   -- Reassign DropID to Flow Rack Locations
   IF @c_Type = 'WP' AND @c_Key <> ''
   BEGIN
      SELECT @c_FR_PAZone   = ''
           , @c_FR_StartLoc = ''

      -- Get Flow Rack PutawayZone
      SELECT TOP 1
             @c_FR_PAZone = (select top 1 b.ColValue
                             from dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes) a, dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes2) b
                             where a.SeqNo=b.SeqNo and a.ColValue='FlowRackPutawayzone')
        FROM dbo.ORDERS OH (NOLOCK)
        JOIN (
           SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
                , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
             FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@cDataWidnow AND Short='Y'
        ) RptCfg
        ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1

      -- Get Starting Loc
      SELECT @c_FR_StartLoc = Userdefine02
        FROM dbo.WAVE (NOLOCK)
       WHERE Wavekey = @c_Key

      IF ISNULL(@c_FR_PAZone,'') <> '' AND ISNULL(@c_FR_StartLoc,'') <> ''
      BEGIN
         -- Get Flow Rack Locations
         SELECT Loc
              , SeqNo = CASE WHEN SeqNo>StartSeqNo THEN SeqNo - StartSeqNo ELSE SeqNo - StartSeqNo + LocCount END
           INTO #TEMP_FLOWRACKLOC
           FROM (
              SELECT Loc        = Loc
                   , SeqNo      = ROW_NUMBER() OVER(ORDER BY LogicalLocation, Loc)
                   , StartSeqNo = (SELECT COUNT(1) FROM dbo.LOC (NOLOCK) WHERE PutawayZone = @c_FR_PAZone AND Loc < ISNULL(@c_FR_StartLoc,''))
                   , LocCount   = (SELECT COUNT(1) FROM dbo.LOC (NOLOCK) WHERE PutawayZone = @c_FR_PAZone)
              FROM dbo.LOC (NOLOCK)
              WHERE PutawayZone = @c_FR_PAZone
           ) a
         
         -- Get Replen Pickdetail
         SELECT Orderkey = b.Orderkey
              , DropID   = b.DropID
              , SeqNo    = ROW_NUMBER() OVER(ORDER BY b.Orderkey, b.DropID)
           INTO #TEMP_REPLENPICKDETAIL
           FROM dbo.ORDERS     a (NOLOCK)
           JOIN dbo.PICKDETAIL b (NOLOCK) ON (a.Orderkey = b.Orderkey)
           LEFT JOIN #TEMP_FLOWRACKLOC c ON b.DropID = c.Loc
          WHERE b.Qty > 0 AND b.DropID <> '' AND b.ToLoc <> ''
            AND a.Userdefine09 = @c_Key
            AND c.Loc IS NULL
          GROUP BY b.Orderkey, b.DropID

         -- Assign Flow Rack Locations to Pickdetail.DropID
         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickdetailKey, PD.DropID, Y.Loc
           FROM dbo.PICKDETAIL PD
           JOIN #TEMP_REPLENPICKDETAIL X ON PD.Orderkey = X.Orderkey AND PD.DropID = X.DropID
           JOIN #TEMP_FLOWRACKLOC      Y ON X.SeqNo = Y.SeqNo
          WHERE PD.Qty > 0 AND PD.DropID <> '' AND PD.ToLoc <> ''
          ORDER BY PD.PickdetailKey

         OPEN CUR_PICKDETAIL 
         
         WHILE 1=1
         BEGIN
            FETCH NEXT FROM CUR_PICKDETAIL
             INTO @c_PickdetailKey, @c_DropID, @c_Loc
      
            IF @@FETCH_STATUS<>0
               BREAK

            UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
               SET DropID = @c_Loc, TrafficCop = NULL
             WHERE PickdetailKey = @c_PickdetailKey AND DropID = @c_DropID
         END

         CLOSE CUR_PICKDETAIL
         DEALLOCATE CUR_PICKDETAIL
      END
   END


   SELECT ReplenNo         = RTRIM ( PIK.ReplenNo )
        , Div              = RTRIM ( PIK.Div )
        , PutawayZone      = RTRIM ( PIK.PutawayZone )
        , Facility         = RTRIM ( PIK.Facility )
        , StorerKey        = RTRIM ( PIK.StorerKey )
        , Sku              = RTRIM ( PIK.Sku )
        , Descr            = RTRIM ( PIK.Descr )
        , AltSku           = RTRIM ( PIK.AltSku )
        , LogicalLocation  = RTRIM ( PIK.LogicalLocation )
        , FromLoc          = RTRIM ( PIK.FromLoc )
        , FromID           = RTRIM ( PIK.FromID )
        , ToFacility       = RTRIM ( PIK.ToFacility )
        , ToLoc            = RTRIM ( PIK.ToLoc )
        , DropId           = RTRIM ( PIK.DropId )
        , Lottable02       = RTRIM ( PIK.Lottable02 )
        , Lottable04       = PIK.Lottable04
        , TotalQty         = PIK.TotalQty
        , PackKey          = PIK.PackKey
        , CaseCnt          = PIK.CaseCnt
        , CartonQty        = CASE WHEN PIK.CaseCnt>0 THEN CEILING(PIK.TotalQty / PIK.CaseCnt) ELSE 0 END
        , PACKUOM1         = 'CS'
        , PACKUOM3         = RTRIM ( PIK.PACKUOM3 )
        , PA_LoosePiece    = CASE WHEN PIK.CaseCnt>0 THEN PIK.TotalQty - CEILING(PIK.TotalQty / PIK.CaseCnt) * PIK.CaseCnt ELSE 0 END

        , Suggest_PA_Loc   = CAST( SUBSTRING(
                           ( SELECT TOP 3 ', ', RTRIM(a.Loc)
                             FROM dbo.LOTXLOCXID a(NOLOCK)
                             JOIN dbo.LOC b(NOLOCK) ON (a.Loc = b.Loc)
                             JOIN dbo.LOTATTRIBUTE c(NOLOCK) ON (a.Lot = c.Lot)
                             WHERE a.Storerkey = PIK.Storerkey AND a.Sku = PIK.Sku
                               AND b.Facility = PIK.Facility
                               AND c.Lottable02 = PIK.Lottable02 AND ISNULL(c.Lottable04,'') = ISNULL(PIK.Lottable04,'')
                               AND b.LocationType = 'PICK' AND b.LocationCategory <> 'SELECTIVE'
                               AND b.LocationFlag <> 'HOLD' AND b.LocationFlag <> 'DAMAGE' AND b.Status <> 'HOLD'
                             GROUP BY RTRIM(a.Loc)
                             ORDER BY CASE WHEN SUM(a.Qty) > 0 THEN 0 ELSE 1 END
                                    , MIN(b.LogicalLocation)
                                    , RTRIM(a.Loc)
                             FOR XML PATH('')),3,50) AS NVARCHAR(50) )

        , UserName         = RTRIM ( PIK.UserName )
        , datawindow       = @cDataWidnow

   FROM (
      SELECT ReplenNo         = RTRIM ( CASE @c_Type WHEN 'WP' THEN OH.Userdefine09 WHEN 'LP' THEN OH.Loadkey ELSE '' END )
           , Div              = RTRIM ( MAX ( SKU.BUSR3 ) )
           , PutawayZone      = RTRIM ( MAX ( FRLOC.PutawayZone ) )
           , Facility         = RTRIM ( MAX ( FRLOC.Facility ) )
           , StorerKey        = RTRIM ( PD.StorerKey )
           , Sku              = RTRIM ( PD.Sku )
           , Descr            = RTRIM ( MAX ( SKU.Descr ) )
           , AltSku           = RTRIM ( MAX ( ISNULL(SKU.AltSku, '') ) )
           , LogicalLocation  = RTRIM ( MAX ( FRLOC.LogicalLocation ) )
           , FromLoc          = RTRIM ( PD.Loc )
           , FromID           = RTRIM ( PD.Id )
           , ToFacility       = RTRIM ( MAX ( TOLOC.Facility ) )
           , ToLoc            = RTRIM ( PD.ToLoc )
           , DropId           = RTRIM ( PD.DropId )
           , Lottable02       = RTRIM ( LA.Lottable02 )
           , Lottable04       = LA.Lottable04
           , TotalQty         = SUM(PD.Qty)
           , PackKey          = RTRIM ( MAX ( SKU.PackKey ) )
           , CaseCnt          = CASE WHEN ISNUMERIC( LA.Lottable06 )=1 THEN CONVERT(FLOAT,LA.Lottable06) ELSE 0 END
           , PACKUOM3         = MAX ( PACK.PACKUOM3 )
           , UserName         = RTRIM ( suser_sname() )

      FROM  dbo.ORDERS       OH (NOLOCK)
      JOIN  dbo.PICKDETAIL   PD (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
      JOIN  dbo.SKU         SKU (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.Storerkey = PD.Storerkey)
      JOIN  dbo.LOC       FRLOC (NOLOCK) ON (FRLOC.Loc = PD.Loc)
      JOIN  dbo.PACK       PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN  dbo.LOTATTRIBUTE LA (NOLOCK) ON (PD.Lot = LA.Lot)
      LEFT JOIN dbo.LOC   TOLOC (NOLOCK) ON (TOLOC.Loc = PD.ToLoc AND PD.ToLoc<>'')

      WHERE PD.Qty > 0 AND PD.DropID <> '' AND PD.ToLoc <> ''
        AND @c_Key <> ''
        AND ( @c_Type = 'WP' OR @c_Type = 'LP' )
        AND ((@c_Type = 'WP' AND OH.Userdefine09 = @c_Key)
          OR (@c_Type = 'LP' AND OH.Loadkey = @c_Key)
            )

      GROUP BY RTRIM ( CASE @c_Type WHEN 'WP' THEN OH.Userdefine09 WHEN 'LP' THEN OH.Loadkey ELSE '' END )
             , PD.StorerKey
             , PD.Sku
             , PD.Loc
             , PD.Id
             , PD.ToLoc
             , PD.DropId
             , LA.Lottable02
             , LA.Lottable04
             , CASE WHEN ISNUMERIC( LA.Lottable06 )=1 THEN CONVERT(FLOAT,LA.Lottable06) ELSE 0 END
   ) PIK

   ORDER BY ReplenNo, Div, PutawayZone, LogicalLocation, FromLoc, SKU, Lottable02, Lottable04


   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO