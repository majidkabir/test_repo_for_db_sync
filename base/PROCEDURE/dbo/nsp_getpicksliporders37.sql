SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_GetPickSlipOrders37                             */
/* Creation Date: 22-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: Pickslip (Refer nsp_GetPickSlipOrders01)                    */
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
/* 15-Nov-2010  audrey    1.1   SOS#196406 - Add UPPER case conversion  */
/*                                                               (ang01)*/
/* 13-Mar-2012  YTWan     1.2   SOS#238061 - Enlarge Lottable02.(wan01) */
/* 06-Jun-2013  TLTING    1.3   SOS#280077 - fine tune                  */
/* 2014-Mar-21  TLTING    1.4   SQL20112 Bug                            */
/* 11-Nov-2015  NJOW01    1.5   Change to get pickslip no by single ord */
/* 13-Nov-2015  NJOW02    1.5   Fix pickslipno prefix P                 */
/* 28-JUL-2016  CSCHONG   1.6   SOS#373693 - report config (CS01)       */
/* 28-Jan-2019  TLTING_ext 1.7 enlarge externorderkey field length      */
/* 10-Jun-2021  Mingle    1.8   add ShowLot02(ML01)                     */
/* 20-Sep-2022  Mingle    1.9   WMS-20805 modify showlot02 logic(ML02)  */
/* 11-APR-2023  KuanYee   2.0   JSM-142019 Extend TrfRoom LEN(KY01)  */
/************************************************************************/

CREATE   PROC [dbo].[nsp_GetPickSlipOrders37] (@c_loadkey NVARCHAR(10))
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
         TrfRoom          NVARCHAR(20)  NULL, -- LoadPlan.TrfRoom    --KY01
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
         ShowLot02        NVARCHAR(20) NULL ) -- ML01

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
          externorderkey,      LogicalLoc,       Areakey,    DeliveryDate,
          Lottable03,          Lottable01,       ID,               ShowField, --NJOW01  --(Vanessa)  --(CS01)
          ShowLot02) --ML01
   SELECT DISTINCT
         (SELECT PickHeaderKey FROM PICKHEADER (NOLOCK)
          WHERE ExternOrderKey = @c_LoadKey
          AND OrderKey = Orders.OrderKey
          AND ZONE = '3'),
         @c_LoadKey AS LoadKey,
         Orders.OrderKey,
         -- SOS82873 Change company info from MBOL level to LOAD level
         -- NOTE: In ECCO case,2 style, the English information saved in C_company, C_Addressaand Chinese Information saved in B_company,B_Address
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.CONSIGNEEKEY , '')
         ELSE ISNULL(ORDERS.BillToKey , '')  END  ) AS ConsigneeKey ,
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Company , '')
         ELSE ISNULL(ORDERS.C_Company, '')  END  ) AS Company  ,

         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Address1 , '')
         ELSE ISNULL(ORDERS.C_Address1, '')  END  ) AS Addr1  ,

         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Address2 , '')
         ELSE ISNULL(ORDERS.C_Address2, '')  END  ) AS Addr2  ,
         0 AS PgGroup,
         (CASE WHEN StorerConfig.sValue = '1' THEN ISNULL(ORDERS.B_Address3 , '')
         ELSE ISNULL(ORDERS.C_Address3, '')  END  ) AS Addr3,
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
         SUM(PickDetail.qty) AS Qty,
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
             ELSE CASE WHEN (SUM(pickdetail.qty) % CAST((CASE SC.SValue WHEN Pack.PackUOM5 -- (Vanessa)
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
         ISNULL (CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103), ''), -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
         LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
         LotAttribute.Lottable01, -- NJOW01
         UPPER(PickDetail.ID) --ang01 -- (Vanessa)
         ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS ShowField     --(CS01)
         --,CASE WHEN Orders.Storerkey = 'NAOS' THEN LotAttribute.Lottable02 ELSE LotAttribute.Lottable01 END AS ShowLot02 --ML01
			,Case when isnull(CLR2.Short,'') = 'Y' then LotAttribute.Lottable02 Else LotAttribute.Lottable01 END AS ShowLot02   --(ML02)	
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
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder37' AND ISNULL(CLR.Short,'') <> 'N')   --(CS01)
	LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'showLOTTABLE02'                                         --(ML02)
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_print_pickorder37' AND ISNULL(CLR2.Short,'') <> 'N')   --(ML02)
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
       ISNULL(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103), ''),  -- Added by MaryVong on 29-Dec-2003 (FBR#18681)
       LotAttribute.Lottable03, -- Added By SHONG On 2nd Mar 2004 (SOS#20463)
       LotAttribute.Lottable01, -- NJOW01
       UPPER(PickDetail.ID),  --ang01 -- (Vanessa)
       CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END,   --CS01
       --CASE WHEN Orders.Storerkey = 'NAOS' THEN LotAttribute.Lottable02 ELSE LotAttribute.Lottable01 END --ML01
		 Case when isnull(CLR2.Short,'') = 'Y' then LotAttribute.Lottable02 Else LotAttribute.Lottable01 END --(ML02)

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
      SELECT * FROM #TEMP_PICK
      DROP TABLE #TEMP_PICK

      --NJOW01
      WHILE @@TRANCOUNT < @n_starttcnt
         BEGIN TRAN
END

GO