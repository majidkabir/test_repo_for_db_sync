SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders106                            */
/* Creation Date: 16-Jan-2020                                           */
/* Copyright:                                                           */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-11755 [CN] RBBT_pick slip_Enhancement_CR                */
/*           copy from nsp_GetPickSlipOrders37                          */
/*                                                                      */
/* Called By:r_dw_print_pickorder106                                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders106] (@c_loadkey NVARCHAR(10))
 AS
 BEGIN
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_pickheaderkey      NVARCHAR(10),
           @n_continue           INT,
           @c_errmsg             NVARCHAR(255),
           @b_success            INT,
           @n_err                INT,
           @n_pickslips_required INT,
           @n_starttcnt          INT, 
           @c_orderkey           NVARCHAR(10) 

   SELECT @n_starttcnt = @@TRANCOUNT   

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TEMP_PICK106
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
         Qty              INT,
         TempQty1         INT NULL,
         TempQty2         INT,
         PrintedFlag      NVARCHAR(1) NULL,
         Zone             NVARCHAR(1),
         PgGroup          INT,
         RowNum           INT,
         Lot              NVARCHAR(10),
         Carrierkey       NVARCHAR(60) NULL,
         VehicleNo        NVARCHAR(10) NULL,
         Lottable02       NVARCHAR(18) NULL,
         Lottable04       DATETIME NULL,
         Lottable05       DATETIME NULL,
         packpallet       INT,
         packcasecnt      INT,
         externorderkey   NVARCHAR(50) NULL,   
         LogicalLoc       NVARCHAR(18) NULL,
         Areakey          NVARCHAR(10) NULL,    
         UOM              NVARCHAR(10) NULL,  
         DeliveryDate     NVARCHAR(10) NULL, 
         Lottable03       NVARCHAR(18) NULL,     
         Lottable01       NVARCHAR(18) NULL,  
         ID               NVARCHAR(18) NULL,  
         ShowField        NVARCHAR(1) NULL ) 

   INSERT INTO #TEMP_PICK106
         (PickSlipNo,          LoadKey,          OrderKey,         ConsigneeKey,
          Company,             Addr1,            Addr2,            PgGroup,
          Addr3,               PostCode,         Route,
          Route_Desc,          TrfRoom,          Notes1,           RowNum,
          Notes2,              LOC,              SKU,
          SkuDesc,             Qty,              TempQty1,
          TempQty2,            PrintedFlag,      Zone,
          Lot,                 CarrierKey,       VehicleNo,        Lottable02,
          Lottable04,          Lottable05,       packpallet,       packcasecnt,
          externorderkey,      LogicalLoc,       Areakey,    DeliveryDate,
          Lottable03,          Lottable01,       ID,ShowField) 

   SELECT DISTINCT
         (SELECT PickHeaderKey FROM PICKHEADER (NOLOCK)
          WHERE ExternOrderKey = @c_LoadKey
          AND OrderKey = Orders.OrderKey
          AND ZONE = '3'),
         @c_LoadKey as LoadKey,
         Orders.OrderKey,
         -- SOS82873 Change company info from MBOL level to LOAD level
         -- NOTE: In ECCO case,2 style, the English information saved in C_company, C_Addressaand Chinese Information saved in B_company,B_Address
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.CONSIGNEEKEY , '')
         ELSE ISNULL(ORDERS.BillToKey , '')  END  ) as ConsigneeKey ,
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Company , '')
         ELSE ISNULL(ORDERS.C_Company, '')  END  ) as Company  ,

         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Address1 , '')
         ELSE ISNULL(ORDERS.C_Address1, '')  END  ) as Addr1  ,

         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Address2 , '')
         ELSE ISNULL(ORDERS.C_Address2, '')  END  ) as Addr2  ,
         0 AS PgGroup,
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Address3 , '')
         ELSE ISNULL(ORDERS.C_Address3, '')  END  ) as Addr3,
         ISNULL(ORDERS.C_Zip,'') AS PostCode,
         ISNULL(ORDERS.Route,'') AS Route,
         ISNULL(RouteMaster.Descr, '') Route_Desc,
         ORDERS.Door AS TrfRoom,
         CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')) Notes1,
         0 AS RowNo,
         CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) Notes2,
         UPPER(PickDetail.loc),  
         UPPER(PickDetail.sku),  
         ISNULL(Sku.Descr,'') SkuDescr,
         SUM(PickDetail.qty) as Qty,
         0 AS TEMPQTY1,
         TempQty2 =
             CASE WHEN (CASE SC.SValue WHEN Pack.PackUOM5   
                               THEN Pack.[Cube]
                          WHEN Pack.PackUOM6
                               THEN Pack.GrossWgt
                          WHEN Pack.PackUOM7
                               THEN Pack.NetWgt
                          WHEN Pack.PackUOM8
                               THEN Pack.OtherUnit1
                          WHEN Pack.PackUOM9
                               THEN Pack.OtherUnit2
                          ELSE PACK.Pallet END) = 0 THEN 0
             ELSE CASE WHEN (Sum(pickdetail.qty) % CAST((CASE SC.SValue WHEN Pack.PackUOM5  
                                                                      THEN Pack.[Cube]
                                                                 WHEN Pack.PackUOM6
                                                                      THEN Pack.GrossWgt
                                                                 WHEN Pack.PackUOM7
                                                                      THEN Pack.NetWgt
                                                                 WHEN Pack.PackUOM8
                                                                      THEN Pack.OtherUnit1
                                                                 WHEN Pack.PackUOM9
                                                                      THEN Pack.OtherUnit2
                                                                 ELSE PACK.Pallet END) AS INT)) > 0 THEN 0
                  ELSE 1 END
             END,  
         ISNULL((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = '3'), 'N') AS PrintedFlag,
         '3' Zone,
         Pickdetail.Lot,
         '' CarrierKey,
         '' AS VehicleNo,
         UPPER(LotAttribute.Lottable02),  
         ISNULL(LotAttribute.Lottable04, '19000101') Lottable04,
         ISNULL(LotAttribute.Lottable05, '19000101') Lottable05,
         CASE SC.SValue WHEN Pack.PackUOM5
              THEN Pack.[Cube]
         WHEN Pack.PackUOM6
              THEN Pack.GrossWgt
         WHEN Pack.PackUOM7
              THEN Pack.NetWgt
         WHEN Pack.PackUOM8
              THEN Pack.OtherUnit1
         WHEN Pack.PackUOM9
              THEN Pack.OtherUnit2
         ELSE PACK.Pallet END AS Pallet,  
         PACK.CaseCnt,
         ORDERS.ExternOrderKey AS ExternOrderKey,
         UPPER(ISNULL(LOC.LogicalLocation, '')) AS LogicalLocation,  
         UPPER(ISNULL(AreaDetail.AreaKey, '00')) AS Areakey,    
         ISNULL (CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 23), ''), 
         LotAttribute.Lottable03, 
         LotAttribute.Lottable01,  
         UPPER(PickDetail.ID)    
         ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowField      
   FROM LoadPlanDetail (NOLOCK)
   JOIN Orders (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
   JOIN Storer (NOLOCK) ON (ORDERS.StorerKey = Storer.StorerKey)
   JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)  
   LEFT OUTER JOIN StorerConfig ON (ORDERS.StorerKey = StorerConfig.StorerKey AND StorerConfig.ConfigKey = 'UsedBillToAddressForPickSlip')
   LEFT OUTER JOIN RouteMaster ON (RouteMaster.Route = ORDERS.Route)
   JOIN PickDetail (NOLOCK) ON (PickDetail.OrderKey = LoadPlanDetail.OrderKey
                   AND ORDERS.OrderKey = PICKDETAIL.OrderKey
                   AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)
   JOIN LotAttribute (NOLOCK) ON (PickDetail.Lot = LotAttribute.Lot)
   JOIN Sku (NOLOCK)  ON (Sku.StorerKey = PickDetail.StorerKey AND Sku.Sku = PickDetail.Sku AND SKU.Sku = OrderDetail.Sku)
   JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   JOIN LOC WITH (NOLOCK, INDEX (PKLOC)) ON (LOC.LOC = PICKDETAIL.LOC)
   LEFT OUTER JOIN AreaDetail (NOLOCK) ON (LOC.PutawayZone = AreaDetail.PutawayZone)
   LEFT OUTER JOIN StorerConfig SC (NOLOCK) ON (Sku.StorerKey = SC.StorerKey
                                            AND LOC.Facility = SC.Facility
                                            AND SC.ConfigKey = 'DefaultPalletUOM')  
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                          
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder37' AND ISNULL(CLR.Short,'') <> 'N')                                            
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
       ISNULL(ORDERS.C_Zip,''),
       ISNULL(ORDERS.Route,''),
       ISNULL(RouteMaster.Descr, ''),
       ORDERS.Door,
       CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes,  '')),
       CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),
       PickDetail.loc,
       UPPER(PickDetail.sku),  
       ISNULL(Sku.Descr,''),
       Pickdetail.Lot,
       UPPER(LotAttribute.Lottable02),  
       ISNULL(LotAttribute.Lottable04, '19000101'),
       ISNULL(LotAttribute.Lottable05, '19000101'),
       CASE SC.SValue WHEN Pack.PackUOM5
            THEN Pack.[Cube]
       WHEN Pack.PackUOM6
            THEN Pack.GrossWgt
       WHEN Pack.PackUOM7
            THEN Pack.NetWgt
       WHEN Pack.PackUOM8
            THEN Pack.OtherUnit1
       WHEN Pack.PackUOM9
            THEN Pack.OtherUnit2
       ELSE PACK.Pallet END,
       PACK.CaseCnt,
       ORDERS.ExternOrderKey,
       UPPER(ISNULL(LOC.LogicalLocation, '')),   
       ISNULL(AreaDetail.AreaKey, '00'),     
       ISNULL(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 23), ''),  
       LotAttribute.Lottable03, 
       LotAttribute.Lottable01,  
       UPPER(PickDetail.ID),     
       CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END    

      BEGIN TRAN
      -- Uses PickType as a Printed Flag
      UPDATE PickHeader SET PickType = '1', TrafficCop = NULL
      WHERE ExternOrderKey = @c_LoadKey
      AND Zone = '3'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         IF @@TRANCOUNT > 0
         BEGIN
            ROLLBACK TRAN
         END
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN 
            COMMIT TRAN
         END
      END

      SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
      FROM #TEMP_PICK106
      WHERE PickSlipNo IS NULL

      IF @@ERROR <> 0
      BEGIN
         GOTO FAILURE
      END
      ELSE IF @n_pickslips_required > 0
      BEGIN
         
         DECLARE Cur_Pickslipno CURSOR LOCAL READ_ONLY FAST_FORWARD FOR          
            SELECT DISTINCT OrderKey
            FROM #TEMP_PICK106
            WHERE PickSlipNo IS NULL         
            ORDER BY Orderkey
            
         OPEN Cur_Pickslipno
   
         FETCH NEXT FROM Cur_Pickslipno INTO @c_orderkey
         WHILE @@FETCH_STATUS <> -1 
         BEGIN
            BEGIN TRAN
            SET @c_pickheaderkey = ''
            SET @n_err = 0

            EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT
            
            SET @c_pickheaderkey = 'P' + LTRIM(@c_pickheaderkey)

            IF @n_err = 0 AND @@ERROR = 0
            BEGIN
               INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
               VALUES (@c_pickheaderkey, @c_Orderkey, @c_Loadkey, '0', '3', '')
               
               IF @@ERROR = 0
               BEGIN
                  WHILE @@TRANCOUNT > 0
                  BEGIN 
                     COMMIT TRAN                     
                  END
               END
               ELSE
               BEGIN
                    IF @@TRANCOUNT > 0
                       ROLLBACK TRAN     
                  GOTO FAILURE           
               END
            END
            ELSE
            BEGIN
               IF @@TRANCOUNT > 0
                  ROLLBACK TRAN
               GOTO FAILURE           
            END
              
            FETCH NEXT FROM Cur_Pickslipno INTO @c_orderkey
         END
         CLOSE Cur_Pickslipno
         DEALLOCATE Cur_Pickslipno

         UPDATE #TEMP_PICK106
         SET PickSlipNo = PICKHEADER.PickHeaderKey
         FROM PICKHEADER (NOLOCK)
         WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK106.LoadKey
         AND   PICKHEADER.OrderKey = #TEMP_PICK106.OrderKey
         AND   PICKHEADER.Zone = '3'
         AND   #TEMP_PICK106.PickSlipNo IS NULL
      END
      GOTO SUCCESS
   FAILURE:
      DELETE FROM #TEMP_PICK106
   SUCCESS:
      SELECT * FROM #TEMP_PICK106
      DROP TABLE #TEMP_PICK106

      WHILE @@TRANCOUNT < @n_starttcnt 
         BEGIN TRAN
END

GO