SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetPickSlipOrders120                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: mingle(copy from nsp_GetPickSlipOrders)                  */
/*                                                                      */
/* Purpose: WMS-16737                                                   */
/*                                                                      */
/* Called By: r_dw_print_pickorder120                                   */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/


CREATE PROC [dbo].[isp_GetPickSlipOrders120] (@c_loadkey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @c_pickheaderkey NVARCHAR(10),
 		@n_continue		int,
 		@c_errmsg	 NVARCHAR(255),
 		@b_success		int,
 		@n_err		int,
 		@c_sku	 NVARCHAR(20),
 		@n_qty		int,
 		@c_loc	 NVARCHAR(10),
 		@n_cases		int,
 		@n_perpallet		int,
 		@c_storer	 NVARCHAR(15),
 		@c_orderkey	 NVARCHAR(10),
 		@c_ConsigneeKey     NVARCHAR(15),
 		@c_Company          NVARCHAR(45),
 		@c_Addr1            NVARCHAR(45),
 		@c_Addr2            NVARCHAR(45),
 		@c_Addr3            NVARCHAR(45),
 		@c_PostCode         NVARCHAR(15),
 		@c_Route            NVARCHAR(10),
 		@c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
 		@c_TrfRoom          NVARCHAR(10),  -- LoadPlan.TrfRoom
 		@c_Notes1           NVARCHAR(60),
 		@c_Notes2           NVARCHAR(60),
 		@c_SkuDesc          NVARCHAR(60),
 		@n_CaseCnt          int,
 		@n_PalletCnt        int,
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
 		@c_firsttime	       NVARCHAR(1),
 		@c_logicalloc       NVARCHAR(18),
 		@c_Lottable01       NVARCHAR(10),
 		@d_Lottable04       datetime,
 		@c_labelPrice       NVARCHAR(5),
 		@c_externorderkey   NVARCHAR(50),
      @c_userdefine09          NVARCHAR(10)
 	   	   		   
    DECLARE @c_PrevOrderKey     NVARCHAR(10),
            @n_Pallets          int,
            @n_Cartons          int,
            @n_Eaches           int,
            @n_UOMQty           int
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
 			TrfRoom          NVARCHAR(10),  -- LoadPlan.TrfRoom
 			Notes1           NVARCHAR(60),
 			Notes2           NVARCHAR(60),
 			LOC              NVARCHAR(10),
 			SKU              NVARCHAR(20),
 			SkuDesc          NVARCHAR(60),
 			Qty              int,
 			TempQty1	  int,
 			TempQty2	  int,
 			PrintedFlag      NVARCHAR(1),
 			Zone             NVARCHAR(1),
 			PgGroup          int,
 			RowNum           int,
 			Lot		  NVARCHAR(10),
 			Carrierkey       NVARCHAR(60),
 			VehicleNo        NVARCHAR(10),
 			Lottable01       NVARCHAR(10),
 			Lottable04       datetime, 
 			LabelPrice	  NVARCHAR(5),
 			ExternOrderKey   NVARCHAR(50),
         userdefine09          NVARCHAR(10)
         )  --tlting_ext
    SELECT @n_continue = 1	
    SELECT @n_RowNo = 0
    SELECT @c_firstorderkey = 'N'
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
    IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) 
              WHERE ExternOrderKey = @c_loadkey
              AND   Zone = "8")
    BEGIN
       SELECT @c_firsttime = 'N'
       SELECT @c_PrintedFlag = 'Y'
    END
    ELSE
    BEGIN
       SELECT @c_firsttime = 'Y'
       SELECT @c_PrintedFlag = "N"
    END -- Record Not Exists
    BEGIN TRAN
       -- Uses PickType as a Printed Flag
       UPDATE PickHeader
       SET PickType = '1',
           TrafficCop = NULL
       WHERE ExternOrderKey = @c_loadkey
       AND Zone = "8"
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
    DECLARE pick_cur CURSOR  FAST_FORWARD READ_ONLY FOR
       SELECT PickDetail.sku,       PickDetail.loc, 
              SUM(PickDetail.qty),  PACK.Qty,
              PickDetail.storerkey, PickDetail.OrderKey, 
              PickDetail.UOM,       LOC.LogicalLocation,
              Pickdetail.Lot
       FROM   PickDetail (NOLOCK),  LoadPlanDetail (NOLOCK), 
              PACK (NOLOCK),        LOC (NOLOCK)
       WHERE  PickDetail.OrderKey = LoadPlanDetail.OrderKey
       AND    PickDetail.Status < '5'
       AND    PickDetail.Packkey = PACK.Packkey
       AND    LOC.Loc = PICKDETAIL.Loc
       AND    LoadPlanDetail.LoadKey = @c_loadkey
       GROUP BY PickDetail.sku,       PickDetail.loc,      PACK.Qty,
                PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
 	       LOC.LogicalLocation,  Pickdetail.Lot
       ORDER BY PICKDETAIL.ORDERKEY
       OPEN pick_cur
       SELECT @c_PrevOrderKey = ""
       FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
 		      @c_orderkey,  @c_UOM, @c_logicalloc, @c_lot
       WHILE (@@FETCH_STATUS <> -1)
       BEGIN
 			 IF @c_OrderKey <> @c_PrevOrderKey
 			 BEGIN
            --tlting01
 				IF NOT EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND OrderKey = @c_OrderKey AND ZONE = '8')
 				BEGIN
 					EXECUTE nspg_GetKey
 					"PICKSLIP",
 					9,   
 					@c_pickheaderkey     OUTPUT,
 					@b_success   	 OUTPUT,
 					@n_err       	 OUTPUT,
 					@c_errmsg    	 OUTPUT
 					
 					SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
 					
 					BEGIN TRAN
 					INSERT INTO PICKHEADER
 					(PickHeaderKey,    OrderKey,    ExternOrderKey, PickType, Zone, TrafficCop)
 					VALUES
 					(@c_pickheaderkey, @c_OrderKey, @c_LoadKey,     "0",      "8",  "")
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
 					SELECT @c_firstorderkey = 'Y'	   
 				END
 				ELSE
 				BEGIN
 					SELECT @c_pickheaderkey = PickHeaderKey FROM PickHeader (NOLOCK) 
 					WHERE ExternOrderKey = @c_loadkey
 					AND   Zone = "8"
 					AND   OrderKey = @c_OrderKey
 				END
 			END
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
                    @c_Notes1 = "",
                    @c_Notes2 = "",
                    @c_userdefine09 = ""
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
                    @c_Notes2       = CONVERT(NVARCHAR(60), ORDERS.Notes2),
 		   @c_labelprice   = ISNULL( ORDERS.LabelPrice, 'N' ),
                    @c_externorderkey = ExternOrderKey,
                    @c_userdefine09 = ORDERS.userdefine09
             FROM   ORDERS (NOLOCK)  
             WHERE  ORDERS.OrderKey = @c_OrderKey
          END -- IF @c_OrderKey = ""
 	
      SELECT @c_TrfRoom   = IsNULL(LoadPlan.TrfRoom, ""),
                 @c_Route     = IsNULL(LoadPlan.Route, ""),
                 @c_VehicleNo = IsNULL(LoadPlan.TruckSize, ""),
 		@c_Carrierkey = IsNULL(LoadPlan.CarrierKey,"")
          FROM   LoadPlan (NOLOCK)
          WHERE  Loadkey = @c_LoadKey
          SELECT @c_Route_Desc  = IsNull(RouteMaster.Descr, "")
          FROM   RouteMaster (NOLOCK)
          WHERE  Route = @c_Route
          SELECT @c_SkuDesc = IsNULL(Descr,"")
          FROM   SKU  (NOLOCK)
          WHERE  SKU = @c_SKU
          SELECT @c_Lottable01 = Lottable01,
                 @d_Lottable04 = Lottable04
         FROM   LOTATTRIBUTE (NOLOCK)
          WHERE  LOT = @c_LOT
          IF @c_Lottable01    IS NULL SELECT @c_Lottable01 = ""
          IF @d_Lottable04    IS NULL SELECT @d_Lottable04 = "01/01/1900"         
          IF @c_Notes1        IS NULL SELECT @c_Notes1 = ""
          IF @c_Notes2        IS NULL SELECT @c_Notes2 = ""
          IF @c_ConsigneeKey  IS NULL SELECT @c_ConsigneeKey = ""
          IF @c_Company       IS NULL SELECT @c_Company = ""
          IF @c_Addr1         IS NULL SELECT @c_Addr1 = ""
          IF @c_Addr2         IS NULL SELECT @c_Addr2 = ""
          IF @c_Addr3         IS NULL SELECT @c_Addr3 = ""
          IF @c_PostCode      IS NULL SELECT @c_PostCode = ""
          IF @c_Route         IS NULL SELECT @c_Route = ""
          IF @c_CarrierKey    IS NULL SELECT @c_Carrierkey = ""
          IF @c_Route_Desc    IS NULL SELECT @c_Route_Desc = ""
 	 IF @c_superorderflag = "Y" SELECT @c_orderkey = ""
          SELECT @n_RowNo = @n_RowNo + 1
          SELECT @n_Pallets = 0,
                 @n_Cartons = 0,
                 @n_Eaches  = 0
          SELECT @n_UOMQty = 0
          SELECT @n_UOMQty = CASE @c_UOM
                                 WHEN "1" THEN PACK.Pallet
                                 WHEN "2" THEN PACK.CaseCnt
                                 WHEN "3" THEN PACK.InnerPack
                                 ELSE 1
                              END
          FROM   PACK (NOLOCK), SKU (NOLOCK)
          WHERE  SKU.SKU = @c_SKU
          AND    PACK.PackKey = SKU.PackKey
          INSERT INTO #Temp_Pick
               (PickSlipNo,          LoadKey,          OrderKey,         ConsigneeKey,
                Company,             Addr1,            Addr2,            PgGroup,
                Addr3,               PostCode,         Route,
                Route_Desc,          TrfRoom,          Notes1,           RowNum,
                Notes2,              LOC,              SKU,
                SkuDesc,             Qty,	      TempQty1,
                TempQty2,	    PrintedFlag,      Zone,
 	       Lot,		    CarrierKey,       VehicleNo,        Lottable01,
                Lottable04, LabelPrice, ExternOrderKey,userdefine09 )
          VALUES 
               (@c_pickheaderkey,   @c_LoadKey,       @c_OrderKey,     @c_ConsigneeKey,
                @c_Company,         @c_Addr1,         @c_Addr2,        0,    
                @c_Addr3,           @c_PostCode,      @c_Route,
                @c_Route_Desc,      @c_TrfRoom,       @c_Notes1,       @n_RowNo,
                @c_Notes2,          @c_LOC,           @c_SKU,
                @c_SKUDesc,         @n_Qty,	     CAST(@c_UOM as int),
                @n_UOMQty, 	   @c_PrintedFlag,   "8",
 	       @c_Lot,		   @c_Carrierkey,   @c_VehicleNo,     @c_Lottable01,
                @d_Lottable04, @c_labelprice, @c_externorderkey,@c_userdefine09  )
          SELECT @c_PrevOrderKey = @c_OrderKey
          FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
 		      @c_orderkey, @c_UOM, @c_logicalloc, @c_LOT
       END
       CLOSE pick_cur	
       DEALLOCATE pick_cur   
    SELECT * FROM #temp_pick
    DROP Table #temp_pick
 END


GO