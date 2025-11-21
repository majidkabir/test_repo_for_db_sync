SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_batch_pickslip_01                    */
/*                   modified from nsp_GetPickSlipALL (ver 22-Jun-2017)  */
/* Creation Date: 06-Dec-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Batch Pickslip                                               */
/*                                                                       */
/* Called By: RCM - Print Batch Pick Slips in LoadPlan                   */
/*            Datawidnow r_hk_print_batch_pickslip_01                    */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2020-11-05   ML       1.1  WMS-15645 - Add Movable Unit               */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_print_batch_pickslip_01] (
       @c_Loadkey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_PickHeaderkey    NVARCHAR(10)
         , @c_Route            NVARCHAR(10)
         , @c_Route_Desc       NVARCHAR(60)
         , @c_TrfRoom          NVARCHAR(10)
         , @c_Notes1           NVARCHAR(80)
         , @n_RowNo            INT
         , @c_Notes2           NVARCHAR(80)
         , @c_Loc              NVARCHAR(10)
         , @c_Sku              NVARCHAR(20)
         , @c_SkuDesc          NVARCHAR(60)
         , @n_Qty              INT
         , @c_UOM              NVARCHAR(10)
         , @n_UOMQty           INT
         , @c_PrintedFlag      NVARCHAR(1)
         , @c_Lot              NVARCHAR(10)
         , @c_VehicleNo        NVARCHAR(10)
         , @c_Lottable02       NVARCHAR(18)
         , @d_Lottable04       DATETIME
         , @n_AlLocatedCube    FLOAT
         , @n_AlLocatedWeight  FLOAT
         , @c_ZoneDesc         NVARCHAR(60)
         , @d_DeliveryDate     DATETIME
         , @n_CaseCnt          INT
         , @c_logicalLoc       NVARCHAR(18)
         , @n_InnerPack        INT
         , @c_AltSku           NVARCHAR(20)
         , @c_ShowField        NVARCHAR(1)
         , @c_SkuSUSR3         NVARCHAR(30)
         , @c_Lottable06       NVARCHAR(30)
         , @c_Facility         NVARCHAR(5)
         , @c_Delivery_zone    NVARCHAR(30)
         , @c_ExternLoadkey    NVARCHAR(30)
         , @c_ID               NVARCHAR(20)

   DECLARE @n_continue         INT
         , @c_errmsg           NVARCHAR(255)
         , @b_success          INT
         , @n_err              INT
         , @c_Storerkey        NVARCHAR(15)
         , @c_GetStorerkey     NVARCHAR(15)


   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAIL


   CREATE TABLE #TEMP_PICKDETAIL (
        PickSlipNo       NVARCHAR(10) NULL
      , Loadkey          NVARCHAR(10) NULL
      , Route            NVARCHAR(10) NULL
      , Route_Desc       NVARCHAR(60) NULL
      , TrfRoom          NVARCHAR(10) NULL
      , Notes1           NVARCHAR(80) NULL
      , Notes2           NVARCHAR(80) NULL
      , Loc              NVARCHAR(10) NULL
      , Sku              NVARCHAR(20) NULL
      , SkuDesc          NVARCHAR(60) NULL
      , Qty              INT          NULL
      , TempQty1         INT          NULL
      , TempQty2         INT          NULL
      , PrintedFlag      NVARCHAR(1)  NULL
      , Zone             NVARCHAR(1)  NULL
      , PgGroup          INT          NULL
      , RowNum           INT          NULL
      , Lot              NVARCHAR(10) NULL
      , VehicleNo        NVARCHAR(10) NULL
      , Lottable02       NVARCHAR(18) NULL
      , Lottable04       DATETIME     NULL
      , AlLocatedCube    FLOAT        NULL
      , AlLocatedWeight  FLOAT        NULL
      , ZoneDesc         NVARCHAR(60) NULL
      , DeliveryDate     DATETIME     NULL
      , CaseCnt          INT          NULL
      , LogicalLocation  NVARCHAR(18) NULL
      , InnerPack        INT          NULL
      , AltSku           NVARCHAR(20) NULL
      , Showfield        NVARCHAR(1)  NULL
      , SUSR3            NVARCHAR(30) NULL
      , Lottable06       NVARCHAR(30) NULL
      , Facility         NVARCHAR(5)  NULL
      , Delivery_Zone    NVARCHAR(30) NULL
      , ExternLoadkey    NVARCHAR(30) NULL
      , ID               NVARCHAR(20) NULL
   )


   DECLARE @b_debug           INT,
           @c_PickslipExists  NVARCHAR(1),
           @c_ExistPickSlipNo NVARCHAR(10)

   SELECT @b_debug     = 0
        , @n_continue  = 1
        , @n_RowNo     = 0
        , @c_ShowField = 'N'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  , 9 - All UOM
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLocK)
             WHERE ExternOrderkey = @c_Loadkey AND Zone = '9')
   BEGIN
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_PrintedFlag = 'N'
   END

   SELECT TOP 1
          @c_GetStorerkey = ISNULL(RTRIM(Storerkey),'')
     FROM PickDetail     PD  WITH (NOLocK)
     JOIN LoadPlandetail LPD WITH (NOLocK) ON LPD.OrderKey = PD.OrderKey
    WHERE LPD.Loadkey = @c_Loadkey

   SELECT @c_ShowField = CASE WHEN ISNULL(CLK.Code,'') <> '' THEN 'Y' ELSE 'N' END
     FROM Codelkup CLK (NOLocK)
    WHERE CLK.Storerkey = @c_GetStorerkey
      AND CLK.Code = N'SHOWFIELD'
      AND CLK.Listname = N'REPORTCFG'
      AND CLK.Long = 'd_dw_print_combined_pickslip' AND ISNULL(CLK.Short,'') <> 'N'

   IF @b_debug = 1 SELECT '@c_printedflag', @c_printedflag

   BEGIN TRAN

   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER WITH(ROWLocK)
      SET PickType = '1',
          TrafficCop = NULL
    WHERE ExternOrderkey = @c_Loadkey
      AND Zone = '9'
      AND PickType = '0'

   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         ROLLBACK TRAN
      END
   END

   -- check if pickslip exists
   IF EXISTS( SELECT 1 FROM PICKHEADER WITH (NOLocK) WHERE ExternOrderkey = @c_Loadkey AND ZONE = '9' )
   BEGIN
      SELECT @c_PickslipExists = '1'
      SELECT @c_ExistPickSlipNo = PickHeaderkey FROM Pickheader WITH (NOLocK) WHERE ExternOrderkey = @c_Loadkey and Zone = '9'
      IF @b_debug = 1 SELECT 'Pickslipexists = 1'
   END
   ELSE
   BEGIN
      SELECT @c_PickslipExists = '0'
      IF @b_debug = 1 SELECT 'Pickslipexists = 0'
   END

   IF EXISTS (SELECT 1 FROM NSQLCONFIG WITH (NOLocK) WHERE CONFIGKEY = N'RF_BATCH_PICK' AND NSQLVALUE = '1') -- batch picking turned on,
   BEGIN
      IF @c_PickslipExists = '1'
      BEGIN
         DECLARE PICK_CUR CURSOR LocAL FAST_FORWARD READ_ONLY FOR
         SELECT RTRIM(PD.Sku)
              , RTRIM(PD.Loc)
              , SUM(PD.Qty)
              , RTRIM(PD.Storerkey)
              , RTRIM(PD.UOM)
              , RTRIM(Loc.LogicalLocation)
              , RTRIM(PD.Lot)
              , RTRIM(PD.ID)
           FROM LOADPLANDETAIL LPD WITH (NOLocK)
           JOIN ORDERS         OH  WITH (NOLocK) ON LPD.Orderkey = OH.Orderkey
           JOIN PICKDETAIL     PD  WITH (NOLocK) ON LPD.OrderKey = PD.OrderKey
           JOIN Loc            Loc WITH (NOLocK) ON PD.Loc = Loc.Loc
          WHERE LPD.Loadkey = @c_Loadkey
            AND PD.PickSlipNo = @c_ExistPickSlipNo
            AND OH.UserDefine08 = 'N' -- only unalLocated order flag are taken into consideration - used for loadplan alLocation only.
            AND ( PD.PickMethod = '8' OR PD.PickMethod = '' )
          GROUP BY PD.Sku
                 , PD.Loc
                 , PD.Storerkey
                 , PD.UOM
                 , Loc.LogicalLocation
                 , PD.Lot
                 , PD.ID
          ORDER BY PD.Sku, PD.Lot, PD.Loc, PD.ID
      END -- @c_PickslipExists = '1'
      ELSE
      BEGIN -- @c_PickslipExists = '0' -- we need to retrieve infromation where PickSlipNo is NULL
         DECLARE PICK_CUR CURSOR LocAL FAST_FORWARD READ_ONLY FOR
         SELECT RTRIM(PD.Sku)
              , RTRIM(PD.Loc)
              , SUM(PD.Qty)
              , RTRIM(PD.Storerkey)
              , RTRIM(PD.UOM)
              , RTRIM(Loc.LogicalLocation)
              , RTRIM(PD.Lot)
              , RTRIM(PD.ID)
           FROM LOADPLANDETAIL LPD WITH (NOLocK)
           JOIN ORDERS         OH  WITH (NOLocK) ON LPD.Orderkey = OH.Orderkey
           JOIN PICKDETAIL     PD  WITH (NOLocK) ON LPD.OrderKey = PD.OrderKey
           JOIN Loc            Loc WITH (NOLocK) ON PD.Loc = Loc.Loc
          WHERE LPD.Loadkey = @c_Loadkey
            AND PD.Status < '5'
            AND ISNULL(PD.PickSlipNo,'') = '' --only selects those without task
            AND OH.UserDefine08 = 'N' -- only unalLocated order flag are taken into consideration - used for loadplan alLocation only.
            AND (PD.Pickmethod = '8' OR PD.Pickmethod = '') -- user wants it to be on lists
          GROUP BY PD.Sku
                 , PD.Loc
                 , PD.Storerkey
                 , PD.UOM
                 , Loc.LogicalLocation
                 , PD.Lot
                 , PD.ID
          ORDER BY PD.Sku, PD.Lot, PD.Loc, PD.ID
      END -- @c_PickslipExists = '0'
   END
   ELSE
   BEGIN
      IF @c_PickslipExists = '1'
      BEGIN --@c_PickslipExists = '1'
         DECLARE PICK_CUR CURSOR LocAL FAST_FORWARD READ_ONLY FOR
         SELECT RTRIM(PD.Sku)
              , RTRIM(PD.Loc)
              , SUM(PD.Qty)
              , RTRIM(PD.Storerkey)
              , RTRIM(PD.UOM)
              , RTRIM(Loc.LogicalLocation)
              , RTRIM(PD.Lot)
              , RTRIM(PD.ID)
           FROM LOADPLANDETAIL LPD WITH (NOLocK)
           JOIN ORDERS         OH  WITH (NOLocK) ON LPD.Orderkey = OH.Orderkey
           JOIN PICKDETAIL     PD  WITH (NOLocK) ON LPD.OrderKey = PD.OrderKey
           JOIN Loc            Loc WITH (NOLocK) ON PD.Loc = Loc.Loc
          WHERE LPD.Loadkey = @c_Loadkey
            AND PD.Status < '5'
            AND OH.UserDefine08 = 'N' -- only unalLocated order flag are taken into consideration - used for loadplan alLocation only.
          GROUP BY PD.Sku
                 , PD.Loc
                 , PD.Storerkey
                 , PD.UOM
                 , Loc.LogicalLocation
                 , PD.Lot
                 , PD.ID
          ORDER BY PD.Sku, PD.Lot, PD.Loc, PD.ID
      END --@c_PickslipExists = '1'
      ELSE
      BEGIN -- @c_PickslipExists = '0'
         DECLARE PICK_CUR CURSOR LocAL FAST_FORWARD READ_ONLY FOR
         SELECT RTRIM(PD.Sku)
              , RTRIM(PD.Loc)
              , SUM(PD.Qty)
              , RTRIM(PD.Storerkey)
              , RTRIM(PD.UOM)
              , RTRIM(Loc.LogicalLocation)
              , RTRIM(PD.Lot)
              , RTRIM(PD.ID)
           FROM LOADPLANDETAIL LPD WITH (NOLocK)
           JOIN ORDERS         OH  WITH (NOLocK) ON OH.Orderkey = LPD.Orderkey
           JOIN PICKDETAIL     PD  WITH (NOLocK) ON PD.OrderKey = LPD.OrderKey
           JOIN Loc            Loc WITH (NOLocK) ON Loc.Loc = PD.Loc
          WHERE LPD.Loadkey = @c_Loadkey
            AND PD.Status < '5'
            AND ISNULL(PD.PickSlipNo,'') = ''
            AND OH.UserDefine08 = 'N' -- only unalLocated order flag are taken into consideration - used for loadplan alLocation only.
          GROUP BY PD.Sku
                 , PD.Loc
                 , PD.Storerkey
                 , PD.UOM
                 , Loc.LogicalLocation
                 , PD.Lot
                 , PD.ID
          ORDER BY PD.Sku, PD.Lot, PD.Loc, PD.ID
      END -- @c_PickslipExists = '0'
   END
   OPEN PICK_CUR

   FETCH NEXT FROM PICK_CUR INTO @c_Sku, @c_Loc, @n_Qty, @c_Storerkey, @c_UOM, @c_logicalLoc, @c_Lot, @c_ID

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF EXISTS( SELECT 1 FROM PICKHEADER WITH (NOLocK) WHERE ExternOrderkey = @c_Loadkey AND ZONE = '9' )
      BEGIN
         IF @b_debug = 1 SELECT 'Pickslip Exists'
         SELECT @c_PickHeaderkey = PickHeaderkey FROM PickHeader WITH (NOLocK)
          WHERE ExternOrderkey = @c_Loadkey AND Zone = '9'
      END
      ELSE
      BEGIN  -- IF NOT EXISTS
         IF @b_debug= 1 SELECT 'Pickslip not yet exist'

         EXECUTE nspg_GetKey
                 'PICKSLIP'
               , 9
               , @c_PickHeaderkey OUTPUT
               , @b_success       OUTPUT
               , @n_err           OUTPUT
               , @c_errmsg        OUTPUT
         SELECT @c_PickHeaderkey = 'P' + @c_PickHeaderkey

         BEGIN TRAN

         INSERT INTO PICKHEADER WITH(ROWLocK)
                (PickHeaderkey,    ExternOrderkey, PickType, Zone, TrafficCop)
         VALUES (@c_PickHeaderkey, @c_Loadkey,     '0',      '9',  '')

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            IF @@TRANCOUNT >= 1
            BEGIN
               ROLLBACK TRAN
            END
         END
         ELSE
         BEGIN
            IF @@TRANCOUNT > 0
               COMMIT TRAN
            ELSE
               ROLLBACK TRAN

            -- Update pickdetail with the PickSlipNo.
            IF EXISTS (SELECT 1 FROM NSQLCONFIG WITH (NOLocK) WHERE CONFIGKEY = N'RF_BATCH_PICK' AND NSQLVALUE = '1') -- batch picking turned on,
            BEGIN   -- we have RF batch pick.
               UPDATE PD WITH (ROWLocK)
                  SET PickSlipNo = @c_PickHeaderkey
                    , Trafficcop = NULL
                    , EDITDATE   = GETDATE()
                 FROM LOADPLANDETAIL LPD WITH (NOLocK)
                 JOIN ORDERS         OH  WITH (NOLocK) ON LPD.Orderkey = OH.Orderkey
                 JOIN PICKDETAIL     PD                ON LPD.Orderkey = PD.Orderkey
                WHERE LPD.Loadkey = @c_Loadkey
                  AND OH.UserDefine08 = 'N'
                  AND PD.Status < '5'
                  AND PD.PickSlipNo IS NULL
                  AND ( PD.Pickmethod = '8' OR PD.Pickmethod = '') -- includes manual picks.
            END
            ELSE
            BEGIN
               UPDATE PD WITH (ROWLocK)
                  SET PickSlipNo = @c_PickHeaderkey
                    , Trafficcop = NULL
                    , EDITDATE   = GETDATE()
                 FROM LOADPLANDETAIL LPD WITH (NOLocK)
                 JOIN ORDERS         OH  WITH (NOLocK) ON LPD.Orderkey = OH.Orderkey
                 JOIN PICKDETAIL     PD                ON LPD.Orderkey = PD.Orderkey
                WHERE LPD.Loadkey = @c_Loadkey
                  AND OH.UserDefine08 = 'N'
                  AND PD.Status < '5'
                  AND PD.PickSlipNo IS NULL
            END
         END
      END  -- while fetch_status

      SELECT @n_RowNo           = @n_RowNo + 1
           , @c_TrfRoom         = ''
           , @c_Route           = ''
           , @c_notes1          = ''
           , @c_notes2          = ''
           , @n_AlLocatedCube   = 0
           , @n_AlLocatedWeight = 0
           , @d_DeliveryDate    = NULL
           , @c_Facility        = ''
           , @c_Delivery_zone   = ''
           , @c_ExternLoadkey   = ''
           , @c_VehicleNo       = ''
           , @c_Route_Desc      = ''
           , @c_SkuDesc         = ''
           , @c_Lottable02      = ''
           , @d_Lottable04      = NULL
           , @c_Lottable06      = ''
           , @c_ZoneDesc        = ''
           , @c_AltSku          = ''
           , @n_casecnt         = 0
           , @n_innerpack       = 0
           , @n_UOMQty          = 0

      SELECT @c_TrfRoom         = RTRIM(ISNULL(LP.TrfRoom, ''))
           , @c_Route           = RTRIM(ISNULL(LP.Route, ''))
           , @c_notes1          = RTRIM(ISNULL(CONVERT(NVARCHAR(80), LP.Load_Userdef1), ''))
           , @c_notes2          = RTRIM(ISNULL(CONVERT(NVARCHAR(80), LP.Load_Userdef2), ''))
           , @n_AlLocatedCube   = ISNULL(LP.AlLocatedCube, 0)
           , @n_AlLocatedWeight = ISNULL(LP.AlLocatedWeight, 0)
           , @d_DeliveryDate    = LP.LPUSERDEFDATE01
           , @c_Facility        = RTRIM(ISNULL(LP.Facility,''))
           , @c_Delivery_zone   = RTRIM(CASE WHEN ISNULL(LP.Route, '')=ISNULL(LP.Delivery_Zone,'')
                                       THEN ISNULL(LP.Route, '')
                                       ELSE LTRIM(RTRIM(ISNULL(LP.Route, '')) +
                                            IIF(ISNULL(LP.Route,'')<>'' AND ISNULL(LP.Delivery_Zone,'')<>'', ', ', '') +
                                            LTRIM(ISNULL(LP.Delivery_Zone,'')))
                                  END)
           , @c_ExternLoadkey   = RTRIM(ISNULL(LP.ExternLoadkey,''))
        FROM LOADPLAN LP WITH (NOLocK)
       WHERE Loadkey = @c_Loadkey

      SELECT @c_VehicleNo = RTRIM(ISNULL(VH.VehicleNumber, ''))
        FROM IDS_LP_VEHICLE VH WITH (NOLocK)
       WHERE VH.Loadkey = @c_Loadkey
         AND VH.Linenumber = '00001' -- major vehicle

      SELECT @c_Route_Desc  = RTRIM(ISNULL(RM.Descr, ''))
        FROM RouteMaster RM WITH (NOLocK)
       WHERE RM.Route = @c_Route

      SELECT @c_SkuDesc  = RTRIM(ISNULL(SKU.Descr,''))
           , @c_SkuSUSR3 = RTRIM(SKU.BUSR10)
        FROM SKU WITH (NOLocK)
       WHERE SKU.Storerkey = @c_Storerkey AND SKU.Sku = @c_Sku

      SELECT @c_Lottable02 = RTRIM(ISNULL(LA.Lottable02, ''))
           , @d_Lottable04 = LA.Lottable04
           , @c_Lottable06 = RTRIM(ISNULL(LA.Lottable06, ''))
        FROM LOTATTRIBUTE LA WITH (NOLocK)
       WHERE LA.LOT = @c_Lot

      SELECT @c_ZoneDesc = RTRIM(PA.Descr)
        FROM Loc         LOC WITH (NOLocK)
        JOIN PUTAWAYZONE PA  WITH (NOLocK) ON LOC.PUTAWAYZONE = PA.PUTAWAYZONE
       WHERE LOC.Loc = @c_Loc

      SELECT @c_AltSku    = RTRIM(SKU.AltSku)
           , @n_casecnt   = PACK.CaseCnt
           , @n_innerpack = PACK.InnerPack
           , @n_UOMQty    = CASE @c_UOM
                            WHEN '1' THEN PACK.Pallet
                            WHEN '2' THEN PACK.CaseCnt
                            WHEN '3' THEN PACK.InnerPack
                            ELSE          1
                            END
        FROM SKU   WITH (NOLocK)
        JOIN PACK  WITH (NOLocK) ON SKU.PackKey = PACK.PackKey
       WHERE SKU.Storerkey = @c_Storerkey
         AND SKU.Sku = @c_Sku

      INSERT INTO #TEMP_PICKDETAIL (
            PickSlipNo,         Loadkey,            Route,
            Route_Desc,         TrfRoom,            Notes1,             RowNum,
            Notes2,             Loc,                Sku,
            SkuDesc,            Qty,                TempQty1,
            TempQty2,           PrintedFlag,        Zone,
            Lot,                VehicleNo,          Lottable02,
            Lottable04,         AlLocatedCube,      AlLocatedWeight,
            ZoneDesc,           DeliveryDate,       CaseCnt,
            LogicalLocation,    InnerPack,          AltSku,
            showfield,          SUSR3,              lottable06,
            Facility,           Delivery_zone,      ExternLoadkey,
            ID
      )
      VALUES (
            @c_PickHeaderkey,   @c_Loadkey,         @c_Route,
            @c_Route_Desc,      @c_TrfRoom,         @c_Notes1,           @n_RowNo,
            @c_Notes2,          @c_Loc,             @c_Sku,
            @c_SkuDesc,         @n_Qty,             CAST(@c_UOM as int),
            @n_UOMQty,          @c_PrintedFlag,     '9',
            @c_Lot,             @c_VehicleNo,       @c_Lottable02,
            @d_Lottable04,      @n_AlLocatedCube,   @n_AlLocatedWeight,
            @c_ZoneDesc,        @d_DeliveryDate,    @n_casecnt,
            @c_logicalLoc,      @n_InnerPack,       @c_AltSku,
            @c_ShowField,       @c_SkuSUSR3,        @c_Lottable06,
            @c_Facility,        @c_Delivery_zone,   @c_ExternLoadkey,
            @c_ID
      )

      FETCH NEXT FROM PICK_CUR INTO @c_Sku, @c_Loc, @n_Qty, @c_Storerkey, @c_UOM, @c_logicalLoc, @c_Lot, @c_ID
   END
   CLOSE PICK_CUR
   DEALLocATE PICK_CUR


   SELECT *
   FROM #TEMP_PICKDETAIL

   DROP TABLE #TEMP_PICKDETAIL

END

GO