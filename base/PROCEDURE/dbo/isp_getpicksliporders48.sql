SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders48                              */
/* Creation Date: 02-AUG-2012                                            */
/* Copyright: IDS                                                        */
/* Written by: YTWan                                                     */
/*                                                                       */
/* Purpose: 251798-Pickslip- Copy & Modified from nsp_GetPickSlipOrders01*/
/*                                                                       */
/* Called By: r_dw_print_pickorder48                                     */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/* 10-Apr-2013  NJOW01  1.0   273764-Add intermodalvehicle               */
/* 06-Jun-2013  TLTING  1.1   SOS#280077 - fine tune                     */
/* 27-Dec-2016  CSCHONG 1.2   WMS-840-add report config (CS01)           */
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length      */
/*************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders48] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)
         , @n_Batch           INT
         , @c_pickheaderkey   NVARCHAR(10)

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @b_success       = 1
   SET @n_err           = 0
   SET @c_errmsg        = ''

   SET @n_Batch         = 0
   SET @c_pickheaderkey = ''

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TEMP_PICK
         ( PickSlipNo      NVARCHAR(10) NULL
         , LoadKey         NVARCHAR(10)
         , OrderKey        NVARCHAR(10)
         , ExternOrderkey  NVARCHAR(50) NULL   --tlting_ext
         , DeliveryDate    DATETIME     NULL
         , ConsigneeKey    NVARCHAR(15)
         , Company         NVARCHAR(45)
         , Addr1           NVARCHAR(45) NULL
         , Addr2           NVARCHAR(45) NULL
         , Addr3           NVARCHAR(45) NULL
         , PostCode        NVARCHAR(15) NULL
         , Route           NVARCHAR(10) NULL
         , Route_Desc      NVARCHAR(60) NULL  -- RouteMaster.Desc
         , TrfRoom         NVARCHAR(5)  NULL  -- LoadPlan.TrfRoom
         , Transporter     NVARCHAR(60) NULL
         , VehicleNo       NVARCHAR(30) NULL
         , Notes1          NVARCHAR(60) NULL
         , Notes2          NVARCHAR(60) NULL
         , SKU             NVARCHAR(20)
         , SkuDesc         NVARCHAR(60)
         , Qty             INT
         , CartonQty       INT          NULL
         , PalletQty       INT          NULL
         , Lot             NVARCHAR(10)
         , Lottable01      NVARCHAR(18) NULL
         , Lottable02      NVARCHAR(18) NULL
         , Lottable03      NVARCHAR(18) NULL
         , Lottable04      DATETIME NULL
         , Lottable05      DATETIME NULL
         , PackPallet      INT
         , PackCasecnt     INT
         , Loc             NVARCHAR(10) NULL
         , LogicalLoc      NVARCHAR(18) NULL
         , Zone            NVARCHAR(1)
         , Areakey         NVARCHAR(10) NULL
         , PrintedFlag     NVARCHAR(1)  NULL
			, OHUDef01        NVARCHAR(20) NULL            --(CS01)
			, ORDConsigneeKey NVARCHAR(15) NULL            --(CS01)
			, ShowField       NVARCHAR(1)  NULL            --(CS01)
         )

   INSERT INTO #TEMP_PICK
         ( PickSlipNo
         , LoadKey
         , OrderKey
         , ExternOrderkey
         , DeliveryDate
         , ConsigneeKey
         , Company
         , Addr1
         , Addr2
         , Addr3
         , PostCode
         , Route
         , Route_Desc
         , TrfRoom
         , Transporter
         , VehicleNo
         , Notes1
         , Notes2
         , Sku
         , SkuDesc
         , Qty
         , CartonQty
         , PalletQty
         , Lot
         , Lottable01
         , Lottable02
         , Lottable03
         , Lottable04
         , Lottable05
         , PackPallet
         , PackCasecnt
         , Loc
         , LogicalLoc
         , Zone
         , Areakey
         , PrintedFlag
			, OHUDef01                                   --(CS01)
			, ORDConsigneeKey                            --(CS01)
			, ShowField                                  --(CS01)
         )

   SELECT DISTINCT
           PickHeaderKey  = ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '')
         , LoadKey = @c_LoadKey
         , Orders.OrderKey
         , ExternOrderKey = ISNULL(RTRIM(ORDERS.ExternOrderKey), '')
         , DeliveryDate   = ORDERS.DeliveryDate
         -- SOS82873 Change company info from MBOL level to LOAD level
         -- NOTE: In ECCO case,2 style, the English information saved in C_company, C_Address and Chinese Information saved in B_company,B_Address
         , ConsigneeKey = CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.ConsigneeKey), '')
                                                                                ELSE ISNULL(RTRIM(ORDERS.BillToKey), '')
                                                                                END
         , Company = CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Company), '')
                                                                           ELSE ISNULL(RTRIM(ORDERS.C_Company), '')
                                                                           END
         , Addr1   = CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Address1), '')
                                                                           ELSE ISNULL(RTRIM(ORDERS.C_Address1), '')
                                                                           END
         , Addr2   = CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Address2), '')
                                                                           ELSE ISNULL(RTRIM(ORDERS.C_Address2), '')
                                                                           END
         , Addr3   = CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Address3), '')
                                                                           ELSE ISNULL(RTRIM(ORDERS.C_Address3), '')
                                                                           END
         , PostCode   = ISNULL(RTRIM(ORDERS.C_Zip),'')
         , Route      = ISNULL(RTRIM(ORDERS.Route),'')
         , Route_Desc = ISNULL(RTRIM(ROUTEMASTER.Descr), '')
         , TrfRoom    = ISNULL(RTRIM(ORDERS.Door), '')
         , Transporter= ''
         , VehicleNo  = ISNULL(RTRIM(ORDERS.IntermodalVehicle), '')   --NJOW01
         , Notes1     = CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, ''))
         , Notes2     = CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2,''))
         , Sku        = ISNULL(RTRIM(PICKDETAIL.Sku),'')
         , SkuDescr   = ISNULL(SKU.Descr,'')
         , Qty        = SUM(PICKDETAIL.Qty)
         , CartonQty  = 0
         , PalletQty  = CASE WHEN ISNULL(PACK.Pallet,0.00) = 0.00 THEN 0.00
                             ELSE CASE WHEN (SUM(PICKDETAIL.Qty) % CAST(ISNULL(PACK.Pallet,0.00) AS INT)) > 0 THEN 0
                                       ELSE 1
                                  END
                        END
         , Lot        = ISNULL(RTRIM(PICKDETAIL.Lot),'')
         , Lottable01 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')
         , Lottable02 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
         , Lottable03 = ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')
         , Lottable04 = ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
         , Lottable05 = ISNULL(LOTATTRIBUTE.Lottable05, '19000101')
         , Pallet     = ISNULL(PACK.Pallet,0.00)
         , CaseCnt    = ISNULL(PACK.CaseCnt,0.00)
         , Loc        = ISNULL(RTRIM(PICKDETAIL.Loc),'')
         , LogicalLocation = ISNULL(RTRIM(LOC.LogicalLocation), '')
         , Zone       = '3'
         , Areakey    = ISNULL(RTRIM(AreaDetail.AreaKey), '00')
         , PrintedFlag= CASE WHEN ISNULL(RTRIM(PICKHEADER.PickType), 'N') = '1' THEN 'Y' ELSE 'N' END
			, OHUdef01   = ORDERS.Userdefine01                                                    --(CS01)
			, ORDConsigneeKey = ISNULL(RTRIM(ORDERS.ConsigneeKey), '')                            --(CS01)
			, ShowField  = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END              --(CS01)
   FROM LOADPLANDETAIL WITH (NOLOCK)
   JOIN ORDERS         WITH (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
   JOIN STORER         WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
   JOIN ORDERDETAIL    WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
   LEFT OUTER JOIN STORERCONFIG WITH (NOLOCK) ON (ORDERS.StorerKey = STORERCONFIG.StorerKey AND STORERCONFIG.ConfigKey = 'UsedBillToAddressForPickSlip')
   LEFT OUTER JOIN ROUTEMASTER  WITH (NOLOCK) ON (ORDERS.Route = ROUTEMASTER.Route)
   JOIN PICKDETAIL              WITH (NOLOCK) ON (PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey)
                                              AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderlineNumber)
   JOIN LOTATTRIBUTE   WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU            WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
   JOIN PACK           WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   JOIN LOC            WITH (NOLOCK, INDEX (PKLOC)) ON (PICKDETAIL.LOC = LOC.LOC)
   LEFT OUTER JOIN AREADETAIL   WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
   LEFT OUTER JOIN PICKHEADER   WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = PICKHEADER.ExternOrderkey)
                                              AND(LOADPLANDETAIL.Orderkey= PICKHEADER.Orderkey)
                                              AND(PICKHEADER.Zone = '3')
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_print_pickorder48' AND ISNULL(CLR.Short,'') <> 'N') 
   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
     AND PICKDETAIL.Status >= '0'
   GROUP BY ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '')
         , ORDERS.OrderKey
         , ISNULL(RTRIM(ORDERS.ExternOrderKey), '')
         , ORDERS.DeliveryDate
         , CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.ConsigneeKey), '')
                                                                 ELSE ISNULL(RTRIM(ORDERS.BillToKey), '')
                                                                 END
         , CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Company), '')
                                                                 ELSE ISNULL(RTRIM(ORDERS.C_Company), '')
                                                                 END
         , CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Address1), '')
                                                                 ELSE ISNULL(RTRIM(ORDERS.C_Address1), '')
                                                                 END
         , CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Address2), '')
                                                                 ELSE ISNULL(RTRIM(ORDERS.C_Address2), '')
                                                                 END
         , CASE WHEN ISNULL(RTRIM(STORERCONFIG.sValue),'') = '1' THEN ISNULL(RTRIM(ORDERS.B_Address3), '')
                                                                 ELSE ISNULL(RTRIM(ORDERS.C_Address3), '')
                                                                 END
         , ISNULL(RTRIM(ORDERS.C_Zip),'')
         , ISNULL(RTRIM(ORDERS.Route),'')
         , ISNULL(RTRIM(ROUTEMASTER.Descr), '')
         , ISNULL(RTRIM(ORDERS.Door), '')
         , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, ''))
         , CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, ''))
         , ISNULL(RTRIM(PICKDETAIL.Sku),'')
         , ISNULL(SKU.Descr,'')
         , ISNULL(RTRIM(PICKDETAIL.Lot),'')
         , ISNULL(RTRIM(LOTATTRIBUTE.Lottable01),'')
         , ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
         , ISNULL(RTRIM(LOTATTRIBUTE.Lottable03),'')
         , ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
         , ISNULL(LOTATTRIBUTE.Lottable05, '19000101')
         , ISNULL(PACK.Pallet,0.00)
         , ISNULL(PACK.CaseCnt,0.00)
         , ISNULL(RTRIM(PICKDETAIL.Loc),'')
         , ISNULL(RTRIM(LOC.LogicalLocation), '')
         , ISNULL(RTRIM(AreaDetail.AreaKey), '00')
         , CASE WHEN ISNULL(RTRIM(PICKHEADER.PickType), 'N') = '1' THEN 'Y' ELSE 'N' END
         , ISNULL(RTRIM(ORDERS.IntermodalVehicle), '')  --NJOW01
			, ORDERS.Userdefine01                                          --(CS01)
			, ISNULL(RTRIM(ORDERS.ConsigneeKey), '')                       --(CS01)
			, CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END    --(CS01)

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
     , TrafficCop = NULL
   WHERE ExternOrderKey = @c_LoadKey
   AND   Zone = '3'

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      IF @@TRANCOUNT > 0
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
   END

   SELECT @n_Batch = Count(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE (PickSlipNo IS NULL OR RTRIM(PickSlipNo) = '')

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_Batch > 0
   BEGIN
      BEGIN TRAN -- SOS#280077
      EXECUTE nspg_GetKey 'PICKSLIP'
            , 9
            , @c_Pickheaderkey   OUTPUT
            , @b_success         OUTPUT
            , @n_err             OUTPUT
            , @c_errmsg          OUTPUT
            , 0
            , @n_Batch

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
      SELECT 'P' + RIGHT ( '000000000' +
                           LTRIM(RTRIM( STR( CAST(@c_pickheaderkey AS INT) +
                           ( SELECT COUNT(DISTINCT orderkey)
                           FROM #TEMP_PICK as Rank
                           WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                           AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- SOS#280077
                           ) -- str
                          ))--LTRIM & RTRIM
                        , 9)
               , OrderKey
               , LoadKey
               , '0'
               , '3'
               , ''
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
      GROUP BY LoadKey, OrderKey

      SELECT @n_err = @@ERROR -- SOS#280077
      IF @n_err = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      UPDATE #TEMP_PICK
      SET   PickSlipNo = PICKHEADER.PickHeaderKey
      FROM  PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   (#TEMP_PICK.PickSlipNo IS NULL OR RTRIM(#TEMP_PICK.PickSlipNo) = '')
   END
   GOTO SUCCESS

FAILURE:
   DELETE FROM #TEMP_PICK

SUCCESS:
   SELECT PickSlipNo
         , LoadKey
         , OrderKey
         , ExternOrderkey
         , DeliveryDate
         , ConsigneeKey
         , Company
         , Addr1
         , Addr2
         , Addr3
         , PostCode
         , Route
         , Route_Desc
         , TrfRoom
         , Transporter
         , VehicleNo
         , Notes1
         , Notes2
         , Sku
         , SkuDesc
         , Qty
         , CartonQty
         , PalletQty
         , Lot
         , Lottable01
         , Lottable02
         , Lottable03
         , Lottable04
         , Lottable05
         , PackPallet
         , PackCasecnt
         , Loc
         , LogicalLoc
         , Zone
         , Areakey
         , PrintedFlag
			, OHUDef01            --(CS01)
			, ORDConsigneeKey     --(CS01)
			, ShowField           --(CS01)
   FROM #TEMP_PICK
   ORDER BY Orderkey
         , Areakey
         , PalletQty DESC
         , Loc
         , Sku
         , Lottable01
         , Lottable02

   DROP TABLE #TEMP_PICK

   -- WHILE @@TRANCOUNT < @n_StartTCnt
   -- BEGIN
   --    BEGIN TRAN
   -- END
END

GO