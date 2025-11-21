SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nspConsoPickList22                                  */
/* Creation Date: 13-Aug-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Unilevel Consolidated PickSlip (print from LoadPlan)        */
/*          (refer to nspConsoPickList22)                               */
/* Input Parameters: @as_LoadKey - (LoadKey)                            */
/*                                                                      */
/* Called By: r_dw_consolidated_pick22                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver. Purposes                                    */
/*                                                                      */
/* 30-Nov-2009 NJOW01  1.1  SOS154094 - Add lottable02 as batch         */
/* 03-Jan-2011 NJOW02  1.2  200847 - Add Pickzone                       */
/* 21-Mac-2011 AQSKC   1.3  210516 - Unique PSNO per LocationDescType   */
/*                          (KC01)                                      */
/* 19-Jul-2011 NJOW03  1.4  221140-Unilever consolidate pickslip page   */
/*                          break by pick zone include each             */
/* 04-Jan-2013 NJOW04  1.5  262698 - Unique pickslipno on each page     */
/* 08-Sep-2016 CSCHONG 1.6  Request by MY LIT for test (CS01/CCS01)     */
/* 27-Mar-2017 NJOW05  1.7  WMS-1445 Configure no split by line count   */
/*                          and PA zone                                 */
/* 16-Jul-2020 WLChooi 1.8  WMS-14236 - Add ReportCFG to show bigger    */
/*                          font (WL01)                                 */
/* 29-Jul-2020 WLChooi 1.9  WMS-14236 Fix show UPPER(LOC) (WL02)        */
/* 10-Feb-2021 WLChooi 2.0  WMS-16170 Group same SKU+LOC in one page one*/
/*                          pickslip (WL03)                             */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList22] (@as_LoadKey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_starttrancnt  INT,
      @n_continue      INT,
      @b_success       INT,
      @n_err           INT,
      @c_errmsg        NVARCHAR(255)

   DECLARE
      @c_PrintedFlag   NVARCHAR(1),
      --@c_PickHeaderKey NVARCHAR(10),
      @c_LocTypeDesc           NVARCHAR(20),      --(Kc01)
      @c_Pickdetailkey         NVARCHAR(10),      --(Kc01)
      @c_PrevLoadkey           NVARCHAR(10),      --(Kc01)
      @c_PrevLocTypeDesc       NVARCHAR(20),      --(KC01)
      @c_Pickslipno            NVARCHAR(10),      --(Kc01)
      @c_Orderkey              NVARCHAR(10),      --(Kc01)
      @c_Orderlinenumber       NVARCHAR(5),       --(Kc01)
      @c_LocTypeCriteria       NVARCHAR(255),     --(Kc01)
      @c_ExecStatement         NVARCHAR(4000),     --(Kc01)
      @c_putawayzone           NVARCHAR(10), --NJOW04
      @c_PrevPutawayzone       NVARCHAR(10), --NJOW04
      @n_Linecount             INT, --NJOW04
      @c_sku                   NVARCHAR(20), --NJOW04
      @c_loc                   NVARCHAR(10), --NJOW04
      @c_id                    NVARCHAR(18), --NJOW04
      @c_lottable01            NVARCHAR(18), --NJOW04
      @c_lottable02            NVARCHAR(18), --NJOW04
      @dt_lottable04           DATETIME,     --NJOW04
      @c_LogicalLoc            NVARCHAR(18),  --(CCS01)
      @c_NOSPLITBYLINECNTZONE  NVARCHAR(10), --NJOW05
      @n_Count                 INT = 0,      --WL03
      @c_GroupSameSKULOC       NVARCHAR(1) = 'N',   --WL03
      @c_PrevSKU               NVARCHAR(20) = '',   --WL03
      @c_PrevLOC               NVARCHAR(10) = ''    --WL03

   SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1

   /********************************/
   /* Use Zone as a UOM Picked     */
   /* 1 = Pallet                   */
   /* 2 = Case                     */
   /* 6 = Each                     */
   /* 7 = Consolidated pick list   */
   /* 8 = By Order                 */
   /********************************/

   --(Kc01) - start
   /*
   SELECT @c_PickHeaderKey = SPACE(10)

   IF NOT EXISTS (SELECT PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE ExternOrderKey = @as_LoadKey AND Zone = '7')
   BEGIN
      SELECT @c_PrintedFlag = 'N'

      SELECT @b_success = 0

      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,
         @c_PickHeaderKey  OUTPUT,
         @b_success        OUTPUT,
         @n_err            OUTPUT,
         @c_errmsg         OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

         INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
         VALUES (@c_PickHeaderKey, @as_LoadKey, '1', '7')

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63501
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList22)'
         END
      END -- @n_continue = 1 or @n_continue = 2
   END
   ELSE
   BEGIN
      SELECT @c_PrintedFlag = 'Y'

      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM  PICKHEADER (NOLOCK)
      WHERE ExternOrderKey = @as_LoadKey
       AND  Zone = '7'
   END

   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = ''
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63502
      SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get LoadKey Failed. (nspConsoPickList22)'
   END
   */
   --(Kc01) - end

   --(Kc01) - start
   --check if the loadplan already printed other pickslip type then return error to reject.
   IF EXISTS (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
          WHERE ExternOrderKey = @as_LoadKey
          AND ISNULL(RTRIM(OrderKey),'') <> ''
          AND ZONE = 'LP')
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500
      SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Pickslip already printed using Discrete option. (nspConsoPickList22)'
   END
   --(Kc01) - end

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      CREATE TABLE #TEMP_PICK
      (PickSlipNo       NVARCHAR(10) NULL,
       LoadKey          NVARCHAR(10) NULL,
       LOC              NVARCHAR(10) NULL,
       ID               NVARCHAR(18) NULL,
       SKU              NVARCHAR(20) NULL,
       AltSKU           NVARCHAR(20) NULL,
       SkuDesc          NVARCHAR(60) NULL,
       Qty              INT,
       PrintedFlag      NVARCHAR(1)  NULL,
       LocationTypeDesc NVARCHAR(20) NULL,
       Lottable01       NVARCHAR(18) NULL,
       Lottable02       NVARCHAR(18) NULL, --NJOW01
       Lottable04       DATETIME NULL,
       LogicalLoc       NVARCHAR(18) NULL,
       Shelflife        INT,
       MinShelfLife     INT,
       pallet           INT,
       casecnt          INT,
       pickafterdate    DATETIME NULL,
       putawayzone      NVARCHAR(10) NULL,
       c_company        NVARCHAR(45) NULL,
       c_address1       NVARCHAR(45) NULL,
       c_address2       NVARCHAR(45) NULL,
       c_address3       NVARCHAR(45) NULL,
       c_address4       NVARCHAR(45) NULL,
       c_city           NVARCHAR(45) NULL,
       c_state          NVARCHAR(45) NULL,
       c_zip            NVARCHAR(18) NULL,
       c_country        NVARCHAR(30) NULL,
       Storerkey        NVARCHAR(15) NULL,   --NJOW02 NJOW05
       ShowBiggerFont   NVARCHAR(10) NULL)   --WL01

       INSERT INTO #TEMP_PICK
            (PickSlipNo,          LoadKey,         Loc,         ID,
             SKU,                 AltSKU,          SkuDesc,       Qty,
             PrintedFlag,         Locationtypedesc, Lottable01, Lottable02,   Lottable04,
             LogicalLoc,         Shelflife,        Minshelflife,
             pallet,             casecnt,          pickafterdate, putawayzone,
             c_company,          c_address1,       c_address2,    c_address3,       c_address4,
             c_city,             c_state,          c_zip,         c_country,	Storerkey, ShowBiggerFont )   --WL01
        --(Kc01) - start
        /*
        SELECT (SELECT PICKHEADERKEY FROM PICKHEADER WITH (NOLOCK)
                WHERE ExternOrderKey = @as_LoadKey
                AND ZONE = '7'),
        */
        SELECT RefKeyLookup.PickSlipNo,
        --(Kc01) - end
           @as_LoadKey as LoadKey,
           CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN UPPER(PickDetail.loc) ELSE PickDetail.loc END,   --WL02
           PickDetail.id,
           PickDetail.sku,
           Sku.Altsku,
           Sku.Descr,
           SUM(PickDetail.qty),
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE PickHeaderkey = RefKeyLookup.PickSlipNo
                     AND ExternOrderkey = @as_Loadkey AND  Zone = 'LP') , 'N') AS PrintedFlag,                                                      --(Kc01)
           --ISNULL((SELECT Distinct 'Y' FROM PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @as_Loadkey AND  Zone = '7'), 'N') AS PrintedFlag,   --(Kc01)
           CASE WHEN LOC.Locationtype = 'OTHER' THEN
                'PALLET PICKING LIST'
                ELSE 'EACH PICKING LIST'
           END,
           LotAttribute.Lottable01,
           LotAttribute.Lottable02, --NJOW01
           IsNUll(LotAttribute.Lottable04, '19000101'),
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
           CASE WHEN LEN(LTRIM(LotAttribute.Lottable01)) = 8 THEN
                CASE WHEN ISDATE(SUBSTRING(LTRIM(LotAttribute.Lottable01),5,4)+SUBSTRING(LTRIM(LotAttribute.Lottable01),3,2)+SUBSTRING(LTRIM(LotAttribute.Lottable01),1,2)) = 1 THEN
                    CONVERT(DATETIME,SUBSTRING(LTRIM(LotAttribute.Lottable01),5,4)+SUBSTRING(LTRIM(LotAttribute.Lottable01),3,2)+SUBSTRING(LTRIM(LotAttribute.Lottable01),1,2)) + SKU.Shelflife - STORER.Minshelflife
                ELSE
                    '19000101'
                END
           ELSE
               '19000101'
           END,
           LOC.PickZone,
           MAX(ISNULL(ORDERS.c_company,'')),
           MAX(ISNULL(ORDERS.c_address1,'')),
           MAX(ISNULL(ORDERS.c_address2,'')),
           MAX(ISNULL(ORDERS.c_address3,'')),
           MAX(ISNULL(ORDERS.c_address4,'')),
           MAX(ISNULL(ORDERS.c_city,'')),
           MAX(ISNULL(ORDERS.c_state,'')),
           MAX(ISNULL(ORDERS.c_zip,'')),
           MAX(ISNULL(ORDERS.c_country,'')),
           SKU.Storerkey, --NJOW05
           ISNULL(CL.Short,'N') AS ShowBiggerFont   --WL01
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
         JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
         JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = PICKDETAIL.Orderkey
                           AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
         JOIN STORER WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
         JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey
                           AND ORDERDETAIL.Sku = SKU.Sku
         JOIN PACK WITH (NOLOCK) ON Sku.Packkey = PACK.Packkey
         JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc
         LEFT OUTER JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)      --(KC01)
         LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Code = 'ShowBiggerFont' 
                                       AND CL.Long = 'r_dw_consolidated_pick22' AND CL.Storerkey = ORDERS.Storerkey   --WL01
        WHERE PICKDETAIL.Status < '5'
        AND LOADPLANDETAIL.LoadKey = @as_LoadKey
        GROUP BY RefKeyLookup.PickSlipNo,          --(Kc01)
           CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN UPPER(PickDetail.loc) ELSE PickDetail.loc END,   --WL02
           PickDetail.id,
           PickDetail.sku,
           Sku.Altsku,
           Sku.Descr,
           CASE WHEN Loc.Locationtype = 'OTHER' THEN
                'PALLET PICKING LIST'
                ELSE 'EACH PICKING LIST'
           END,
           LotAttribute.Lottable01,
           LotAttribute.Lottable02, --NJOW01
           IsNUll(LotAttribute.Lottable04, '19000101'),
           LOC.LogicalLocation,
           SKU.Shelflife,
           STORER.Minshelflife,
           PACK.Pallet,
           PACK.CaseCnt,
           LOC.PickZone,
           SKU.Storerkey, --NJOW05
           ISNULL(CL.Short,'N')   --WL01

      --(Kc01) - start
      -- Uses PickType as a Printed Flag
      UPDATE PickHeader WITH (ROWLOCK) SET PickType = '1', TrafficCop = NULL
      WHERE ExternOrderKey = @as_LoadKey
      AND Zone = 'LP'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63501
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PICKHEADER Failed. (nspConsoPickList22)'
         GOTO FAILURE
      END

      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SET @as_LoadKey = ''
         SET @c_PickDetailKey = ''
         SET @n_Continue = 1
         SET @c_Putawayzone = '' --NJOW04
         SET @n_Linecount = 0 --NJOW04

         DECLARE C_Loadkey_LocTypeDesc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TP.LoadKey, TP.LocationTypeDesc,
                TP.Putawayzone, TP.sku, TP.loc, TP.id, TP.lottable01, TP.lottable02, TP.lottable04 --NJOW04
               ,TP.LogicalLoc                                                    --CCS01
               ,CASE WHEN CLR.Code IS NOT NULL THEN 'Y' ELSE 'N' END AS NOSPLITBYLINECNTZONE --NJOW05
               ,ISNULL(CL1.Short,'N') AS GroupSameSKULOC --WL03
         FROM   #TEMP_PICK TP
         LEFT JOIN CODELKUP CLR (NOLOCK) ON (TP.Storerkey = CLR.Storerkey AND CLR.Code = 'NOSPLITBYLINECNTZONE' 
                                             AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_consolidated_pick22' AND ISNULL(CLR.Short,'') <> 'N') --NJOW05                                 
         LEFT JOIN CODELKUP CL1 (NOLOCK) ON (TP.Storerkey = CL1.Storerkey AND CL1.Code = 'GroupSameSKULOC' 
                                             AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'r_dw_consolidated_pick22' AND ISNULL(CL1.Short,'') <> 'N') --NJOW05
         WHERE  TP.PickSlipNo IS NULL or TP.PickSlipNo = ''
         ORDER BY TP.LoadKey, TP.LocationTypeDesc,
                  TP.Putawayzone, TP.logicalloc, TP.loc, TP.sku, TP.id --NJOW04 --CS01

         OPEN C_Loadkey_LocTypeDesc

         FETCH NEXT FROM C_Loadkey_LocTypeDesc INTO @as_LoadKey, @c_LocTypeDesc,
                                                    @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04 --NJOW04
                                                   ,@c_LogicalLoc                 --CCS01
                                                   ,@c_NOSPLITBYLINECNTZONE --NJOW05
                                                   ,@c_GroupSameSKULOC   --WL03

         WHILE (@@Fetch_Status <> -1)
         BEGIN -- while 1

            SELECT @n_Linecount = @n_Linecount + 1 --NJOW04
            
            --WL03 S
            IF @c_GroupSameSKULOC = 'Y' AND @c_PrevSKU <> @c_SKU AND  @c_PrevLOC <> @c_loc
            BEGIN
               SELECT @n_Count = COUNT(1)
               FROM #TEMP_PICK TP
               WHERE TP.putawayzone = @c_Putawayzone AND TP.LocationTypeDesc = @c_LocTypeDesc 
               AND TP.SKU = @c_SKU AND TP.LOC = @c_LOC

               --SELECT @c_SKU, @c_LOC, @n_Count, @n_Linecount
            END
            --WL03 E

            IF @c_PrevLoadKey <> @as_LoadKey OR
               @c_PrevLocTypeDesc <> @c_LocTypeDesc OR
               (@c_PrevPutawayzone <> @c_Putawayzone AND @c_NOSPLITBYLINECNTZONE <> 'Y') OR  --NJOW04 NJOW05
               (@n_Linecount > 15 AND @c_NOSPLITBYLINECNTZONE <> 'Y') OR --NJOW04 NJOW05   --WL03
               (@n_Linecount + @n_Count > 15 AND @c_GroupSameSKULOC = 'Y')   --WL03
            BEGIN
               SET @c_PickSlipNo = ''
               SET @n_Linecount = 1 --NJOW04

               EXECUTE nspg_GetKey
                  'PICKSLIP',
                  9,
                  @c_PickSlipNo   OUTPUT,
                  @b_success      OUTPUT,
                  @n_err          OUTPUT,
                  @c_errmsg       OUTPUT

               IF @b_success = 1
               BEGIN
                  SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo
                  INSERT PICKHEADER (pickheaderkey, ExternOrderkey, Zone, PickType, Wavekey)
                             VALUES (@c_PickSlipNo, @as_LoadKey, 'LP', '0',  @c_PickSlipNo)

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63501
                     SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert into PICKHEADER Failed. (nspConsoPickList22)'
                     GOTO FAILURE
                  END
               END -- @b_success = 1
               ELSE
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63502
                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get PSNO Failed. (nspConsoPickList22)'
                  BREAK
               END
            END -- @c_PrevLoadKey <> @as_LoadKey OR  @c_PrevLocTypeDesc <> @c_LocTypeDesc

            IF @n_Continue = 1
            BEGIN
               SET @c_LocTypeCriteria = ''
               SET @c_ExecStatement = ''

               IF @c_LocTypeDesc = 'PALLET PICKING LIST'
               BEGIN
                  SET @c_LocTypeCriteria = 'AND LOC.LocationType = ''OTHER'''
               END
               ELSE
               BEGIN
                  SET @c_LocTypeCriteria = 'AND LOC.LocationType <> ''OTHER'''
               END

               SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                       'SELECT PickDetail.PickDetailKey, PickDetail.Orderkey, PickDetail.OrderLineNumber ' +
                                       'FROM   PickDetail WITH (NOLOCK) ' +
                                       'JOIN   OrderDetail WITH (NOLOCK) ' +
                                       'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' +
                                       'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +
                                       'JOIN   LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +
                                       'JOIN   LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) ' +  --NJOW04
                                       'WHERE  OrderDetail.LoadKey  = N''' + @as_LoadKey  + ''' ' +
                                       ' AND LOC.PickZone = N''' + RTRIM(@c_Putawayzone) + ''' ' +  --NJOW04
                                       ' AND Pickdetail.Sku = N''' + RTRIM(@c_Sku) + ''' ' +  --NJOW04
                                       ' AND Pickdetail.Loc = N''' + RTRIM(@c_Loc) + ''' ' +  --NJOW04
                                       ' AND Pickdetail.Id = N''' + RTRIM(@c_ID) + ''' ' +  --NJOW04
                                       ' AND Lotattribute.Lottable01 = N''' + RTRIM(@c_Lottable01) + ''' ' +  --NJOW04
                                       ' AND Lotattribute.Lottable02 = N''' + RTRIM(@c_Lottable02) + ''' ' +  --NJOW04
                                       ' AND CONVERT(CHAR(10),ISNULL(Lotattribute.Lottable04,''19000101''),112) = ''' + CONVERT(CHAR(10),@dt_Lottable04,112) + ''' ' +  --NJOW04
                                       @c_LocTypeCriteria +
                                       ' ORDER BY PickDetail.PickDetailKey '

               EXEC(@c_ExecStatement)
               OPEN C_PickDetailKey

               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_orderkey, @c_OrderLineNumber

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)
                  BEGIN
                     INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
                     VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @as_LoadKey)

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 63503
                        SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert RefKeyLookup Failed. (nspConsoPickList22)'
                        GOTO FAILURE
                     END
                  END

                  FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_orderkey, @c_OrderLineNumber
               END
               CLOSE C_PickDetailKey
               DEALLOCATE C_PickDetailKey
            END

            UPDATE #TEMP_PICK
               SET PickSlipNo = @c_PickSlipNo
            WHERE LoadKey = @as_LoadKey
            AND   LocationTypeDesc = @c_LocTypeDesc
            AND   Putawayzone = @c_Putawayzone --NJOW04
            AND   Sku = @c_Sku --NJOW04
            AND   Loc = @c_Loc --NJOW04
            AND   ID = @c_ID --NJOW04
            AND   Lottable01 = @c_Lottable01 --NJOW04
            AND   Lottable02 = @c_Lottable02 --NJOW04
            AND   Lottable04 = @dt_Lottable04 --NJOW04
            AND   (PickSlipNo IS NULL OR PickSlipNo = '')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63504
               SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update #Temp_Pick Failed. (nspConsoPickList22)'
               GOTO FAILURE
            END

            SET @c_PrevLoadKey = @as_LoadKey
            SET @c_PrevLocTypeDesc = @c_LocTypeDesc
            SET @c_PrevPutawayzone = @c_Putawayzone --NJOW04
            SET @c_PrevSKU = @c_sku   --WL03
            SET @c_PrevLOC = @c_loc   --WL03
            SET @n_Count = 0   --WL03

            FETCH NEXT FROM C_Loadkey_LocTypeDesc INTO @as_LoadKey, @c_LocTypeDesc,
                                                       @c_Putawayzone, @c_sku, @c_loc, @c_id, @c_lottable01, @c_lottable02, @dt_lottable04 --NJOW04
                                                      ,@c_LogicalLoc         --CCS01
                                                      ,@c_NOSPLITBYLINECNTZONE --NJOW05
                                                      ,@c_GroupSameSKULOC   --WL03
         END -- while 1

         CLOSE C_Loadkey_LocTypeDesc
         DEALLOCATE C_Loadkey_LocTypeDesc
         GOTO SUCCESS
      END --@n_continue = 1 or @n_continue = 2

 FAILURE:
     DELETE FROM #TEMP_PICK
     IF CURSOR_STATUS('LOCAL' , 'C_Loadkey_LocTypeDesc') in (0 , 1)
     BEGIN
        CLOSE C_Loadkey_LocTypeDesc
        DEALLOCATE C_Loadkey_LocTypeDesc
     END

     IF CURSOR_STATUS('GLOBAL' , 'C_PickDetailKey') in (0 , 1)
     BEGIN
        CLOSE C_PickDetailKey
        DEALLOCATE C_PickDetailKey
     END
      --(Kc01) - end

 SUCCESS:
      SELECT * FROM #TEMP_PICK ORDER BY Pickslipno
      DROP Table #TEMP_PICK

   END -- @n_continue = 1 or 2

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList22'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END /* main procedure */

GO