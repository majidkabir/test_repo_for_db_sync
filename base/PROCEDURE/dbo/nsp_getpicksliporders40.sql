SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_GetPickSlipOrders40                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 213634 HERBALIFE Pickslip                                   */
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
/* Date         Author    Ver.  Purposes                                */
/* 2014-Mar-21  TLTING        SQL20112 Bug                              */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders40] (@c_loadkey NVARCHAR(10)) 
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @c_pickheaderkey  NVARCHAR(10),
      @n_continue         		int,
      @c_errmsg           	 NVARCHAR(255),
      @b_success          		int,
      @n_err              		int,
      @n_pickslips_required	int

    CREATE TABLE #TEMP_PICK
       ( PickSlipNo       NVARCHAR(10) NULL,
         LoadKey          NVARCHAR(10),
         OrderKey         NVARCHAR(10),
         ConsigneeKey     NVARCHAR(15),
         Company          NVARCHAR(45),
         Addr1            NVARCHAR(45) NULL,
         Addr2            NVARCHAR(45) NULL,
         Addr3            NVARCHAR(45) NULL,
         PostCode         NVARCHAR(15) NULL,
         Route            NVARCHAR(10) NULL,
         Route_Desc       NVARCHAR(60) NULL, -- RouteMaster.Desc
         TrfRoom          NVARCHAR(5)  NULL, -- LoadPlan.TrfRoom
         Notes1           NVARCHAR(60) NULL,
         Notes2           NVARCHAR(60) NULL,
         LOC              NVARCHAR(10) NULL,
         SKU              NVARCHAR(20),
         SkuDesc          NVARCHAR(60),
         Qty              int,
         TempQty1         int NULL,
         TempQty2         int,
         PrintedFlag      NVARCHAR(1) NULL,
         Zone             NVARCHAR(1),
         PgGroup          int,
         RowNum           int,
         Lot              NVARCHAR(10),
         Carrierkey       NVARCHAR(60) NULL,
         VehicleNo        NVARCHAR(10) NULL,
         Lottable02       NVARCHAR(18) NULL,
         Lottable04       datetime NULL,
         Lottable05       datetime NULL,
         packpallet       int,
         packcasecnt      int,
         externorderkey   NVARCHAR(50) NULL,   --tlting_ext
         LogicalLoc       NVARCHAR(18) NULL,  
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
         UOM              NVARCHAR(10) NULL,		-- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
			   DeliveryDate	    NVARCHAR(10) NULL,		-- Added by MaryVong on 29-Dec-2003 (FBR#18681)
         Lottable03       NVARCHAR(18) NULL,      -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
         Lottable01       NVARCHAR(18) NULL,
         ItemClass        NVARCHAR(10) NULL) 
                         
       INSERT INTO #TEMP_PICK
            (PickSlipNo,          LoadKey,          OrderKey,         ConsigneeKey,
             Company,             Addr1,            Addr2,            PgGroup,
             Addr3,               PostCode,         Route,
             Route_Desc,          TrfRoom,          Notes1,           RowNum,
             Notes2,              LOC,              SKU,
             SkuDesc,             Qty,              TempQty1,
             TempQty2,            PrintedFlag,      Zone,
             Lot,                 CarrierKey,       VehicleNo,        Lottable02,
             Lottable04,          Lottable05,       packpallet,       packcasecnt,      
             externorderkey,      LogicalLoc,       Areakey,			 DeliveryDate,
             Lottable03, 					Lottable01,				ItemClass) --NJOW01

        SELECT DISTINCT 
        (SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK) 
            WHERE ExternOrderKey = @c_LoadKey 
            AND OrderKey = Orders.OrderKey 
            AND ZONE = '3'), 
        @c_LoadKey as LoadKey,                 
        Orders.OrderKey,                            
         -- SOS82873 Change company info from MBOL level to LOAD level
         -- NOTE: In ECCO case,2 style, the English information saved in C_company, C_AddressÃ and Chinese Information saved in B_company,B_Address
        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.CONSIGNEEKEY , '')
        ELSE IsNull(ORDERS.BillToKey , '')  END  ) as ConsigneeKey ,
        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Company , '')
        ELSE IsNull(ORDERS.C_Company, '')  END  ) as Company  ,

        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Address1 , '')
        ELSE IsNull(ORDERS.C_Address1, '')  END  ) as Addr1  ,

        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Address2 , '')
        ELSE IsNull(ORDERS.C_Address2, '')  END  ) as Addr2  ,
        0 AS PgGroup,                                       
        (CASE WHEN StorerConfig.sValue = '1' THEN IsNull(ORDERS.B_Address3 , '')
        ELSE IsNull(ORDERS.C_Address3, '')  END  ) as Addr3,
        IsNull(ORDERS.C_Zip,'') AS PostCode,
        IsNull(ORDERS.Route,'') AS Route,         
        IsNull(RouteMaster.Descr, '') Route_Desc,       
        ORDERS.Door AS TrfRoom,
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')) Notes1,                                    
        0 AS RowNo, 
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')) Notes2,
        PickDetail.loc,   
        PickDetail.sku,                         
        IsNULL(Sku.Descr,'') SkuDescr,                  
        SUM(PickDetail.qty) as Qty,
        0 AS TEMPQTY1,
        TempQty2 = 
          CASE WHEN pack.pallet = 0 then 0
                ELSE CASE WHEN (Sum(pickdetail.qty) % CAST(pack.pallet AS INT)) > 0 THEN 0
        ELSE 1 END END , -- Vicky
        IsNull((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND  Zone = '3'), 'N') AS PrintedFlag, 
        '3' Zone,
        Pickdetail.Lot,                         
        '' CarrierKey,                                  
        '' AS VehicleNo,
        LotAttribute.Lottable02,                
        IsNull(LotAttribute.Lottable04, '19000101') Lottable04,        
        IsNull(LotAttribute.Lottable05, '19000101') Lottable05,        
        PACK.Pallet,
        PACK.CaseCnt, 
        ORDERS.ExternOrderKey AS ExternOrderKey,               
        IsNuLL(LOC.LogicalLocation, '') AS LogicalLocation, 
        IsNull(AreaDetail.AreaKey, '00') AS Areakey,     			-- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
		  IsNull (CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103), ''),	-- Added by MaryVong on 29-Dec-2003 (FBR#18681)
        LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)  
        LotAttribute.Lottable01, -- NJOW01
        CASE WHEN SKU.ItemClass = 'PTS' THEN 'PTS' ELSE 'N/A' END AS ItemClass
    FROM   LOADPLANDETAIL (NOLOCK) 
    JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LoadPlanDetail.Orderkey)
    JOIN Storer (NOLOCK) ON (ORDERS.StorerKey = Storer.StorerKey)
    JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)		-- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
    LEFT OUTER JOIN StorerConfig ON (ORDERS.StorerKey = StorerConfig.StorerKey AND StorerConfig.ConfigKey = 'UsedBillToAddressForPickSlip')
    LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = ORDERS.Route)
    JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey 
                    AND ORDERS.Orderkey = PICKDETAIL.Orderkey
                    AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)
    JOIN LotAttribute (NOLOCK) ON (PickDetail.Lot = LotAttribute.Lot)
    JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku AND SKU.Sku = OrderDetail.Sku)
    JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
    JOIN LOC with (NOLOCK, INDEX (PKLOC)) ON (LOC.LOC = PICKDETAIL.LOC)
    LEFT OUTER JOIN AreaDetail (NOLOCK) ON (LOC.PutawayZone = AreaDetail.PutawayZone)
   WHERE PickDetail.Status >= '0'  
       AND LoadPlanDetail.LoadKey = @c_LoadKey
     GROUP BY ORDERS.OrderKey,                            
        StorerConfig.sValue , 
        ORDERS.CONSIGNEEKEY,
        ORDERS.B_Company,
        ORDERS.B_Address1,
        ORDERS.B_Address2,
        ORDERS.B_Address3,
        ORDERS.BillToKey,
        ORDERS.C_Company,
        ORDERS.C_Address1,
        ORDERS.C_Address2,
        ORDERS.C_Address3,
        IsNull(ORDERS.C_Zip,''),
        IsNull(ORDERS.Route,''),
        IsNull(RouteMaster.Descr, ''),
        ORDERS.Door,
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes,  '')),                                    
        CONVERT(NVARCHAR(60), IsNull(ORDERS.Notes2, '')),
        PickDetail.loc,   
        PickDetail.sku,    
        IsNULL(Sku.Descr,''),                  
        Pickdetail.Lot,                         
        LotAttribute.Lottable02,                
        IsNUll(LotAttribute.Lottable04, '19000101'),        
        IsNUll(LotAttribute.Lottable05, '19000101'),  
        PACK.Pallet,
        PACK.CaseCnt,
        ORDERS.ExternOrderKey,
        IsNull(LOC.LogicalLocation, ''),  
        IsNull(AreaDetail.AreaKey, '00'),     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
		  IsNull(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103), ''),		-- Added by MaryVong on 29-Dec-2003 (FBR#18681)
        LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
        LotAttribute.Lottable01, --NJOW01
				CASE WHEN SKU.ItemClass = 'PTS' THEN 'PTS' ELSE 'N/A' END
     BEGIN TRAN  

     -- Uses PickType as a Printed Flag  
     UPDATE PickHeader SET PickType = '1', TrafficCop = NULL 
     WHERE ExternOrderKey = @c_LoadKey 
     AND Zone = '3' 

     SELECT @n_err = @@ERROR  
     IF @n_err <> 0   
     BEGIN  
         SELECT @n_continue = 3  
         IF @@TRANCOUNT >= 1  
         BEGIN  
             ROLLBACK TRAN  
         END  
     END  
     ELSE BEGIN  
         IF @@TRANCOUNT > 0   
         BEGIN  
             COMMIT TRAN  
         END  
         ELSE BEGIN  
             SELECT @n_continue = 3  
             ROLLBACK TRAN  
         END  
     END  

     SELECT @n_pickslips_required = Count(DISTINCT OrderKey) 
     FROM #TEMP_PICK
     WHERE PickSlipNo IS NULL
     IF @@ERROR <> 0
     BEGIN
         GOTO FAILURE
     END
     ELSE IF @n_pickslips_required > 0
     BEGIN
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
             SELECT 'P' + RIGHT ( REPLICATE ('0', 9) + 
             dbo.fnc_LTrim( dbo.fnc_RTrim( STR( CAST(@c_pickheaderkey AS int) + 
                              ( select count(distinct orderkey) 
                                from #TEMP_PICK as Rank 
                                WHERE Rank.OrderKey < #TEMP_PICK.OrderKey ) 
                    ) -- str
                    )) -- dbo.fnc_RTrim
                 , 9) 
              , OrderKey, LoadKey, '0', '3', ''
             FROM #TEMP_PICK WHERE PickSlipNo IS NULL
             GROUP By LoadKey, OrderKey

         UPDATE #TEMP_PICK 
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM PICKHEADER (NOLOCK)
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
         AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
         AND   PICKHEADER.Zone = '3'
         AND   #TEMP_PICK.PickSlipNo IS NULL
     END
     GOTO SUCCESS
 FAILURE:
     DELETE FROM #TEMP_PICK
 SUCCESS:
     SELECT * FROM #TEMP_PICK  
     DROP Table #TEMP_PICK  
 END

GO