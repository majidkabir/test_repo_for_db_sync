SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders102                            */
/* Creation Date: 15-Nov-2019                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11108 - CN_GYM_Picking Slip_CR                          */ 
/*          (Refer nsp_GetPickSlipOrders37)                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 18/11/2019   mingle01  1.0   adding codelkup and mappings.           */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders102] (@c_loadkey NVARCHAR(10))
 AS
 BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_pickheaderkey      NVARCHAR(10),
           @n_continue           INT,
           @c_errmsg             NVARCHAR(255),
           @b_success            INT,
           @n_err                INT,
           @n_pickslips_required INT,
           @n_starttcnt          INT, -- SOS#280077
           @c_orderkey           NVARCHAR(10) --NJOW01

   SELECT @n_starttcnt = @@TRANCOUNT   -- SOS#280077

   WHILE @@TRANCOUNT > 0 -- SOS#280077
   BEGIN
      COMMIT TRAN
   END

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
         --(Wan01) - START
         --Lottable02       NVARCHAR(10) NULL,
         Lottable02       NVARCHAR(18) NULL,
         --(Wan01) - END
         Lottable04       DATETIME NULL,
         Lottable05       DATETIME NULL,
         packpallet       INT,
         packcasecnt      INT,
         externorderkey   NVARCHAR(50) NULL,   --tlting_ext
         LogicalLoc       NVARCHAR(18) NULL,
         Areakey          NVARCHAR(10) NULL,     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
         UOM              NVARCHAR(10) NULL,  -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
         DeliveryDate     NVARCHAR(10) NULL,  -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
         Lottable03       NVARCHAR(18) NULL,      -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
         Lottable01       NVARCHAR(18) NULL,  -- NJOW01
         ID               NVARCHAR(18) NULL,  -- (Vanessa)
         ShowField        NVARCHAR(1) NULL, -- CS01
         --start mingle01
         Title                  NVARCHAR(50) NULL,
         OrdersNotes            NVARCHAR(50) NULL,
         ExpectedDeliveryDate   NVARCHAR(50) NULL,
         Transport              NVARCHAR(50) NULL,
         Location               NVARCHAR(50) NULL,
         CartonsNo              NVARCHAR(50) NULL,
         EachNo                 NVARCHAR(50) NULL,
         Quantity               NVARCHAR(50) NULL,
         SubQuantity            NVARCHAR(50) NULL,
         ShowChineseTitle       NVARCHAR(50)NULL,
         CustOrdNo              NVARCHAR(50)NULL,
         ManLot                 NVARCHAR(50)NULL)
         --end mingle01


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
          externorderkey,      LogicalLoc,       Areakey,          DeliveryDate,
          Lottable03,          Lottable01,       ID,               ShowField,      --NJOW01  --(Vanessa)  --(CS01)  
          --start mingle01
          Title,               OrdersNotes,      ExpectedDeliveryDate,
          Transport,         Location,           CartonsNo,        EachNo,
          Quantity,         SubQuantity,         ShowChineseTitle,  CustOrdNo,
          ManLot)
          --end mingle01

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
         UPPER(PickDetail.loc), --ang01
         UPPER(PickDetail.sku), --ang01
         ISNULL(Sku.Descr,'') SkuDescr,
         SUM(PickDetail.qty) as Qty,
         0 AS TEMPQTY1,
         TempQty2 =
             CASE WHEN (CASE SC.SValue WHEN Pack.PackUOM5  -- (Vanessa)
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
             ELSE CASE WHEN (Sum(pickdetail.qty) % CAST((CASE SC.SValue WHEN Pack.PackUOM5 -- (Vanessa)
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
             END, -- Vicky
         ISNULL((SELECT Distinct 'Y' FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = '3'), 'N') AS PrintedFlag,
         '3' Zone,
         Pickdetail.Lot,
         '' CarrierKey,
         '' AS VehicleNo,
         UPPER(LotAttribute.Lottable02), --ang01
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
         ELSE PACK.Pallet END AS Pallet, -- (Vanessa)
         PACK.CaseCnt,
         ORDERS.ExternOrderKey AS ExternOrderKey,
         UPPER(ISNULL(LOC.LogicalLocation, '')) AS LogicalLocation, --ang01
         UPPER(ISNULL(AreaDetail.AreaKey, '00')) AS Areakey,  --ang01 -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
         ISNULL (CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 111), ''), -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
         LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
         LotAttribute.Lottable01, -- NJOW01
         UPPER(PickDetail.ID) --ang01 -- (Vanessa)
         ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowField,    --(CS01)
         --start mingle01
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'小小运动馆拣货单' ELSE 'Picking Slip' END AS Title,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'订单备注: ' ELSE 'Orders Notes:' END AS OrdersNotes,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'发货日期：' ELSE 'Expected Delivery Date:' END AS ExpectedDeliveryDate,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'运输方式：' ELSE 'Transporter:' END AS Transport,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'库位' ELSE 'Loc' END AS [Location],
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'整箱数' ELSE 'Cartons' END AS CartonsNo,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'零头数' ELSE 'Each' END AS EachNo,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'总件数' ELSE 'Qty' END AS Quantity,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'订单总件数：' ELSE 'Sub total for order:' END AS SubQuantity,
         ISNULL(CLR1.Short,'N') AS ShowChineseTitle,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'订单号' ELSE 'Customer Order No:' END AS CustOrdNo,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'箱号' ELSE 'Man Lot#' END AS ManLot
         --end mingle01
   FROM LoadPlanDetail (NOLOCK)
   JOIN Orders (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
   JOIN Storer (NOLOCK) ON (ORDERS.StorerKey = Storer.StorerKey)
   JOIN OrderDetail (NOLOCK) ON (OrderDetail.OrderKey = ORDERS.OrderKey)  -- Added By YokeBeen on 18-Mar-2002 (Ticket # 2539)
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
                                            AND SC.ConfigKey = 'DefaultPalletUOM') -- (Vanessa)
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                                         --(CS01)
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder102' AND ISNULL(CLR.Short,'') <> 'N')   --(CS01)
   LEFT JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Listname='REPORTCFG'                                          --mingle01
                                          AND CLR1.Long = 'r_dw_print_pickorder102') AND CLR1.CODE = 'ShowChineseTitle'                          --mingle01
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
       UPPER(PickDetail.sku), --ang01
       ISNULL(Sku.Descr,''),
       Pickdetail.Lot,
       UPPER(LotAttribute.Lottable02), --ang01
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
       UPPER(ISNULL(LOC.LogicalLocation, '')),  --ang01
       ISNULL(AreaDetail.AreaKey, '00'),     -- Added By YokeBeen on 05-Mar-2002 (Ticket # 3377)
       ISNULL(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 111), ''),  -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
       LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
       LotAttribute.Lottable01, -- NJOW01
       UPPER(PickDetail.ID),  --ang01 -- (Vanessa)
       CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,   --CS01
       --start mingle01
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'小小运动馆拣货单' ELSE 'Picking Slip' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'页码1/1' ELSE 'Reprint' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'订单备注: ' ELSE 'Orders Notes:' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'发货日期：' ELSE 'Expected Delivery Date:' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'运输方式：' ELSE 'Transporter:' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'库位' ELSE 'Loc' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN 'PK' ELSE '(Each)' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'整箱数' ELSE 'Cartons' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'零头数' ELSE 'Each' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'总件数' ELSE 'Qty' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'订单总件数：' ELSE 'Sub total for order:' END,
         ISNULL(CLR1.Short,'N'),
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'订单号' ELSE 'Customer Order No:' END,
         CASE WHEN ISNULL(CLR1.Short,'N') = 'Y' THEN N'箱号' ELSE 'Man Lot#' END
         --end mingle01

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
         /*
         IF @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
         	  IF @@TRANCOUNT > 0
               ROLLBACK TRAN
         END
         */
      END

      SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
      FROM #TEMP_PICK
      WHERE PickSlipNo IS NULL

      IF @@ERROR <> 0
      BEGIN
         GOTO FAILURE
      END
      ELSE IF @n_pickslips_required > 0
      BEGIN
      	 --NJOW01 Start
         DECLARE Cur_Pickslipno CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 			
            SELECT DISTINCT OrderKey
            FROM #TEMP_PICK
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
         --NJOW01 End
       	 
      	 /*
         BEGIN TRAN -- SOS#280077
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

         SELECT @n_err = @@ERROR -- SOS#280077
         IF @n_err = 0
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END

         BEGIN TRAN -- SOS#280077
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
                              dbo.fnc_LTrim( dbo.fnc_RTrim( STR(CAST(@c_pickheaderkey AS INT) +
                                           ( SELECT COUNT(DISTINCT OrderKey)
                                             FROM #TEMP_PICK AS Rank
                                             WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                                             AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- SOS#280077
                                            ) -- str
                                           )) -- dbo.fnc_RTrim
                                         , 9)
              , OrderKey, LoadKey, '0', '3', ''
         FROM #TEMP_PICK WHERE PickSlipNo IS NULL
         GROUP By LoadKey, OrderKey

         SELECT @n_err = @@ERROR -- SOS#280077
         IF @n_err = 0
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
         END
         */

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
      SELECT DISTINCT * FROM #TEMP_PICK
      DROP TABLE #TEMP_PICK

      --NJOW01
      WHILE @@TRANCOUNT < @n_starttcnt 
         BEGIN TRAN
END

GO