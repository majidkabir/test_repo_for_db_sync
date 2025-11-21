SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nspPiecePickSlip_size_01                            */
/* Creation Date: 2022-09-05                                            */
/* Copyright: IDS                                                       */
/* Written by: MINGLE (copy from  nspPiecePickSlip_size_01)             */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: r_dw_piecepickslip_byload_size_01 (WMS-20678)             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version:                                                             */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver Purposes                                     */
/* 05-Sep-2022 Mingle  1.0 Created.(DevOps Combine Script)              */
/* 29-Mar-2023 WLChooi 1.1 WMS-22112 - Add new columns (WL01)           */
/************************************************************************/

CREATE   PROC [dbo].[nspPiecePickSlip_size_01] (
   @c_LoadKey  NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_OrderKey      NVARCHAR(10),
            @c_PickHeaderKey NVARCHAR(10),
            @n_row           INT,
            @n_err           INT,
            @n_continue      INT,
            @b_success       INT,
            @c_errmsg        NVARCHAR(255),
            @n_StartTranCnt  INT,
            @c_Storerkey     NVARCHAR(15),
            @c_Facility      NVARCHAR(5),
            @c_Authority     NVARCHAR(10)

   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   DECLARE @c_PostAllocationProcessSP NVARCHAR(10),
           @c_Execute                 NVARCHAR(1000)

   --WL01 S
   SELECT TOP 1
      @c_Storerkey = Storerkey,
      @c_Facility  = Facility
   FROM LoadPlanDetail LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK)ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.Loadkey = @c_Loadkey
   --WL01 E

   SET @b_Success = 1
   SELECT @c_PostAllocationProcessSP = SValue
   FROM StorerConfig WITH (NOLOCK)
   WHERE ConfigKey = 'PostAllocationProcess'
   AND StorerKey = @c_Storerkey
   IF ISNULL(RTRIM(@c_PostAllocationProcessSP),'') <> ''
   BEGIN
      SET @c_Execute = N'EXEC ' + @c_PostAllocationProcessSP +
         N' @c_LoadKey=@c_LoadKey, @b_Success=@b_success OUTPUT, ' +
         N' @n_ErrNo = @n_err OUTPUT, @c_ErrMsg = @c_errmsg OUTPUT, @b_Debug =0 '

      EXEC sp_ExecuteSQL @c_Execute,
         N'@c_LoadKey NVARCHAR(10), @b_Success INT OUTPUT, @n_err INT OUTPUT, @c_errmsg NVARCHAR(215) OUTPUT',
         @c_Loadkey, @b_Success, @n_err, @c_errmsg

   END
   IF @b_Success = 1
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END
   ELSE
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63502 
      SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + '-' + @c_errmsg + '. (' + @c_PostAllocationProcessSP + + ')'
   END


   SELECT Storerkey,
          SortByExtOrdKey  = ISNULL(MAX(CASE WHEN Code = 'SortByExtORDKey'  THEN 1 ELSE 0 END),0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Long      = 'r_dw_piecepickslip_byload_size_01'
   AND (Short IS NULL OR Short <> 'N')
   GROUP BY Storerkey

   -- discrete pick slip i.e. one pick slip no for each orderkey in one loadkey
   -- default '3' to  PickHeader.Zone
   -- remove location type = 'pick'
   -- Sort by loadkey, SOStatus desc,logical loc, loc, sku
   -- page break by loadkey, orderkey


   DECLARE PickSlip_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --WL01 S
      SELECT OH.Orderkey
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
      JOIN PICKDETAIL PD WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey
      WHERE PD.Status < '5'
      AND LPD.Loadkey = @c_loadkey
      AND PD.Qty > 0
      ORDER BY OH.SOStatus DESC
      --WL01 E

   OPEN PickSlip_CUR
   FETCH NEXT FROM PickSlip_CUR INTO @c_OrderKey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
   -- End : June01
      SELECT @c_PickHeaderKey = ''

      IF NOT EXISTS( SELECT 1 FROM PickHeader WITH (NOLOCK)
                     WHERE ExternOrderKey = @c_LoadKey AND  Orderkey = @c_OrderKey AND  Zone = '3' )
      BEGIN
         BEGIN TRAN

         SELECT @b_success = 0
         EXECUTE nspg_GetKey
               'PICKSLIP',
               9,
               @c_PickHeaderKey OUTPUT,
               @b_success       OUTPUT,
               @n_err           OUTPUT,
               @c_errmsg        OUTPUT

         IF @b_success <> 1
         BEGIN
            ROLLBACK TRAN
            SELECT @n_continue = 3
            SELECT @n_err = 63500 
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Get PICKSLIP number failed. (nspPiecePickSlip_size_01)'
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

            INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, Orderkey, Zone)
            VALUES (@c_PickHeaderKey, @c_LoadKey, @c_OrderKey, '3')

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN
               SELECT @n_continue = 3
               SELECT @n_err = 63501
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into PICKHEADER Failed. (nspPiecePickSlip_size_01)'
            END
         END -- @n_continue = 1 or @n_continue = 2
         COMMIT TRAN
      END

      FETCH NEXT FROM PickSlip_CUR INTO @c_OrderKey 
   END -- While
   CLOSE PickSlip_CUR
   DEALLOCATE PickSlip_CUR

   -- If sp call from rdt then no need return result else
   -- will return java error 
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT = 1
      GOTO Quit

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        --WL01 S
        SELECT @c_Storerkey = MAX(Storerkey),
               @c_Facility = MAX(Facility)
        FROM LoadPlanDetail LPD (NOLOCK)
        JOIN ORDERS OH (NOLOCK)ON OH.OrderKey = LPD.OrderKey
        WHERE LPD.Loadkey = @c_Loadkey
        --WL01 E

        SELECT @b_success = 0
        BEGIN TRAN
        EXECUTE nspGetRight
        @c_Facility,         -- facility
        @c_StorerKey,        -- Storerkey
        NULL,                -- Sku
        'VFCNSKU',    -- Configkey
        @b_Success        OUTPUT,
        @c_Authority      OUTPUT,
        @n_err            OUTPUT,
        @c_ErrMsg         OUTPUT

        COMMIT TRAN

      WHILE @@TRANCOUNT < @n_StartTranCnt
      BEGIN
         BEGIN TRAN
      END

      SELECT ORDERS.Orderkey, ORDERS.Loadkey,
             SUM(CASE WHEN PACK.Casecnt > 0 THEN FLOOR(PICKDETAIL.Qty / PACK.Casecnt)
                 ELSE 0 END) AS totalordctn,
             SUM(CASE WHEN PACK.Casecnt > 0 THEN PICKDETAIL.Qty % CAST(PACK.Casecnt AS INT)
                 ELSE PICKDETAIL.Qty END) AS totalordpcs
      INTO #TMP_ORDQTYSUM
      FROM LOADPLANDETAIL (NOLOCK)   --WL01
      JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)   --WL01
      JOIN PICKDETAIL (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey   --WL01
      AND PICKDETAIL.Status < '5'
      GROUP BY ORDERS.Orderkey, ORDERS.Loadkey

      IF @c_authority = '1'
      BEGIN
          SELECT LOADPLAN.LoadKey,
                PICKHeader.PickHeaderKey,
                ORDERS.STORERKEY,
                ORDERS.ORDERKEY,
                ORDERS.SOSTATUS,
                ORDERS.EXTERNORDERKEY,
                LoadPlan.Route,
                LoadPlan.AddDate,
                SUM(ORDERDETAIL.Originalqty) AS TotalQtyOrdered,
                SUM(ORDERDETAIL.Qtyallocated) AS TotalQtyInBulk,
                RTRIM(ORDERS.type) + RTRIM(ISNULL(CODELKUP.UDF01,'')) AS ordertype,
                'Y' AS Config,
                #TMP_ORDQTYSUM.Totalordctn,
                #TMP_ORDQTYSUM.Totalordpcs
                ,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0)  AS SortByExtOrdKey 
                ,ORDERS.CONSIGNEEKEY
                --WL01 S
                ,CASE ORDERS.[Priority] WHEN '10' THEN N'内部订单'
                                        WHEN '40' THEN N'批发'
                                        WHEN '50' THEN N'零售'
                                        ELSE '' END AS Channel
                ,ISNULL(ORDERS.UserDefine02,'') AS Remarks
                --WL01 E
         FROM LOADPLAN WITH (NOLOCK)
         JOIN LOADPLANDETAIL WITH (NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey )
         JOIN ORDERS WITH (NOLOCK) ON ( LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND  LOADPLANDETAIL.Loadkey = ORDERS.Loadkey )
         JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
         JOIN PICKHEADER WITH (NOLOCK) ON ( PICKHEADER.ExternOrderKey = ORDERS.LoadKey AND Pickheader.Orderkey = ORDERS.Orderkey )
         LEFT JOIN CODELKUP WITH (NOLOCK) ON ( ORDERS.Type = CODELKUP.Code AND CODELKUP.Listname = 'ORDERTYPE' )
         JOIN #TMP_ORDQTYSUM ON ( ORDERS.Orderkey = #TMP_ORDQTYSUM.Orderkey )
         LEFT JOIN #TMP_RPTCFG WITH (NOLOCK) ON #TMP_RPTCFG.storerkey = ORDERS.StorerKey           
         WHERE LOADPLAN.LoadKey = @c_Loadkey
         AND   ORDERDETAIL.QtyAllocated > 0
         AND   PICKHeader.Zone = '3'
         GROUP BY LOADPLAN.LoadKey,
                  PICKHeader.PickHeaderKey,
                  ORDERS.STORERKEY,
                  ORDERS.ORDERKEY,
                  ORDERS.SOSTATUS,
                  ORDERS.EXTERNORDERKEY,
                  LoadPlan.Route,
                  LoadPlan.AddDate,
                  RTRIM(ORDERS.type) + RTRIM(ISNULL(CODELKUP.UDF01,'')),
                  #TMP_ORDQTYSUM.Totalordctn,
                  #TMP_ORDQTYSUM.Totalordpcs ,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0),
                  ORDERS.CONSIGNEEKEY
                  --WL01 S
                  ,CASE ORDERS.[Priority] WHEN '10' THEN N'内部订单'
                                          WHEN '40' THEN N'批发'
                                          WHEN '50' THEN N'零售'
                                          ELSE '' END
                  ,ISNULL(ORDERS.UserDefine02,'')
                  --WL01 E
         ORDER BY CASE WHEN ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0) = '1' THEN ORDERS.EXTERNORDERKEY ELSE '' END ASC,    
         LOADPLAN.LoadKey ASC, ORDERS.SOSTATUS DESC, ORDERS.ORDERKEY ASC
      END
      ELSE
      BEGIN

         SELECT LOADPLAN.LoadKey,
                PICKHeader.PickHeaderKey,
                ORDERS.STORERKEY,
                ORDERS.ORDERKEY,
                ORDERS.SOSTATUS,
                ORDERS.EXTERNORDERKEY,
                LoadPlan.Route,
                LoadPlan.AddDate,
                OD.TotalQtyOrdered,
                PD.TotalQtyInBulk,
                ORDERS.Type,
                'N' AS Config,
                #TMP_ORDQTYSUM.Totalordctn,
                #TMP_ORDQTYSUM.Totalordpcs
                ,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0)  AS SortByExtOrdKey
                ,ORDERS.CONSIGNEEKEY
                --WL01 S
                ,CASE ORDERS.[Priority] WHEN '10' THEN N'内部订单'
                                        WHEN '40' THEN N'批发'
                                        WHEN '50' THEN N'零售'
                                        ELSE '' END AS Channel
                ,ISNULL(ORDERS.UserDefine02,'') AS Remarks
                --WL01 E
         FROM LOADPLAN WITH (NOLOCK)
         JOIN LOADPLANDETAIL WITH (NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey )
         JOIN ORDERS WITH (NOLOCK) ON ( LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND  LOADPLANDETAIL.Loadkey = ORDERS.Loadkey )
         JOIN PICKDETAIL WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey )
         JOIN PICKHEADER WITH (NOLOCK) ON ( PICKHEADER.ExternOrderKey = ORDERS.LoadKey AND Pickheader.Orderkey = ORDERS.Orderkey )
         JOIN ( SELECT Loadkey, SUM(ISNULL(OpenQty,0)) TotalQtyOrdered
                    FROM ORDERDETAIL WITH (NOLOCK)
                    GROUP BY Loadkey ) OD ON (OD.LoadKey = LOADPLAN.Loadkey)
         LEFT OUTER JOIN ( SELECT Loadkey, SUM(ISNULL(PD.Qty,0)) TotalQtyInBulk
                             FROM LOADPLANDETAIL LPD WITH (NOLOCK)
                             JOIN PICKDETAIL  PD WITH (NOLOCK) ON PD.Orderkey = LPD.Orderkey
                             GROUP BY Loadkey ) PD ON (PD.Loadkey = LOADPLAN.Loadkey)
         JOIN #TMP_ORDQTYSUM ON ( ORDERS.Orderkey = #TMP_ORDQTYSUM.Orderkey )
         LEFT JOIN #TMP_RPTCFG WITH (NOLOCK) ON #TMP_RPTCFG.storerkey = ORDERS.StorerKey           
         WHERE LOADPLAN.LoadKey = @c_Loadkey
         AND   PICKDETAIL.STATUS < '5'
         AND   PICKHeader.Zone = '3'
         GROUP BY LOADPLAN.LoadKey,
                  PICKHeader.PickHeaderKey,
                  ORDERS.STORERKEY,
                  ORDERS.ORDERKEY,
                  ORDERS.SOSTATUS,
                  ORDERS.EXTERNORDERKEY,
                  LoadPlan.Route,
                  LoadPlan.AddDate,
                  OD.TotalQtyOrdered,
                  PD.TotalQtyInBulk,
                  ORDERS.Type,
                  #TMP_ORDQTYSUM.Totalordctn,
                  #TMP_ORDQTYSUM.Totalordpcs,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0),
                  ORDERS.CONSIGNEEKEY
                  --WL01 S
                  ,CASE ORDERS.[Priority] WHEN '10' THEN N'内部订单'
                                          WHEN '40' THEN N'批发'
                                          WHEN '50' THEN N'零售'
                                          ELSE '' END
                  ,ISNULL(ORDERS.UserDefine02,'')
                  --WL01 E
         ORDER BY CASE WHEN ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0) = '1' THEN ORDERS.EXTERNORDERKEY ELSE '' END ASC,  
         LOADPLAN.LoadKey ASC, ORDERS.SOSTATUS DESC, ORDERS.ORDERKEY ASC
      END
   END -- @n_continue = 1 or @n_continue = 2

   Quit:
END /* main procedure */

GO