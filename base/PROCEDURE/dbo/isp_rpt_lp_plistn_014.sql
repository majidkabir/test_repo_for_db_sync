SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTN_014                                 */
/* Creation Date: 28-JUL-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-20147                                                      */
/*                                                                         */
/* Called By: RPT_LP_PLISTN_014                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author    Ver Purposes                                      */
/* 29-Jul-2022 WLChooi   1.0 DevOps Combine Script                         */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PLISTN_014]
   @c_Loadkey       NVARCHAR(20)
 , @c_PreGenRptData NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_company  NVARCHAR(45)
         , @c_address1 NVARCHAR(45)
         , @c_address2 NVARCHAR(45)
         , @c_address3 NVARCHAR(45)
         , @c_address4 NVARCHAR(45)

   DECLARE @n_starttrancnt         INT
         , @n_continue             INT
         , @c_errmsg               NVARCHAR(255)
         , @b_success              INT
         , @n_err                  INT
         , @c_PrintedFlag          NVARCHAR(1)
         , @c_Orderkey             NVARCHAR(10)
         , @c_LocTypeDesc          NVARCHAR(20)
         , @c_Pickdetailkey        NVARCHAR(10)
         , @c_PrevLoadkey          NVARCHAR(10)
         , @c_PrevOrderkey         NVARCHAR(10)
         , @c_PrevLocTypeDesc      NVARCHAR(20)
         , @c_Pickslipno           NVARCHAR(10)
         , @c_Orderlinenumber      NVARCHAR(5)
         , @c_LocTypeCriteria      NVARCHAR(255)
         , @c_ExecStatement        NVARCHAR(4000)
         , @c_putawayzone          NVARCHAR(10)
         , @c_PrevPutawayzone      NVARCHAR(10)
         , @n_Linecount            INT
         , @c_sku                  NVARCHAR(20)
         , @c_loc                  NVARCHAR(10)
         , @c_id                   NVARCHAR(18)
         , @c_lottable01           NVARCHAR(18)
         , @c_lottable02           NVARCHAR(18)
         , @dt_lottable04          DATETIME
         , @c_NOSPLITBYLINECNTZONE NVARCHAR(10)

   SET @c_company = N''
   SET @c_address1 = N''
   SET @c_address2 = N''
   SET @c_address3 = N''
   SET @c_address4 = N''

   IF ISNULL(@c_PreGenRptData, '') IN ( '', '0' )
      SET @c_PreGenRptData = ''

   SELECT @n_starttrancnt = @@TRANCOUNT
        , @n_continue = 1

   --check if the loadplan already printed other pickslip type then return error to reject.
   IF EXISTS (  SELECT PickHeaderKey
                FROM PICKHEADER WITH (NOLOCK)
                WHERE ExternOrderKey = @c_Loadkey AND ISNULL(RTRIM(OrderKey), '') = '' AND Zone = 'LP')
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500
      SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                         + N': Pickslip already printed using Consolidated option. (isp_RPT_LP_PLISTN_014)'
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      CREATE TABLE #TEMP_GETPICKSUMM01
      (
         PickSlipNo       NVARCHAR(10) NULL
       , LoadKey          NVARCHAR(10) NULL
       , OrderKey         NVARCHAR(10) NULL
       , ConsigneeKey     NVARCHAR(15) NULL
       , Company          NVARCHAR(45) NULL
       , Addr1            NVARCHAR(45) NULL
       , Addr2            NVARCHAR(45) NULL
       , Addr3            NVARCHAR(45) NULL
       , Addr4            NVARCHAR(45) NULL
       , City             NVARCHAR(45) NULL
       , LOC              NVARCHAR(10) NULL
       , ID               NVARCHAR(18) NULL
       , SKU              NVARCHAR(20) NULL
       , AltSKU           NVARCHAR(20) NULL
       , SkuDesc          NVARCHAR(60) NULL
       , Qty              INT
       , PrintedFlag      NVARCHAR(1)  NULL
       , LocationTypeDesc NVARCHAR(20) NULL
       , Lottable01       NVARCHAR(18) NULL
       , Lottable02       NVARCHAR(18) NULL
       , Lottable04       DATETIME     NULL
       , externorderkey   NVARCHAR(30) NULL
       , LogicalLoc       NVARCHAR(18) NULL
       , Shelflife        INT
       , MinShelfLife     INT
       , pallet           INT
       , casecnt          INT
       , pickafterdate    DATETIME     NULL
       , putawayzone      NVARCHAR(10) NULL
       , LRoute           NVARCHAR(10) NULL
       , LEXTLoadKey      NVARCHAR(20) NULL
       , Storerkey        NVARCHAR(20) NULL
       , Facility         NVARCHAR(5)  DEFAULT ('')
       , CustName         NVARCHAR(50) DEFAULT ('')
      )

      INSERT INTO #TEMP_GETPICKSUMM01 (PickSlipNo, LoadKey, OrderKey, ConsigneeKey, Company, Addr1, Addr2, Addr3, Addr4
                                     , City, LOC, ID, SKU, AltSKU, SkuDesc, Qty, PrintedFlag, LocationTypeDesc
                                     , Lottable01, Lottable02, Lottable04, externorderkey, LogicalLoc, Shelflife
                                     , MinShelfLife, pallet, casecnt, pickafterdate, putawayzone, LRoute, LEXTLoadKey
                                     , Storerkey, Facility, CustName)
      SELECT RefKeyLookup.Pickslipno
           , @c_Loadkey AS LoadKey
           , ORDERS.OrderKey
           , ISNULL(ORDERS.ConsigneeKey, '')
           , ISNULL(ORDERS.C_Company, '')
           , ISNULL(ORDERS.C_Address1, '')
           , ISNULL(ORDERS.C_Address2, '')
           , ISNULL(ORDERS.C_Address3, '')
           , ISNULL(ORDERS.C_Address4, '')
           , ISNULL(ORDERS.C_City, '')
           , PICKDETAIL.Loc
           , PICKDETAIL.ID
           , PICKDETAIL.Sku
           , SKU.ALTSKU
           , SKU.DESCR
           , SUM(PICKDETAIL.Qty)
           , ISNULL(
             (  SELECT DISTINCT 'Y'
                FROM PICKHEADER WITH (NOLOCK)
                WHERE PickHeaderKey = RefKeyLookup.Pickslipno AND OrderKey = ORDERS.OrderKey AND Zone = 'LP')
           , 'N') AS PrintedFlag
           , CASE WHEN LOC.LocationType = 'OTHER' THEN 'PALLET PICKING LIST'
                  ELSE 'EACH PICKING LIST' END
           , LOTATTRIBUTE.Lottable01
           , LOTATTRIBUTE.Lottable02
           , ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
           , ORDERS.ExternOrderKey
           , LOC.LogicalLocation
           , SKU.ShelfLife
           , STORER.MinShelfLife
           , PACK.Pallet
           , PACK.CaseCnt
           , CASE WHEN LEN(LTRIM(LOTATTRIBUTE.Lottable01)) = 8 THEN
                     CASE WHEN ISDATE(
                                  SUBSTRING(LTRIM(LOTATTRIBUTE.Lottable01), 5, 4)
                                  + SUBSTRING(LTRIM(LOTATTRIBUTE.Lottable01), 3, 2)
                                  + SUBSTRING(LTRIM(LOTATTRIBUTE.Lottable01), 1, 2)) = 1 THEN
                             CONVERT(
                                DATETIME
                              , SUBSTRING(LTRIM(LOTATTRIBUTE.Lottable01), 5, 4)
                                + SUBSTRING(LTRIM(LOTATTRIBUTE.Lottable01), 3, 2)
                                + SUBSTRING(LTRIM(LOTATTRIBUTE.Lottable01), 1, 2)) + SKU.ShelfLife
                             - STORER.MinShelfLife
                          ELSE '19000101' END
                  ELSE '19000101' END
           , LOC.PickZone AS Putawayzone
           , LoadPlan.Route AS LRoute
           , LoadPlan.ExternLoadKey AS LEXTLoadKey
           , ORDERS.StorerKey AS storerkey
           , LoadPlan.facility AS facility
           , LoadPlanDetail.CustomerName AS CustName
      FROM LoadPlanDetail WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON LoadPlanDetail.OrderKey = ORDERS.OrderKey
      JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
      JOIN PICKDETAIL WITH (NOLOCK) ON  ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey
                                    AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
      JOIN STORER WITH (NOLOCK) ON ORDERS.StorerKey = STORER.StorerKey
      JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku
      JOIN PACK WITH (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
      LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailkey = PICKDETAIL.PickDetailKey)
      JOIN LoadPlan WITH (NOLOCK) ON LoadPlan.LoadKey = ORDERDETAIL.LoadKey
      WHERE PICKDETAIL.Status < '5' AND LoadPlanDetail.LoadKey = @c_Loadkey
      GROUP BY RefKeyLookup.Pickslipno
             , ORDERS.OrderKey
             , ISNULL(ORDERS.ConsigneeKey, '')
             , ISNULL(ORDERS.C_Company, '')
             , ISNULL(ORDERS.C_Address1, '')
             , ISNULL(ORDERS.C_Address2, '')
             , ISNULL(ORDERS.C_Address3, '')
             , ISNULL(ORDERS.C_Address4, '')
             , ISNULL(ORDERS.C_City, '')
             , PICKDETAIL.Loc
             , PICKDETAIL.ID
             , PICKDETAIL.Sku
             , SKU.ALTSKU
             , SKU.DESCR
             , CASE WHEN LOC.LocationType = 'OTHER' THEN 'PALLET PICKING LIST'
                    ELSE 'EACH PICKING LIST' END
             , LOTATTRIBUTE.Lottable01
             , LOTATTRIBUTE.Lottable02
             , ISNULL(LOTATTRIBUTE.Lottable04, '19000101')
             , ORDERS.ExternOrderKey
             , LOC.LogicalLocation
             , SKU.ShelfLife
             , STORER.MinShelfLife
             , PACK.Pallet
             , PACK.CaseCnt
             , LOC.PickZone
             , LoadPlan.Route
             , LoadPlan.ExternLoadKey
             , ORDERS.StorerKey
             , LoadPlan.facility
             , LoadPlanDetail.CustomerName

      IF @c_PreGenRptData = 'Y'
      BEGIN
         BEGIN TRAN
         -- Uses PickType as a Printed Flag  
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET PickType = '1'
           , TrafficCop = NULL
         WHERE ExternOrderKey = @c_Loadkey AND Zone = 'LP'
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

      SET @c_Loadkey = ''
      SET @c_Orderkey = ''
      SET @c_LocTypeDesc = N''
      SET @c_Pickdetailkey = ''
      SET @n_continue = 1
      SET @c_putawayzone = ''
      SET @n_Linecount = 0

      DECLARE C_Orderkey_LocTypeDesc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TP.LoadKey
                    , TP.OrderKey
                    , TP.LocationTypeDesc
                    , TP.putawayzone
                    , TP.SKU
                    , TP.LOC
                    , TP.ID
                    , TP.Lottable01
                    , TP.Lottable02
                    , TP.Lottable04
                    , CASE WHEN CLR.Code IS NOT NULL THEN 'Y'
                           ELSE 'N' END AS NOSPLITBYLINECNTZONE
      FROM #TEMP_GETPICKSUMM01 TP
      JOIN ORDERS O (NOLOCK) ON (TP.OrderKey = O.OrderKey)
      LEFT JOIN CODELKUP CLR (NOLOCK) ON (   O.StorerKey = CLR.Storerkey
                                         AND CLR.Code = 'NOSPLITBYLINECNTZONE'
                                         AND CLR.LISTNAME = 'REPORTCFG'
                                         AND CLR.Long = 'RPT_LP_PLISTN_014'
                                         AND ISNULL(CLR.Short, '') <> 'N')
      WHERE (TP.PickSlipNo IS NULL OR TP.PickSlipNo = '') AND @c_PreGenRptData = 'Y'
      ORDER BY TP.LoadKey
             , TP.OrderKey
             , TP.LocationTypeDesc
             , TP.putawayzone
             , TP.LOC
             , TP.SKU
             , TP.ID

      OPEN C_Orderkey_LocTypeDesc

      FETCH NEXT FROM C_Orderkey_LocTypeDesc
      INTO @c_Loadkey
         , @c_Orderkey
         , @c_LocTypeDesc
         , @c_putawayzone
         , @c_sku
         , @c_loc
         , @c_id
         , @c_lottable01
         , @c_lottable02
         , @dt_lottable04
         , @c_NOSPLITBYLINECNTZONE

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN -- while 1  
         IF ISNULL(@c_Orderkey, '0') = '0'
            BREAK

         SELECT @n_Linecount = @n_Linecount + 1

         IF @c_PrevLoadkey <> @c_Loadkey
         OR @c_PrevOrderkey <> @c_Orderkey
         OR @c_PrevLocTypeDesc <> @c_LocTypeDesc
         OR (@c_PrevPutawayzone <> @c_putawayzone AND @c_NOSPLITBYLINECNTZONE <> 'Y')
         OR (@n_Linecount > 15 AND @c_NOSPLITBYLINECNTZONE <> 'Y')
         BEGIN
            SET @c_Pickslipno = ''
            SET @n_Linecount = 1

            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_Pickslipno OUTPUT
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

            IF @b_success = 1
            BEGIN
               SELECT @c_Pickslipno = 'P' + @c_Pickslipno
               INSERT PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, Zone, PickType, WaveKey)
               VALUES (@c_Pickslipno, @c_Orderkey, @c_Loadkey, 'LP', '0', @c_Pickslipno)

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63501
                  SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                     + N': Insert into PICKHEADER Failed. (isp_GetPickSummary01)'
                  GOTO FAILURE
               END
            END -- @b_success = 1    
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63502
               SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err) + N': Get PSNO Failed. (isp_GetPickSummary01)'
               BREAK
            END
         END -- @c_PrevLoadKey <> @c_LoadKey OR @c_PrevOrderKey <> @c_OrderKey OR  @c_PrevLocTypeDesc <> @c_LocTypeDesc   

         IF @n_continue = 1
         BEGIN
            SET @c_LocTypeCriteria = N''
            SET @c_ExecStatement = N''

            IF @c_LocTypeDesc = 'PALLET PICKING LIST'
            BEGIN
               SET @c_LocTypeCriteria = N'AND LOC.LocationType = ''OTHER'''
            END
            ELSE
            BEGIN
               SET @c_LocTypeCriteria = N'AND LOC.LocationType <> ''OTHER'''
            END

            SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR '
                                   + N'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber '
                                   + N'FROM   PickDetail WITH (NOLOCK) ' + N'JOIN   OrderDetail WITH (NOLOCK) '
                                   + N'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND '
                                   + N'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) '
                                   + N'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) '
                                   + N'JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) '
                                   + N'WHERE  OrderDetail.OrderKey = N''' + @c_Orderkey + N''''
                                   + N' AND    OrderDetail.LoadKey  = N''' + @c_Loadkey + N''' '
                                   + N' AND LOC.PickZone = N''' + RTRIM(@c_putawayzone) + N''' '
                                   + N' AND Pickdetail.Sku = N''' + RTRIM(@c_sku) + N''' '
                                   + N' AND Pickdetail.Loc = N''' + RTRIM(@c_loc) + N''' '
                                   + N' AND Pickdetail.Id = N''' + RTRIM(@c_id) + N''' '
                                   + N' AND Lotattribute.Lottable01 = N''' + RTRIM(@c_lottable01) + N''' '
                                   + N' AND Lotattribute.Lottable02 = N''' + RTRIM(@c_lottable02) + N''' '
                                   + N' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable04,''19000101''),112) = '''
                                   + CONVERT(CHAR(10), @dt_lottable04, 112) + N''' ' + @c_LocTypeCriteria
                                   + N' ORDER BY PickDetail.PickDetailKey '

            EXEC (@c_ExecStatement)
            OPEN C_PickDetailKey

            FETCH NEXT FROM C_PickDetailKey
            INTO @c_Pickdetailkey
               , @c_Orderlinenumber

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (  SELECT 1
                                FROM RefKeyLookup WITH (NOLOCK)
                                WHERE PickDetailkey = @c_Pickdetailkey)
               BEGIN
                  INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                  VALUES (@c_Pickdetailkey, @c_Pickslipno, @c_Orderkey, @c_Orderlinenumber, @c_Loadkey)

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63503
                     SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                                        + N': Insert RefKeyLookup Failed. (isp_GetPickSummary01)'
                     GOTO FAILURE
                  END
               END

               FETCH NEXT FROM C_PickDetailKey
               INTO @c_Pickdetailkey
                  , @c_Orderlinenumber
            END
            CLOSE C_PickDetailKey
            DEALLOCATE C_PickDetailKey
         END

         UPDATE #TEMP_GETPICKSUMM01
         SET PickSlipNo = @c_Pickslipno
         WHERE OrderKey = @c_Orderkey
         AND   LoadKey = @c_Loadkey
         AND   LocationTypeDesc = @c_LocTypeDesc
         AND   putawayzone = @c_putawayzone
         AND   SKU = @c_sku
         AND   LOC = @c_loc
         AND   ID = @c_id
         AND   (PickSlipNo IS NULL OR PickSlipNo = '')

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63504
            SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                               + N': Update #TEMP_GETPICKSUMM01 Failed. (isp_GetPickSummary01)'
            GOTO FAILURE
         END

         SET @c_PrevLoadkey = @c_Loadkey
         SET @c_PrevOrderkey = @c_Orderkey
         SET @c_PrevLocTypeDesc = @c_LocTypeDesc
         SET @c_PrevPutawayzone = @c_putawayzone

         FETCH NEXT FROM C_Orderkey_LocTypeDesc
         INTO @c_Loadkey
            , @c_Orderkey
            , @c_LocTypeDesc
            , @c_putawayzone
            , @c_sku
            , @c_loc
            , @c_id
            , @c_lottable01
            , @c_lottable02
            , @dt_lottable04
            , @c_NOSPLITBYLINECNTZONE

      END -- while 1   

      CLOSE C_Orderkey_LocTypeDesc
      DEALLOCATE C_Orderkey_LocTypeDesc

      GOTO SUCCESS
      FAILURE:
      DELETE FROM #TEMP_GETPICKSUMM01
      IF CURSOR_STATUS('LOCAL', 'C_Orderkey_LocTypeDesc') IN ( 0, 1 )
      BEGIN
         CLOSE C_Orderkey_LocTypeDesc
         DEALLOCATE C_Orderkey_LocTypeDesc
      END

      IF CURSOR_STATUS('GLOBAL', 'C_PickDetailKey') IN ( 0, 1 )
      BEGIN
         CLOSE C_PickDetailKey
         DEALLOCATE C_PickDetailKey
      END

      SUCCESS:
      IF ISNULL(@c_PreGenRptData, '') = ''
      BEGIN
         CREATE TABLE #temp_picksumm01
         (
            ID             INT          IDENTITY(1, 1)
          , LoadKey        NVARCHAR(10)
          , C_Company      NVARCHAR(45) NULL
          , Storerkey      NVARCHAR(20)
          , Consigneekey   NVARCHAR(20) DEFAULT ('')
          , Facility       NVARCHAR(5)  DEFAULT ('')
          , CustName       NVARCHAR(50) DEFAULT ('')
          , LPExternOrdKey NVARCHAR(30) DEFAULT ('')
          , C_city         NVARCHAR(45) DEFAULT ('')
          , PHKey          NVARCHAR(18) DEFAULT ('')
          , LocType        NVARCHAR(30) DEFAULT ('')
         )


         CREATE TABLE #temp_picksumm01OTH
         (
            ID             INT          IDENTITY(1, 1)
          , LoadKey        NVARCHAR(10)
          , C_Company      NVARCHAR(45) NULL
          , Storerkey      NVARCHAR(20)
          , Consigneekey   NVARCHAR(20) DEFAULT ('')
          , Facility       NVARCHAR(5)  DEFAULT ('')
          , CustName       NVARCHAR(50) DEFAULT ('')
          , LPExternOrdKey NVARCHAR(30) DEFAULT ('')
          , C_city         NVARCHAR(45) DEFAULT ('')
          , PHKey          NVARCHAR(18) DEFAULT ('')
          , LocType        NVARCHAR(30) DEFAULT ('')
         )

         INSERT INTO #temp_picksumm01 (LoadKey, C_Company, Storerkey, Consigneekey, Facility, CustName, LPExternOrdKey
                                     , C_city, PHKey, LocType)
         SELECT DISTINCT LoadKey
                       , Company
                       , Storerkey
                       , ConsigneeKey
                       , Facility
                       , CustName
                       , externorderkey
                       , City
                       , PickSlipNo
                       , LocationTypeDesc
         FROM #TEMP_GETPICKSUMM01
         WHERE LocationTypeDesc = 'EACH PICKING LIST'
         ORDER BY LocationTypeDesc
                , PickSlipNo DESC

         INSERT INTO #temp_picksumm01OTH (LoadKey, C_Company, Storerkey, Consigneekey, Facility, CustName
                                        , LPExternOrdKey, C_city, PHKey, LocType)
         SELECT DISTINCT LoadKey
                       , Company
                       , Storerkey
                       , ConsigneeKey
                       , Facility
                       , CustName
                       , externorderkey
                       , City
                       , PickSlipNo
                       , LocationTypeDesc
         FROM #TEMP_GETPICKSUMM01
         WHERE LocationTypeDesc = 'PALLET PICKING LIST'
         GROUP BY LoadKey
                , Company
                , Storerkey
                , ConsigneeKey
                , Facility
                , CustName
                , externorderkey
                , City
                , PickSlipNo
                , LocationTypeDesc
         ORDER BY LocationTypeDesc
                , PickSlipNo DESC

         SELECT DISTINCT CASE WHEN ISNULL(T01.LoadKey, '') <> '' THEN T01.LoadKey
                              ELSE OTHT01.LoadKey END AS loadkey
                       , T01.C_Company AS c_company
                       , T01.Storerkey AS storerkey
                       , T01.Consigneekey AS consigneekey
                       , T01.Facility AS Facility
                       , T01.CustName AS Custname
                       , T01.LPExternOrdKey AS LPExternOrdkey
                       , T01.C_city AS C_city
                       , T01.PHKey AS PHKey
                       , T01.LocType AS Loctype
                       , OTHT01.C_Company AS OTH_C_company
                       , OTHT01.Consigneekey AS OTH_Consigneekey
                       , OTHT01.CustName AS OTH_CustName
                       , OTHT01.LPExternOrdKey AS OTH_LPExternOrdKey
                       , OTHT01.C_city AS OTH_C_City
                       , OTHT01.PHKey AS OTH_PHKEY
                       , OTHT01.LocType AS OTH_Loctype
         FROM #temp_picksumm01 T01
         FULL OUTER JOIN #temp_picksumm01OTH OTHT01 ON OTHT01.ID = T01.ID

         IF OBJECT_ID('tempdb..#temp_picksumm01') IS NOT NULL
            DROP TABLE #temp_picksumm01

         IF OBJECT_ID('tempdb..#temp_picksumm01OTH') IS NOT NULL
            DROP TABLE #temp_picksumm01OTH

         IF OBJECT_ID('tempdb..#TEMP_GETPICKSUMM01') IS NOT NULL
            DROP TABLE #TEMP_GETPICKSUMM01
      END
   END --@n_continue = 1 or 2
   QUIT_SP:
END

GO