SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipALL_FPA                             */
/* Creation Date: 26-Dec-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose: SOS#62931 - Replensihment Report for IDSHK LOR principle    */
/*          - Replenish To Forward Pick Area (FPA)                      */
/*          - Printed together with Move Ticket & Pickslip in a         */
/*            composite report                                          */
/*                                                                      */
/* Called By: RCM - Popup Pickslip in Loadplan / WavePlan               */
/*            Modified from nsp_GetPickSlipALL                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 15-Dec-2018  TLTING01  1.1   Missing nolock                          */
/************************************************************************/


CREATE PROC [dbo].[nsp_GetPickSlipALL_FPA] (
           @c_loadkey_type NVARCHAR(1113)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
-- This is batch pick slip.
-- Modified by Jeff - 12-Nov-2002 Manual picks have pickmethod = ' '. Therefore, we want to include that on the pick list
-- 8-APR-2004 (SOS20748) Add Unilever Hong Kong Pick Confirm interface

   DECLARE @c_pickheaderkey NVARCHAR(10),
   @n_continue         int,
   @c_errmsg           NVARCHAR(255),
   @b_success          int,
   @n_err              int,
   @c_sku              NVARCHAR(20),
   @n_qty              int,
   @c_loc              NVARCHAR(10),
   @n_cases            int,
   @n_perpallet        int,
   @c_orderkey         NVARCHAR(10),
   @c_storer           NVARCHAR(15),
   @c_ConsigneeKey     NVARCHAR(15),
   @c_Company          NVARCHAR(45),
   @c_Addr1            NVARCHAR(45),
   @c_Addr2            NVARCHAR(45),
   @c_Addr3            NVARCHAR(45),
   @c_PostCode         NVARCHAR(15),
   @c_Route            NVARCHAR(10),
   @c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
   @c_TrfRoom          NVARCHAR(10),  -- wave.TrfRoom
   @c_Notes1           NVARCHAR(80),
   @c_Notes2           NVARCHAR(80),
   @c_SkuDesc          NVARCHAR(60),
   @n_CaseCnt          int,
   @n_PalletCnt        int,
   @n_InnerPack        int,
   @c_ReceiptTm        NVARCHAR(20),
   @c_PrintedFlag      NVARCHAR(1),
   @c_UOM              NVARCHAR(10),
   @n_UOM3             int,
   @c_Lot              NVARCHAR(10),
   @c_StorerKey        NVARCHAR(15),
   @c_Zone             NVARCHAR(1),
   @n_PgGroup          int,
   @n_TotCases         int,
   @n_RowNo            int,
   @c_PrevSKU          NVARCHAR(20),
   @n_SKUCount         int,
   @c_Carrierkey       NVARCHAR(60),
   @c_VehicleNo        NVARCHAR(10),
   @c_firstorderkey    NVARCHAR(10),
   @c_superorderflag   NVARCHAR(1),
   @c_firsttime        NVARCHAR(1),
   @c_logicalloc       NVARCHAR(18),
   @c_Lottable02       NVARCHAR(10),
   @d_Lottable04       datetime,
   @c_labelPrice       NVARCHAR(5),
   @c_externorderkey   NVARCHAR(30),
   @n_allocatedcube    float,
   @n_allocatedweight  float,
   @c_ZoneDesc         NVARCHAR(60),
   @d_deliverydate     datetime,
	@c_AltSKU			  NVARCHAR(20)

   DECLARE @c_PrevOrderKey     NVARCHAR(10),
           @n_Pallets          int,
           @n_Cartons          int,
           @n_Eaches           int,
           @n_UOMQty           int

   DECLARE @c_ToLoc            NVARCHAR(10),
           @c_MoveId           NVARCHAR(18),
           @c_loadkey          NVARCHAR(10),
           @c_Type             NVARCHAR(2),
           @c_ToLocZoneDesc    NVARCHAR(60)

   CREATE TABLE #temp_pick
    ( PickSlipNo       NVARCHAR(10) NULL,
      loadkey          NVARCHAR(10) NULL,
      Route            NVARCHAR(10) NULL,
      Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc
      TrfRoom          NVARCHAR(5)  NULL,  -- wave.TrfRoom
      Notes1           NVARCHAR(80) NULL,
      Notes2           NVARCHAR(80) NULL,
      LOC              NVARCHAR(10) NULL,
      SKU              NVARCHAR(20) NULL,
      SkuDesc          NVARCHAR(60) NULL,
      Qty              int      NULL,
      TempQty1         int      NULL,
      TempQty2         int      NULL,
      PrintedFlag      NVARCHAR(1)  NULL,
      Zone             NVARCHAR(1)  NULL,
      PgGroup          int      NULL,
      RowNum           int      NULL,
      Lot              NVARCHAR(10) NULL,
      VehicleNo        NVARCHAR(10) NULL,
      Lottable02       NVARCHAR(10) NULL,
      Lottable04       datetime NULL,
      AllocatedCube    float    NULL,
      AllocatedWeight  float    NULL,
      ZoneDesc         NVARCHAR(60) NULL,
      DeliveryDate     datetime NULL,
      CaseCnt          int      NULL,
      LogicalLocation  NVARCHAR(18) NULL,
      InnerPack        int      NULL,
		AltSKU			  NVARCHAR(20) NULL, -- SOS57249
      ToLoc            NVARCHAR(10) NULL,
      MoveId           NVARCHAR(18) NULL,
      ToLocZoneDesc    NVARCHAR(60) NULL)

   declare @b_debug int,
           @c_pickslipexists NVARCHAR(1),
           @c_existpickslipno NVARCHAR(10)
   select @b_debug = 0
   SELECT @n_continue = 1
   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = 'N'
   SELECT @c_loadkey = LEFT(@c_loadkey_type, 10)
   SELECT @c_Type = RIGHT(@c_loadkey_type,2)

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  , 9 - All UOM
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)
             WHERE externOrderkey = @c_loadkey
             AND   Zone = '9')
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   IF @b_debug = 1 SELECT '@c_printedflag', @c_printedflag, '@c_firsttime', @c_firsttime

   BEGIN TRAN

   -- Uses PickType as a Printed Flag
   UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
   WHERE externOrderkey = @c_loadkey
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
         -- SELECT @c_PrintedFlag = "Y"
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         ROLLBACK TRAN
      END
   END

   -- check if pickslip exists
   --tlting01
   IF EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE ExternOrderkey = @c_loadkey AND ZONE = '9' )
   BEGIN
      SELECT @c_pickslipexists = '1'
      SELECT @c_existpickslipno = PICKHEADERKEY from Pickheader (NOLOCK) where externorderkey = @c_loadkey and Zone = '9'
      IF @b_debug = 1 SELECT 'Pickslipexists = 1'
   END
   ELSE
   BEGIN
      SELECT @c_pickslipexists = '0'
      IF @b_debug = 1 SELECT 'Pickslipexists = 0'
   END
   IF EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE CONFIGKEY = 'RF_BATCH_PICK' AND NSQLVALUE = '1') -- batch picking turned on,
   BEGIN
      IF @c_pickslipexists = '1'
      BEGIN
         DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PickDetail.sku,       PickDetail.loc,
                SUM(PickDetail.qty),  PACK.Qty,
                PickDetail.storerkey, -- PickDetail.OrderKey,
                PickDetail.UOM,       LOC.LogicalLocation,
                Pickdetail.Lot,       Pickdetail.ToLoc,
                Pickdetail.DropID
         FROM   PickDetail (NOLOCK),  LoadPlandetail (NOLOCK),
                PACK (NOLOCK),        LOC (NOLOCK)  ,
                ORDERS (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlandetail.OrderKey
           AND  ORDERS.Orderkey = LoadPlanDetail.Orderkey
           AND  ORDERS.Orderkey = Pickdetail.Orderkey
           AND  ORDERS.UserDefine08 = 'N' -- only unallocated order flag are taken into consideration - used for loadplan allocation only.
           AND  PickDetail.Status < '5'
           AND  PickDetail.Packkey = PACK.Packkey
           AND  LOC.Loc = PICKDETAIL.Loc
           AND  LoadPlandetail.loadkey = @c_loadkey
			  -- Remarked by MaryVong on 24-Nov-2005 (SOS43327)
			  -- As configkey 'RF_BATCH_PICK' is turn on, 
			  -- PickDetail.PickSlipNo for both PickMethod = '8' and ' ' will be updated
			  -- AND  ( ( PICKDETAIL.Pickmethod = '8' AND PICKDETAIL.PickSlipNo = @c_ExistPickSLipNo )
			  --     or ( dbo.fnc_RTrim(PICKDETAIL.Pickmethod) IS NULL AND dbo.fnc_RTrim(PICKDETAIL.PickSlipNo) is NULL )) -- user wants it to be on lists or manual pick (pickmethod = ' ' )
			  AND  PICKDETAIL.PickSlipNo = @c_ExistPickSLipNo
           AND  ( PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = ' ' ) 
			  -- End of SOS43327
--         AND  ( dbo.fnc_LTrim(dbo.fnc_RTrim(PICKSLIPNO)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(PICKSLIPNO)) = '') --only selects those without task
         GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
                  PickDetail.storerkey, PICKDETAIL.UOM ,--   PickDetail.OrderKey,
                  LOC.LogicalLocation,  Pickdetail.Lot,      Pickdetail.ToLoc, 
                  Pickdetail.DropID
         ORDER BY PICKDETAIL.SKU, PIckdetail.Lot, Pickdetail.Loc
--       ORDER BY PICKDETAIL.ORDERKEY
      END -- @c_pickslipexists = '1'
      ELSE
      BEGIN -- @c_pickslipexists = '0' -- we need to retrieve infromation where pickslipno is NULL
         DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PickDetail.sku,       PickDetail.loc,
                SUM(PickDetail.qty),  PACK.Qty,
                PickDetail.storerkey, -- PickDetail.OrderKey,
                PickDetail.UOM,       LOC.LogicalLocation,
                Pickdetail.Lot,       Pickdetail.ToLoc,
                Pickdetail.DropID
         FROM   PickDetail (NOLOCK),  LoadPlandetail (NOLOCK),
                PACK (NOLOCK),        LOC (NOLOCK)  , ORDERS (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlandetail.OrderKey
           AND  ORDERS.Orderkey = LoadPlanDetail.Orderkey
           AND  ORDERS.Orderkey = Pickdetail.Orderkey
           AND  ORDERS.UserDefine08 = 'N' -- only unallocated order flag are taken into consideration - used for loadplan allocation only.
           AND  PickDetail.Status < '5'
           AND  PickDetail.Packkey = PACK.Packkey
           AND  LOC.Loc = PICKDETAIL.Loc
           AND  LoadPlandetail.loadkey = @c_loadkey
           AND  (PICKDETAIL.Pickmethod = '8' OR PICKDETAIL.Pickmethod = ' ') -- user wants it to be on lists
           AND  ( dbo.fnc_LTrim(dbo.fnc_RTrim(PICKSLIPNO)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(PICKSLIPNO)) = '') --only selects those without task
         GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
                  PickDetail.storerkey, PICKDETAIL.UOM ,--   PickDetail.OrderKey,
                  LOC.LogicalLocation,  Pickdetail.Lot,      Pickdetail.ToLoc,
                  Pickdetail.DropID
         ORDER BY PICKDETAIL.SKU, PIckdetail.Lot, Pickdetail.Loc
      END -- @c_pickslipexists = '0'
   END
   ELSE
   BEGIN
      IF @c_pickslipexists = '1'
      BEGIN --@c_pickslipexists = '1'
         DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PickDetail.sku,       PickDetail.loc,
                SUM(PickDetail.qty),  PACK.Qty,
                PickDetail.storerkey, -- PickDetail.OrderKey,
                PickDetail.UOM,       LOC.LogicalLocation,
                Pickdetail.Lot,       Pickdetail.ToLoc,
                Pickdetail.DropID
         FROM   PickDetail (NOLOCK),  LoadPlandetail (NOLOCK),
                PACK (NOLOCK),        LOC (NOLOCK)  , ORDERS (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlandetail.OrderKey
           AND  ORDERS.Orderkey = LoadPlanDetail.Orderkey
           AND  ORDERS.Orderkey = Pickdetail.Orderkey
           AND  ORDERS.UserDefine08 = 'N' -- only unallocated order flag are taken into consideration - used for loadplan allocation only.
           AND  PickDetail.Status < '5'
           AND  PickDetail.Packkey = PACK.Packkey
           AND  LOC.Loc = PICKDETAIL.Loc
           AND  LoadPlandetail.loadkey = @c_loadkey
--         AND  PICKDETAIL.Pickmethod = '8'  -- for IF Batch picking turned off, we want to display all records
         GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
                  PickDetail.storerkey, PICKDETAIL.UOM,  -- PickDetail.OrderKey,
                  LOC.LogicalLocation,  Pickdetail.Lot,      Pickdetail.ToLoc,
                  Pickdetail.DropID
         ORDER BY PICKDETAIL.SKU, PIckdetail.Lot, Pickdetail.Loc
      END --@c_pickslipexists = '1'
      ELSE
      BEGIN -- @c_pickslipexists = '0'
         DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PickDetail.sku,       PickDetail.loc,
                SUM(PickDetail.qty),  PACK.Qty,
                PickDetail.storerkey, -- PickDetail.OrderKey,
                PickDetail.UOM,       LOC.LogicalLocation,
                Pickdetail.Lot,       Pickdetail.ToLoc,
                Pickdetail.DropID
         FROM   PickDetail (NOLOCK),  LoadPlandetail (NOLOCK),
                PACK (NOLOCK),        LOC (NOLOCK)  , ORDERS (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlandetail.OrderKey
           AND  ORDERS.Orderkey = LoadPlanDetail.Orderkey
           AND  ORDERS.Orderkey = Pickdetail.Orderkey
           AND  ORDERS.UserDefine08 = 'N' -- only unallocated order flag are taken into consideration - used for loadplan allocation only.
           AND  PickDetail.Status < '5'
           AND  PickDetail.Packkey = PACK.Packkey
           AND  LOC.Loc = PICKDETAIL.Loc
           AND  ( dbo.fnc_LTrim(dbo.fnc_RTrim(PICKSLIPNO)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(PICKSLIPNO)) = '')
           AND  LoadPlandetail.loadkey = @c_loadkey
         GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
                  PickDetail.storerkey, PICKDETAIL.UOM,  -- PickDetail.OrderKey,
                  LOC.LogicalLocation,  Pickdetail.Lot,      Pickdetail.ToLoc,
                  Pickdetail.DropID
         ORDER BY PICKDETAIL.SKU, PIckdetail.Lot, Pickdetail.Loc
      END -- @c_pickslipexists = '0'
   END
   OPEN pick_cur
   SELECT @c_PrevOrderKey = ''
   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,  -- @c_orderkey,
      @c_UOM, @c_logicalloc, @c_lot, @c_ToLoc, @c_MoveId
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN -- WHILE
--    IF @c_OrderKey <> @c_PrevOrderKey
--    BEGIN
      --tlting01
      IF EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE ExternOrderkey = @c_loadkey AND ZONE = '9' )
      BEGIN
         IF @b_debug = 1 SELECT 'Pickslip Exists'
         SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)
          WHERE externOrderkey = @c_loadkey
            AND   Zone = '9'
      END
--    IF NOT EXISTS( SELECT 1 FROM PICKHEADER WHERE ExternOrderkey = @c_loadkey AND ZONE = '9' )--AND OrderKey = @c_OrderKey )
      ELSE
      BEGIN  -- IF NOT EXISTS
         IF @b_debug= 1 SELECT 'Pickslip not yet exist'

         EXECUTE nspg_GetKey
         'PICKSLIP',
         9,
         @c_pickheaderkey     OUTPUT,
         @b_success     OUTPUT,
         @n_err         OUTPUT,
         @c_errmsg      OUTPUT
         SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

         BEGIN TRAN

         INSERT INTO PICKHEADER
         (PickHeaderKey,    ExternOrderkey, PickType, Zone, TrafficCop)
         VALUES
         (@c_pickheaderkey, @c_loadkey,     '0',      '9',  '')

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

            -- Update pickdetail with the pickslipno.
            IF EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE CONFIGKEY = 'RF_BATCH_PICK' AND NSQLVALUE = '1') -- batch picking turned on,
            BEGIN   -- we have RF batch pick.
               UPDATE PICKDETAIL
               SET PICKSLIPNO = @c_pickheaderkey, Trafficcop = null
               FROM PICKDETAIL P1(NOLOCK), LOADPLANDETAIL L1(NOLOCK), ORDERS O1 (NOLOCK)
               WHERE  L1.Orderkey = P1.Orderkey
                 AND  L1.Orderkey = O1.Orderkey
                 AND  P1.Orderkey = O1.Orderkey
                 AND  P1.Status < '5'
                 AND  O1.UserDefine08 = 'N'
                 AND  ( P1.Pickmethod = '8' OR P1.Pickmethod = ' ') -- includes manual picks.
                 AND  P1.Pickslipno IS NULL
                 AND  L1.Loadkey = @c_loadkey
            END
            ELSE
            BEGIN
               UPDATE PICKDETAIL
               SET PICKSLIPNO = @c_pickheaderkey, Trafficcop = null
               FROM PICKDETAIL P1(NOLOCK), LOADPLANDETAIL L1(NOLOCK), ORDERS O1 (NOLOCK)
               WHERE  L1.Orderkey = P1.Orderkey
                 AND  L1.Orderkey = O1.Orderkey
                 AND  P1.Orderkey = O1.Orderkey
                 AND  P1.Status < '5'
                 AND  O1.UserDefine08 = 'N'
                 AND  P1.Pickslipno IS NULL
                 AND  L1.Loadkey = @c_loadkey
            END
         END
      END  -- while fetch_status
/*         ELSE
         BEGIN
            SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)
            WHERE externOrderkey = @c_loadkey
            AND   Zone = "9"
         END
*/
      SELECT @c_TrfRoom   = IsNULL(LOADPLAN.TrfRoom, ''),
             @c_Route     = IsNULL(LOADPLAN.Route, ''),
--           @c_VehicleNo = IsNULL(LOADPLAN.TruckSize, ''),
             @c_Carrierkey = IsNULL(LOADPLAN.CarrierKey, ''),
             @c_notes1 = ISNULL(convert(NVARCHAR(80), LOADPLAN.Load_Userdef1), ''),
             @c_notes2 = ISNULL(convert(NVARCHAR(80), LOADPLAN.Load_Userdef2), ''),
             @n_allocatedcube = ISNULL(LOADPLAN.AllocatedCube, 0),
             @n_allocatedweight = ISNULL(LOADPLAN.AllocatedWeight, 0),
             @d_deliverydate = LOADPLAN.LPUSERDEFDATE01
      FROM   LOADPLAN (NOLOCK)
      WHERE  loadkey = @c_loadkey

      SELECT @c_vehicleno = ISNULL (IDS_LP_VEHICLE.VehicleNumber, '')
      FROM   IDS_LP_VEHICLE (NOLOCK)  --tlting01
      WHERE  Loadkey = @c_loadkey
        AND Linenumber = '00001' -- major vehicle

      SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, '')
      FROM   RouteMaster (NOLOCK)
      WHERE  Route = @c_Route

      SELECT @c_SkuDesc = IsNULL(Descr, '')
      FROM   SKU  (NOLOCK)
      WHERE  SKU = @c_SKU

      SELECT @c_Lottable02 = Lottable02,
             @d_Lottable04 = Lottable04
      FROM   LOTATTRIBUTE (NOLOCK)
      WHERE  LOT = @c_LOT

      SELECT @c_ZoneDesc = PUTAWAYZONE.Descr
      FROM LOC (nolock), PUTAWAYZONE (nolock)
      WHERE LOC.PUTAWAYZONE = PUTAWAYZONE.PUTAWAYZONE and
            LOC.LOC = @c_loc
      
      SELECT @c_ToLocZoneDesc = ''

      IF @c_toloc <> '' AND @c_toloc IS NOT NULL
      BEGIN
	      SELECT @c_ToLocZoneDesc = PUTAWAYZONE.Descr
	      FROM LOC (nolock), PUTAWAYZONE (nolock)
	      WHERE LOC.PUTAWAYZONE = PUTAWAYZONE.PUTAWAYZONE and
	            LOC.LOC = @c_toloc
      END

      IF @c_Lottable02    IS NULL SELECT @c_Lottable02 = ''
      IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = '01/01/1900'
      IF @c_Notes1        IS NULL SELECT @c_Notes1 = ''
      IF @c_Notes2        IS NULL SELECT @c_Notes2 = ''
      IF @c_Route         IS NULL SELECT @c_Route = ''
      IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ''
--       IF @c_superorderflag = "Y" SELECT @c_orderkey = ''

      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0,
             @n_Cartons = 0,
             @n_Eaches  = 0
      SELECT @n_UOMQty = 0
      SELECT @n_casecnt = CaseCnt,
             @n_innerpack = Pack.InnerPack,
             @n_UOMQty = CASE @c_UOM
                            WHEN '1' THEN PACK.Pallet
                            WHEN '2' THEN PACK.CaseCnt
                            WHEN '3' THEN PACK.InnerPack
                            ELSE 1
                         END,
				@c_AltSKU = AltSKU    -- SOS57249
      FROM   PACK (nolock), SKU (nolock)
      WHERE  SKU.SKU = @c_SKU
        AND  SKU.Storerkey = @c_storerkey
        AND    PACK.PackKey = SKU.PackKey

      INSERT INTO #Temp_Pick
           (PickSlipNo,          loadkey,          Route,
            Route_Desc,          TrfRoom,          Notes1,           
            RowNum,              Notes2,           LOC,              
            SKU,                 SkuDesc,          Qty,
            TempQty1,            TempQty2,         PrintedFlag,      
            Zone,                Lot,              VehicleNo,
            Lottable02,          Lottable04,       AllocatedCube,    
            AllocatedWeight,     ZoneDesc,         DeliveryDate,     
            CaseCnt,             LogicalLocation,  InnerPack,	
				AltSKU,              ToLoc,            MoveId,
            ToLocZoneDesc )
      VALUES
           (@c_pickheaderkey,   @c_loadkey,       @c_Route,
            @c_Route_Desc,      @c_TrfRoom,       @c_Notes1,       
            @n_RowNo,           @c_Notes2,        @c_LOC,           
            @c_SKU,             @c_SKUDesc,       @n_Qty,
            CAST(@c_UOM as int), @n_UOMQty,       @c_PrintedFlag,   
            '9',                @c_Lot,           @c_VehicleNo,     
            @c_Lottable02,      @d_Lottable04,    @n_Allocatedcube, 
            @n_AllocatedWeight, @c_ZoneDesc,      @d_deliverydate,  
            @n_casecnt,         @c_logicalloc,    @n_InnerPack,
				@c_AltSKU,          @c_ToLoc,         @c_MoveId,
            ISNULL(@c_ToLocZoneDesc, '') ) 

      FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
            @c_UOM, @c_logicalloc, @c_LOT, @c_ToLoc, @c_MoveId
   END
   CLOSE pick_cur
   DEALLOCATE pick_cur


   -- Begin SOS20748
   IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK)
              WHERE Storerkey = @c_StorerKey AND Configkey = 'ULVITF_PCF_WHEN_GEN_PICKSLIP' AND SVALUE = '1')    -- New Config Key
   BEGIN
      DECLARE
      @c_TableName        NVARCHAR(15),
      @c_OrderLineNumber  NVARCHAR(5),
      @c_TransmitLogKey   NVARCHAR(10)

      SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK)
       WHERE ExternOrderkey = @c_loadkey
         AND Zone = '9'

      SELECT @c_OrderKey = ''
      WHILE ( @n_continue = 1 or @n_continue = 2 )
      BEGIN
         SELECT @c_OrderKey = MIN(OrderKey)
           FROM ORDERS (NOLOCK)
          WHERE LoadKey = @c_loadkey
            AND UserDefine08 = 'N'
            AND OrderKey > @c_OrderKey

         IF ISNULL(@c_OrderKey,'') = ''
            BREAK

         SELECT @c_StorerKey  = ORDERS.StorerKey,
                @c_TableName  = CASE ORDERS.TYPE
                                   WHEN 'WT' THEN 'ULVNSO'
                                   WHEN 'W'  THEN 'ULVHOL'
                                   WHEN 'WC' THEN 'ULVINVTRF'
                                   WHEN 'WD' THEN 'ULVDAMWD'
                                   ELSE 'ULVPCF'
                                END
           FROM ORDERS (NOLOCK)
          WHERE ORDERS.OrderKey    = @c_OrderKey


         IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK)
                           WHERE Storerkey = @c_StorerKey AND Configkey = 'ULVITF' AND SVALUE = '1')
            AND EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK)
                           WHERE Storerkey = @c_StorerKey AND Configkey = 'ULVITF_PCF_WHEN_GEN_PICKSLIP' AND SVALUE = '1')    -- New Config Key
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK)
                                   WHERE StorerKey = @c_StorerKey AND Configkey = 'ULVPODITF' AND SValue = '1' )
            BEGIN
               SELECT @c_OrderLineNumber = ''
               WHILE ( @n_continue = 1 or @n_continue = 2 )
               BEGIN
                  SELECT @c_OrderLineNumber = MIN (Orderlinenumber)
                    FROM ORDERDETAIL (NOLOCK)
                   WHERE Orderkey = @c_OrderKey
                     AND ORDERLINENUMBER > @c_OrderLineNumber

                  IF ISNULL(@c_OrderLineNumber,'') = ''
                     BREAK

                  IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG2 (NOLOCK)
                                  WHERE TableName = @c_TableName
                                    AND key1 = @c_OrderKey
                                    AND Key2 = @c_OrderLineNumber )
                  BEGIN
                     SELECT @c_TransmitLogKey=''
                     SELECT @b_success=1

                     EXECUTE nspg_getkey
                     'TransmitLogKey2'
                     , 10
                     , @c_TransmitLogKey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     IF NOT @b_success=1
                     BEGIN
                        SELECT @n_continue=3
                     END

                     IF ( @n_continue = 1 or @n_continue = 2 )
                     BEGIN
                        INSERT TransmitLog2 (TransmitLogKey, Tablename, Key1, Key2, Key3, Transmitbatch)
                           VALUES (@c_TransmitLogKey, @c_TableName, @c_OrderKey, @c_OrderLineNumber, @c_Storerkey, @c_pickheaderkey )

                        SELECT @n_err= @@Error
                        IF NOT @n_err=0
                        BEGIN
                           SELECT @n_continue=3
                           Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=22806
                           Select @c_errmsg= "NSQL"+CONVERT(char(5), @n_err)+":Insert failed on TransmitLog2. (nsp_GetPickSlipWave)"+"("+"SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+")"
                        END
                     END
                  END
               END
            END
         END
      END
   END -- if ULVITF_PCF_WHEN_GEN_PICKSLIP Turn on
   -- End SOS20748

   SELECT #TEMP_PICK.*,
   LOADPLAN.Facility,
   LOADPLAN.Delivery_zone
   FROM #temp_pick, LOADPLAN(NOLOCK)
   WHERE #TEMP_PICK.Loadkey = LOADPLAN.Loadkey
   DROP Table #temp_pick
END


GO