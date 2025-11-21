SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nspPiecePickSlip_size                               */
/* Creation Date: 2007-11-12                                            */
/* Copyright: IDS                                                       */
/* Written by: AQUASORA                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: r_dw_piecepickslip_byload_size (FBR 90107)                */
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
/* 30-Nov-2007 June    1.0 Bug fixes : June01                           */
/* 13-Jun-2012 Leong   1.1 SOS# 245168 - Add @n_err and @c_errmsg       */
/* 19-Jun-2012 NJOW01  1.2 247360-Picking slip report CR for CN VF Vans */
/* 22-Jun-2012 TLTING      SOS# 245168 - Commit TRan                    */ 
/* 07-Dec-2012 SHONG   1.4 #263231 Post Allocate Process                */
/* 07-Aug-2013 JAMES   1.5 SOS284891 - If call from RDT then no need    */
/*                         return result (james01)                      */
/* 17-MAY-2017 CSCHONG 1.6 WMS-1917-report config for sorting(CS01)     */
/* 24-May-2017 SPChin  1.7 IN00354703 - Bug Fixed                       */
/************************************************************************/

CREATE PROC [dbo].[nspPiecePickSlip_size] (
   @c_LoadKey  NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_OrderKey      NVARCHAR(10),
            @c_PickHeaderKey NVARCHAR(10),
            @n_row           Int,
            @n_err           Int,
            @n_continue      Int,
            @b_success       Int,
            @c_errmsg        NVARCHAR(255),
            @n_StartTranCnt  Int,
            @c_Storerkey     NVARCHAR(15),
            @c_Facility      NVARCHAR(5),
            @c_Authority     NVARCHAR(10)
            
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1

   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN

   DECLARE @c_PostAllocationProcessSP NVARCHAR(10), 
           @c_Execute                 NVARCHAR(1000)
   
   SELECT TOP 1 
      @c_Storerkey = Storerkey,  
      @c_Facility  = Facility  
   FROM ORDERS (NOLOCK)  
   WHERE Loadkey = @c_Loadkey 
   
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
      SELECT @n_err = 63502 -- SOS# 245168
      SELECT @c_errmsg = 'NSQL' + CONVERT(Char(5),@n_err) + '-' + @c_errmsg + '. (' + @c_PostAllocationProcessSP + + ')'                  
   END
   
   
    --(CS01) - START
   SELECT Storerkey,
          SortByExtOrdKey  = ISNULL(MAX(CASE WHEN Code = 'SortByExtORDKey'  THEN 1 ELSE 0 END),0)
   INTO #TMP_RPTCFG
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Long      = 'r_dw_piecepickslip_byload_size'
   AND (Short IS NULL OR Short <> 'N')
   GROUP BY Storerkey
   --(CS01) - END  
   -- discrete pick slip i.e. one pick slip no for each orderkey in one loadkey
   -- default '3' to  PickHeader.Zone
   -- remove location type = 'pick'
   -- Sort by loadkey, SOStatus desc,logical loc, loc, sku
   -- page break by loadkey, orderkey


   DECLARE PickSlip_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ORDERS.Orderkey
      FROM   PICKDETAIL PD WITH (NOLOCK)
      JOIN   ORDERS WITH (NOLOCK) ON ORDERS.Orderkey = PD.Orderkey
      WHERE  PD.Status      < '5'
      AND    ORDERS.Loadkey = @c_loadkey
      AND    PD.Qty > 0
      ORDER BY ORDERS.SOStatus DESC

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
            SELECT @n_err = 63500 -- SOS# 245168
            SELECT @c_errmsg = 'NSQL' + CONVERT(Char(5),@n_err) + ': Get PICKSLIP number failed. (nspPiecePickSlip_size)'            
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
               SELECT @c_errmsg = 'NSQL' + CONVERT(Char(5),@n_err) + ': Insert Into PICKHEADER Failed. (nspPiecePickSlip_size)'
            END
         END -- @n_continue = 1 or @n_continue = 2
         COMMIT TRAN         
      END

      FETCH NEXT FROM PickSlip_CUR INTO @c_OrderKey -- June01
   END -- While
   -- Start : June01
   CLOSE PickSlip_CUR
   DEALLOCATE PickSlip_CUR
   -- End : June01

   -- If sp call from rdt then no need return result else 
   -- will return java error (james01)
   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT = 1
      GOTO Quit
      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT @c_Storerkey = MAX(Storerkey),
   	         @c_Facility = MAX(Facility)
   	  FROM ORDERS (NOLOCK)
   	  WHERE Loadkey = @c_Loadkey
   	  
        SELECT @b_success = 0
        BEGIN TRAN
   	  Execute nspGetRight 
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
             SUM(CASE WHEN PACK.Casecnt > 0 THEN PICKDETAIL.Qty % CAST(PACK.Casecnt AS int) 
                 ELSE PICKDETAIL.Qty END) AS totalordpcs
      INTO #TMP_ORDQTYSUM
      FROM ORDERS (NOLOCK)
      JOIN PICKDETAIL (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
      JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
      JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE ORDERS.Loadkey = @c_Loadkey
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
                ,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0)  AS SortByExtOrdKey            --CS01          
         FROM LOADPLAN WITH (NOLOCK)
         JOIN LOADPLANDETAIL WITH (NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey )
         JOIN ORDERS WITH (NOLOCK) ON ( LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND  LOADPLANDETAIL.Loadkey = ORDERS.Loadkey )
         JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
         JOIN PICKHEADER WITH (NOLOCK) ON ( PICKHEADER.ExternOrderKey = ORDERS.LoadKey AND Pickheader.Orderkey = ORDERS.Orderkey )
         LEFT JOIN CODELKUP WITH (NOLOCK) ON ( ORDERS.Type = CODELKUP.Code AND CODELKUP.Listname = 'ORDERTYPE' )
         JOIN #TMP_ORDQTYSUM ON ( ORDERS.Orderkey = #TMP_ORDQTYSUM.Orderkey )
         LEFT JOIN #TMP_RPTCFG WITH (NOLOCK) ON #TMP_RPTCFG.storerkey = ORDERS.StorerKey           --CS01
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
                  #TMP_ORDQTYSUM.Totalordpcs ,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0)                                    --CS01         
         ORDER BY CASE WHEN ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0) = '1' THEN ORDERS.EXTERNORDERKEY ELSE '' END ASC,    --CS01, IN00354703  
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
                ,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0)  AS SortByExtOrdKey            --CS01                
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
         LEFT JOIN #TMP_RPTCFG WITH (NOLOCK) ON #TMP_RPTCFG.storerkey = ORDERS.StorerKey           --CS01                            
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
                  #TMP_ORDQTYSUM.Totalordpcs,ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0)                                   --CS01, IN00354703                
         ORDER BY CASE WHEN ISNULL(#TMP_RPTCFG.SortByExtOrdKey,0) = '1' THEN ORDERS.EXTERNORDERKEY ELSE '' END ASC,  --CS01, IN00354703               
         LOADPLAN.LoadKey ASC, ORDERS.SOSTATUS DESC, ORDERS.ORDERKEY ASC
      END
   END -- @n_continue = 1 or @n_continue = 2

   Quit:
END /* main procedure */

GO