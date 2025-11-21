SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: nsp_GetPickSlipCase                                   */  
/* Creation Date:                                                          */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:                                                                */                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date           Ver    Author   Purposes                                 */  
/* 20-MAY-2020    1.1    CSCHONG  Change to use # Temp table (CS01)        */
/***************************************************************************/    

CREATE PROC [dbo].[nsp_GetPickSlipCase] (@c_loadkey NVARCHAR(10)) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_pickheaderkey NVARCHAR(10),
      @n_continue    int,
      @c_errmsg    NVARCHAR(255),
      @b_success     int,
      @n_err      int,
      @c_sku    NVARCHAR(20),
      @n_qty      int,
      @c_loc    NVARCHAR(10),
      @n_cases     int,
      @n_pallets     int,
      @n_perpallet      int,
      @c_storer    NVARCHAR(15),
      @c_orderkey  NVARCHAR(10),
      @c_ConsigneeKey     NVARCHAR(15),
      @c_Company          NVARCHAR(45),
      @c_Addr1            NVARCHAR(45),
      @c_Addr2            NVARCHAR(45),
      @c_Addr3            NVARCHAR(45),
      @c_PostCode         NVARCHAR(15),
      @c_Route            NVARCHAR(10),
      @c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
      @c_TrfRoom          NVARCHAR(10), -- LoadPlan.TrfRoom  -- Modified by YokeBeen on 07-Oct-2002 (SOS# 7632)
      @c_Notes1           NVARCHAR(60),
      @c_Notes2           NVARCHAR(60),
      @c_SkuDesc          NVARCHAR(60),
      @n_CaseCnt          float,
      @c_ReceiptTm        NVARCHAR(20),
      @c_PrintedFlag      NVARCHAR(1),
      @c_UOM              NVARCHAR(10),
      @c_Lot              NVARCHAR(10),
      @c_StorerKey        NVARCHAR(15),
      @c_Zone             NVARCHAR(1),
      @n_PgGroup          int,
      @n_TotCases         int,
      @n_RowNo            int,
      @c_PrevSKU          NVARCHAR(20),
      @n_SKUCount         int,
      @c_PackKey          NVARCHAR(10),
      @c_Transporter      NVARCHAR(60),
      @c_VehicleNo        NVARCHAR(10),
      @c_firsttime          NVARCHAR(1),
      @c_superorderflag   NVARCHAR(1),
      @c_logicalloc       NVARCHAR(18), 
      @c_Pickdetailkey     NVARCHAR(18)   
                        
   CREATE TABLE #temp_pick
      (  PickSlipNo       NVARCHAR(10),
         LoadKey          NVARCHAR(10),
         OrderKey         NVARCHAR(10),
         ConsigneeKey     NVARCHAR(15),
         Company          NVARCHAR(45),
         Addr1            NVARCHAR(45),
         Addr2            NVARCHAR(45),
         Addr3            NVARCHAR(45),
         PostCode         NVARCHAR(15),
         Route            NVARCHAR(10),
         Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
         TrfRoom          NVARCHAR(10),  -- LoadPlan.TrfRoom  -- Modified by YokeBeen on 07-Oct-2002 (SOS# 7632)
         Notes1           NVARCHAR(60),
         Notes2           NVARCHAR(60),
         LOC              NVARCHAR(10),
         SKU              NVARCHAR(20),
         SkuDesc          NVARCHAR(60),
         CaseCnt          int,
         Qty              int,
         TotalQty     int,
         PrintedFlag      NVARCHAR(1),
         Zone             NVARCHAR(1),
         PgGroup          int,
         RowNum           int,
         Lot       NVARCHAR(10),
         Transporter      NVARCHAR(60),
         VehicleNo        NVARCHAR(10) )

   SELECT @n_continue = 1, @c_firsttime = "N"
   SELECT @n_RowNo = 0

   SELECT @c_superorderflag = SuperOrderFlag
   FROM LoadPlan (NOLOCK)
   WHERE LoadPlan.LoadKey = @c_loadkey

   IF @c_superorderflag IS NULL SELECT @c_superorderflag = 'N'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
             WHERE ExternOrderKey = @c_loadkey
             AND   Zone = "2")
   BEGIN
      SELECT @c_firsttime = "N"
      
      IF EXISTS (SELECT 1 FROM PickHeader (NOLOCK)
       WHERE ExternOrderKey = @c_loadkey
       AND Zone = "2"
       AND PickType = "0")
      BEGIN
         SELECT @c_PrintedFlag = "N"
      END 
      ELSE
      BEGIN
        SELECT @c_PrintedFlag = "N"
      END
   
      BEGIN TRAN

      -- Uses PickType as a Printed Flag
      UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
      WHERE ExternOrderKey = @c_loadkey
      AND PickType = '0'
      AND Zone = '2'

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
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = "Y"
      SELECT @c_PrintedFlag = "N"
   END -- Record Not Exists

   IF @c_firsttime = "Y"
   BEGIN
      IF @c_superorderflag <> 'Y'
      BEGIN
         DECLARE pick_cur CURSOR  FAST_FORWARD READ_ONLY FOR
         SELECT Pickdetail.Pickdetailkey, PickDetail.sku, PickDetail.loc, SUM(PickDetail.qty), PACK.PackUOM3, 
         PickDetail.storerkey, PickDetail.OrderKey, PACK.CaseCnt, PACK.PACKKEY,
         LOC.Logicallocation
         FROM   PickDetail (NOLOCK), LoadPlanDetail (NOLOCK), SKUxLOC (NOLOCK), PACK (NOLOCK),
         LOC (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
         AND    PickDetail.Status < '5'
         AND    PickDetail.Packkey = PACK.Packkey
 --        AND    PACK.PackUom3 = 'CS'
         AND    ( PickDetail.Uom = '6' OR PickDetail.Uom = '3')
         AND    SKUxLOC.SKU = PICKDETAIL.SKU
         AND    SKUxLOC.Loc = PICKDETAIL.Loc
         AND    LOC.Loc = SKUxLOC.Loc
         AND    SKUxLOC.LocationType IN ("PICK", "CASE")
         AND    LoadPlanDetail.LoadKey = @c_loadkey
         GROUP BY Pickdetail.Pickdetailkey, PickDetail.sku, PickDetail.loc, PACK.PackUOM3,
                  PickDetail.storerkey, PickDetail.OrderKey, PACK.CaseCnt, PACK.PACKKEY,
                  LOC.Logicallocation
         UNION
         SELECT Pickdetail.Pickdetailkey,PickDetail.sku, PickDetail.loc, SUM(PickDetail.qty), PACK.PackUOM3, 
         PickDetail.storerkey, PickDetail.OrderKey, PACK.CaseCnt, PACK.PACKKEY,
         LOC.Logicallocation
         FROM   PickDetail (NOLOCK), LoadPlanDetail (NOLOCK), SKUxLOC (NOLOCK), PACK (NOLOCK),
         LOC (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
         AND    PickDetail.Status < '5'
         AND    PickDetail.Packkey = PACK.Packkey
--         AND    PACK.PackUom3 = 'EA'
         AND    ( PickDetail.Uom = '2' OR PickDetail.Uom = '3')
         AND    SKUxLOC.SKU = PICKDETAIL.SKU
         AND    SKUxLOC.Loc = PICKDETAIL.Loc
         AND    LOC.Loc = SKUxLOC.Loc
         AND    SKUxLOC.LocationType IN ("PICK", "CASE")
         AND    LoadPlanDetail.LoadKey = @c_loadkey
         GROUP BY Pickdetail.Pickdetailkey,PickDetail.sku, PickDetail.loc, PACK.PackUOM3,
                  PickDetail.storerkey, PickDetail.OrderKey, PACK.CaseCnt, PACK.PACKKEY,
        LOC.Logicallocation
        ORDER BY LOC.LogicalLocation, PICKDETAIL.Loc
      END
      ELSE
      BEGIN
    DECLARE pick_cur CURSOR  FAST_FORWARD READ_ONLY FOR
         SELECT Pickdetail.Pickdetailkey,PickDetail.sku, PickDetail.loc, SUM(PickDetail.qty), PACK.PackUOM3, 
         PickDetail.storerkey, '', PACK.CaseCnt, PACK.PACKKEY,
         LOC.Logicallocation
         FROM   PickDetail (NOLOCK), LoadPlanDetail (NOLOCK), SKUxLOC (NOLOCK), PACK (NOLOCK),
         LOC (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
         AND    PickDetail.Status < '5'
         AND    PickDetail.Packkey = PACK.Packkey
         AND    PACK.PackUom3 = 'CS'
         AND    PickDetail.Uom = '6'
         AND    SKUxLOC.SKU = PICKDETAIL.SKU
         AND    SKUxLOC.Loc = PICKDETAIL.Loc
         AND    LOC.Loc = SKUxLOC.Loc
         AND    SKUxLOC.LocationType IN ("PICK", "CASE")
         AND    LoadPlanDetail.LoadKey = @c_loadkey
         GROUP BY Pickdetail.Pickdetailkey,PickDetail.sku, PickDetail.loc, PACK.PackUOM3,
                  PickDetail.storerkey, PACK.CaseCnt, PACK.PACKKEY,
                  LOC.Logicallocation
    UNION
         SELECT Pickdetail.Pickdetailkey,PickDetail.sku, PickDetail.loc, SUM(PickDetail.qty), PACK.PackUOM3, 
         PickDetail.storerkey, '', PACK.CaseCnt, PACK.PACKKEY,
         LOC.Logicallocation
         FROM   PickDetail (NOLOCK), LoadPlanDetail (NOLOCK), SKUxLOC (NOLOCK), PACK (NOLOCK),
         LOC (NOLOCK)
         WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
         AND    PickDetail.Status < '5'
         AND    PickDetail.Packkey = PACK.Packkey
         AND    PACK.PackUom3 = 'EA'
         AND    ( PickDetail.Uom = '2' OR PickDetail.Uom = '3')
         AND    SKUxLOC.SKU = PICKDETAIL.SKU
         AND    SKUxLOC.Loc = PICKDETAIL.Loc
         AND    LOC.Loc = SKUxLOC.Loc
         AND    SKUxLOC.LocationType IN ("PICK", "CASE")

         AND    LoadPlanDetail.LoadKey = @c_loadkey
         GROUP BY Pickdetail.Pickdetailkey,PickDetail.sku, PickDetail.loc, PACK.PackUOM3,
                  PickDetail.storerkey, PACK.CaseCnt, PACK.PACKKEY,
                  LOC.Logicallocation

         ORDER BY LOC.LogicalLocation, PICKDETAIL.Loc
      END   

      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_Pickdetailkey, @c_sku, @c_loc, @n_Qty, @c_uom, @c_storerkey,
            @c_orderkey, @n_CaseCnt, @c_PackKey, @c_logicalloc

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         IF @c_OrderKey = ""
         BEGIN
            SELECT @c_ConsigneeKey = "",
                   @c_Company = "",
                   @c_Addr1 = "",
                   @c_Addr2 = "",
                   @c_Addr3 = "",
                   @c_PostCode = "",
                   @c_Route = "",
                   @c_Route_Desc = "",
                   @c_TrfRoom = "",
                   @c_Notes1 = "",
                   @c_Notes2 = ""
         END
         ELSE
         BEGIN
            SELECT @c_ConsigneeKey = Orders.BillToKey,
                   @c_Company      = ORDERS.c_Company,
                   @c_Addr1        = ORDERS.C_Address1,
                   @c_Addr2        = ORDERS.C_Address2,
                   @c_Addr3        = ORDERS.C_Address3,
                   @c_PostCode     = ORDERS.C_Zip,
                   @c_Notes1       = CONVERT(NVARCHAR(60), ORDERS.Notes),
                   @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2)
            FROM   ORDERS (NOLOCK)
            WHERE  ORDERS.OrderKey = @c_OrderKey
            
         END -- IF @c_OrderKey = ""

         SELECT @c_TrfRoom = LoadPlan.TrfRoom,
                @c_Route     = LoadPlan.Route
         FROM   LoadPlan (NOLOCK)
         WHERE  Loadkey = @c_LoadKey

         SELECT @c_VehicleNo = ids_lp_vehicle.vehiclenumber
         FROM ids_lp_vehicle (NOLOCK)
         WHERE ids_lp_vehicle.loadkey = @c_loadkey
         AND ids_lp_vehicle.linenumber = '00001'

         SELECT @c_Route_Desc = RouteMaster.Descr,
                @c_Transporter = RouteMaster.CarrierDesc
         FROM   RouteMaster (NOLOCK)
         WHERE  Route = @c_Route

         SELECT @c_SkuDesc = Descr
         FROM   SKU  (NOLOCK)
         WHERE  SKU = @c_SKU

        SELECT @c_Lot = Lot
        FROM Pickdetail
        WHERE Pickdetailkey = @c_Pickdetailkey


         IF @c_Transporter   IS NULL SELECT @c_Transporter = ""
         IF @c_VehicleNo     IS NULL SELECT @c_VehicleNo = ""
         IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ""
         IF @c_SkuDesc       IS NULL SELECT @c_SkuDesc = ""
         IF @c_Notes1        IS NULL SELECT @c_Notes1 = ""
         IF @c_Notes2        IS NULL SELECT @c_Notes2 = ""
         IF @c_TrfRoom       IS NULL SELECT @c_TrfRoom = ""
         IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ""
         IF @c_Company       IS NULL SELECT @c_Company = ""
         IF @c_Addr1         IS NULL SELECT @c_Addr1 = ""
         IF @c_Addr2         IS NULL SELECT @c_Addr2 = ""
         IF @c_Addr3         IS NULL SELECT @c_Addr3 = ""
         IF @c_PostCode      IS NULL SELECT @c_PostCode = ""
         IF @c_Route         IS NULL SELECT @c_Route = ""
 
         SELECT @n_RowNo = @n_RowNo + 1
         INSERT INTO #Temp_Pick
             (PickSlipNo,          LoadKey,          OrderKey,         ConsigneeKey,
              Company,             Addr1,            Addr2,            PgGroup,
              Addr3,               PostCode,         Route,
              Route_Desc,          TrfRoom,          Notes1,           RowNum,
              Notes2,              LOC,              SKU,
              SkuDesc,             CaseCnt,          Qty,          TotalQty,

              PrintedFlag,      Zone,             Lot,
              Transporter,         VehicleNo)
         VALUES 
             ("",         @c_LoadKey,       @c_OrderKey,     @c_ConsigneeKey,
              @c_Company,         @c_Addr1,         @c_Addr2,        0,    
              @c_Addr3,           @c_PostCode,      @c_Route,
              @c_Route_Desc,      @c_TrfRoom,       @c_Notes1,       @n_RowNo,
              @c_Notes2,          @c_LOC,           @c_SKU,
              @c_SKUDesc,         @n_CaseCnt,       @n_Qty,      @n_Qty,
              @c_PrintedFlag,   "2",           @c_Lot,   
              @c_Transporter,     @c_VehicleNo)

         FETCH NEXT FROM pick_cur INTO @c_Pickdetailkey, @c_sku, @c_loc, @n_Qty, @c_uom, @c_storerkey,
                                       @c_orderkey, @n_CaseCnt, @c_PackKey, @c_logicalloc
      END
      CLOSE pick_cur 
      DEALLOCATE pick_cur   
   
   -- Create 2nd Temp Table to store splitted line
      SELECT * INTO #Temp_Pick2
      FROM #Temp_Pick
      WHERE 1=2

      DECLARE @n_SplitQty int,
         @c_TempOrderKey NVARCHAR(10)

      SELECT @n_PgGroup = 0
      SELECT @n_TotCases = 0
      SELECT @c_TempOrderKey = ""
      SELECT @c_PrevSKU = ""
      SELECT @n_SKUCount = 0
      SELECT @n_splitqty = 0
   
      IF @c_superorderflag = 'Y'
      BEGIN
         DECLARE PickCursor CURSOR  FAST_FORWARD READ_ONLY FOR 
         SELECT  SKU, SUM(Qty), 'A', #Temp_Pick.Loc, LOC.Logicallocation
         FROM    #Temp_Pick, LOC (NOLOCK)
         WHERE #Temp_Pick.Loc = LOC.Loc
         GROUP BY Sku, #Temp_Pick.Loc, LOC.Logicallocation
         ORDER BY LOC.Logicallocation, #Temp_Pick.Loc
      END
      ELSE
      BEGIN
         DECLARE PickCursor CURSOR  FAST_FORWARD READ_ONLY FOR 
         SELECT  SKU, SUM(Qty), OrderKey, #Temp_Pick.Loc, LOC.Logicallocation
         FROM    #Temp_Pick, LOC (NOLOCK)
         WHERE #Temp_Pick.Loc = LOC.Loc
         GROUP BY OrderKey, Sku, #Temp_Pick.Loc, LOC.Logicallocation
         ORDER BY OrderKey, LOC.Logicallocation, #Temp_Pick.Loc
      END

      OPEN PickCursor

      FETCH NEXT FROM PickCursor INTO @c_SKU, @n_Qty, @c_OrderKey, @c_loc, @c_logicalloc
   
      WHILE @@FETCH_STATUS <> -1 
      BEGIN
    IF @c_PrevSKU <> @c_SKU SELECT @n_SKUCount = @n_SKUCount + 1

         IF @c_TempOrderKey <> @c_OrderKey
         BEGIN
            EXECUTE nspg_GetKey
             "PICKSLIP",
             9,   
               @c_pickheaderkey     OUTPUT,
               @b_success      OUTPUT,
               @n_err          OUTPUT,
               @c_errmsg       OUTPUT

                SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey  

          BEGIN TRAN
 
            INSERT INTO PICKHEADER
          (PickHeaderKey,    OrderKey,    ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES
               (@c_pickheaderkey, @c_OrderKey, @c_LoadKey,     "0",      "2",  "")

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
       END
         SELECT @n_PgGroup = @n_PgGroup + 1
         SELECT @n_SKUCount = 0
         SELECT @n_splitqty = 0
      END  -- Temp Order Key <> Order Key
      ELSE
      BEGIN
       IF @n_SKUCount = 5
       BEGIN
               EXECUTE nspg_GetKey
                     "PICKSLIP",
                     9,   
                     @c_pickheaderkey     OUTPUT,
                     @b_success      OUTPUT,
                     @n_err         OUTPUT,
                     @c_errmsg      OUTPUT

             SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

             BEGIN TRAN

               INSERT INTO PICKHEADER
            (PickHeaderKey,    OrderKey,    ExternOrderKey, PickType, Zone, TrafficCop)
               VALUES
               (@c_pickheaderkey, @c_OrderKey, @c_LoadKey,     "0",      "2",  "")

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
                  END

          SELECT @n_PgGroup = @n_PgGroup + 1
          SELECT @n_splitqty = 0
          SELECT @n_SKUCount = 0 
       END  -- More Than 5 SKU
       ELSE
       BEGIN
          IF @n_splitqty >= 50 
          BEGIN
             EXECUTE nspg_GetKey
                     "PICKSLIP",
                     9,   
                     @c_pickheaderkey     OUTPUT,
                     @b_success      OUTPUT,
                     @n_err         OUTPUT,
                     @c_errmsg      OUTPUT

                      SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey

                BEGIN TRAN

                  INSERT INTO PICKHEADER
                 (PickHeaderKey,    OrderKey,    ExternOrderKey, PickType, Zone, TrafficCop)
                  VALUES
                        (@c_pickheaderkey, @c_OrderKey, @c_LoadKey,     "0",      "2",  "")

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
                      END
                SELECT @n_PgGroup = @n_PgGroup + 1
                SELECT @n_SKUCount = 0
                SELECT @n_splitqty = 0
          END   -- More Than 50 Cases     
       END  -- Less Than 5 SKU And To Check For Cases > 50
     END  -- Temp Order Key = Order Key

    IF @c_superorderflag = 'Y'
    BEGIN
            UPDATE #temp_pick
            SET PickSlipNo = @c_pickheaderKey,
                PgGroup = @n_PgGroup
            WHERE Sku = @c_sku
    END 
    ELSE
    BEGIN
       UPDATE #temp_pick
       SET PickSlipNo = @c_pickheaderKey,
           PgGroup = @n_PgGroup
       WHERE OrderKey = @c_orderkey
       AND Sku = @c_sku
    END

         BEGIN TRAN

         IF @c_superorderflag = 'Y'
         BEGIN
            UPDATE PickDetail
            SET PickSlipNo = @c_pickheaderkey,
            Trafficcop = NULL
            FROM PickDetail, SKUxLOC (NOLOCK), PACK (NOLOCK), LOADPLANDETAIL (NOLOCK)
            WHERE PickDetail.OrderKey = LoadPlanDetail.OrderKey
            AND LoadPlanDetail.LoadKey = @c_loadkey
            AND PickDetail.SKU = @c_sku
            AND SKUxLOC.SKU = PickDetail.SKU
            AND SKUxLOC.Loc = PickDetail.Loc
            AND SKUxLOC.LocationType IN ("PICK", "CASE")
            AND PickDetail.Loc = @c_loc
            AND PickDetail.Packkey = PACK.Packkey
            AND PACK.PackUom1 <> 'EA'
            AND PickDetail.PickSlipNo IS NULL
    END
    ELSE
    BEGIN
       UPDATE PickDetail
            SET PickSlipNo = @c_pickheaderkey,
            Trafficcop = NULL
            FROM PickDetail, SKUxLOC (NOLOCK), PACK (NOLOCK)
            WHERE PickDetail.SKU = @c_sku
            AND SKUxLOC.SKU = PickDetail.SKU
            AND SKUxLOC.Loc = PickDetail.Loc
            AND SKUxLOC.LocationType IN ("PICK", "CASE")
            AND PickDetail.Loc = @c_loc
            AND PickDetail.Packkey = PACK.Packkey
            AND PACK.PackUom1 <> 'EA'
            AND PickDetail.OrderKey = @c_orderkey
            AND PickDetail.PickSlipNo IS NULL
    END
 
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
         END

         SELECT @c_PrevSKU = @c_SKU

         SELECT @c_TempOrderKey = @c_OrderKey
         SELECT @n_splitqty = @n_splitqty + @n_qty
       
      FETCH NEXT FROM PickCursor INTO @c_SKU, @n_Qty, @c_OrderKey, @c_loc, @c_logicalloc
      END
      CLOSE PickCursor
      DEALLOCATE PickCursor
      
      --CS01 disable insert  
      --INSERT INTO TempPickSlip
      --SELECT *, '2' FROM #temp_pick

      --BY CSCHONG 08-MAY-2020 Add traceinfo to track the record insert to TempPickSlip table 

      DECLARE @d_CurrentDate DATETIME 
      
      SET @d_CurrentDate = GETDATE()
      
     EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'TempPickSlip',
      @c_TraceName = 'nsp_GetPickSlipCase',
      @c_starttime = @d_CurrentDate,
      @c_endtime = @d_CurrentDate,
      @c_step1 = '',
      @c_step2 = '',
      @c_step3 = '',
      @c_step4 = '',
      @c_step5 = '',
      @c_col1 = @c_loadkey, 
      @c_col2 = '2',
      @c_col3 = '',
      @c_col4 = '',
      @c_col5 = '',
      @b_Success = 1,
      @n_Err = 0,
      @c_ErrMsg = '' 
  
   END
   ELSE
   BEGIN

      INSERT INTO #temp_pick
      SELECT PickSlipNo,
        LoadKey,
        OrderKey,
        ConsigneeKey,
        Company,
        Add1,
        Add2,
        Add3,
        PostCode,
        Route,
        RouteDesc,
        TrfRoom,
        Notes1,
        Notes2,
        Loc,
        SKU,
        SKUDesc,
        CaseCnt,
        TotalPallets,
        TotalCases,
        PrintedFlag,
        Zone,
        PgGroup,
        RowNum,
        Lot,
        Transporter,
        Vehicle
      FROM TempPickSlip
      WHERE PickSlipType = '2'
      AND LoadKey = @c_loadkey
   END 

   SELECT #temp_pick.*, PACK.Pallet, Pack.Packkey, Pack.Packuom1, Orders.Deliverydate, Lotattribute.Lottable02, Lotattribute.Lottable04, Areadetail.AreaKey
   FROM #temp_pick, SKU (NOLOCK), PACK (NOLOCK), LOADPLANDETAIL (NOLOCK), ORDERDETAIL (NOLOCK), ORDERS (NOLOCK), LOTATTRIBUTE (NOLOCK), LOC(NOLOCK), AREADETAIL(NOLOCK)
   WHERE SKU.Sku = #temp_pick.sku
   AND #temp_pick.Lot = LOTATTRIBUTE.Lot
   AND #temp_pick.Loc = Loc.Loc
   AND Loc.Putawayzone = Areadetail.Putawayzone
   AND SKU.PackKey = PACK.Packkey
   AND #temp_pick.Loadkey = LOADPLANDETAIL.Loadkey
   AND LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
   AND LOADPLANDETAIL.Orderkey = ORDERDETAIL.Orderkey
   AND ORDERDETAIL.Storerkey = SKU.Storerkey
   
   ORDER BY PgGroup, RowNum


END


GO