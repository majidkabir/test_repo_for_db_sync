SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPickSlipOrders66                                 */
/* Creation Date: 09-NOV-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:r_dw_print_pickorder66                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2017-Feb-06  CSCHONG   1.0 WMS-1009 revise report logic (CS01)       */
/* 2017-Oct-04  CSCHONG   1.1 WMS-3140 - Change sorting (CS02)          */
/* 2017-Nov-02  JHTAN     1.2 INC0029494 - Duplicate picking info (JH01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipOrders66]
            @c_Loadkey     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)

         , @n_NoOfReqPSlip    INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

         , @c_AutoScanIn      NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)     --(CS01)

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_Err      = 0
   SET @c_Errmsg   = ''

   CREATE TABLE #TMP_PCK
      ( Loadkey      NVARCHAR(10)   NOT NULL
      , Orderkey     NVARCHAR(10)   NOT NULL
      , PickSlipNo   NVARCHAR(10)   NOT NULL
      , Storerkey    NVARCHAR(15)   NOT NULL
      , Brand             NVARCHAR(60)   NULL
      )
  
   CREATE TABLE #TMP_BRAND
   (  OrderKey          NVARCHAR(10)   NULL
   ,  Brand             NVARCHAR(60)   NULL
   ,  DistinctBrand     INT  NULL
   )

   INSERT INTO #TMP_BRAND
   (  OrderKey
   ,  Brand
   ,  DistinctBrand
   )
   SELECT OrderKey  = ORDERDETAIL.OrderKey
         ,ItemClass    = ISNULL(MIN(RTRIM(CL.Description)),'')
         ,DistinctBrand= COUNT(DISTINCT ISNULL(RTRIM(CL.Description),''))
   FROM ORDERDETAIL WITH (NOLOCK)  
   JOIN SKU           WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                    AND(ORDERDETAIL.Sku = SKU.Sku)
   LEFT JOIN CODELKUP CL   WITH (NOLOCK) ON (CL.ListName = 'ItemClass')
                                         AND(CL.Code = SKU.ItemClass)
   WHERE ORDERDETAIL.Loadkey = @c_LoadKey
   GROUP BY ORDERDETAIL.Orderkey

   UPDATE #TMP_BRAND
      SET Brand = CASE WHEN #TMP_BRAND.DistinctBrand > 1 THEN 'Mixed Brand' ELSE #TMP_BRAND.Brand END   
      
      /*CS01 Start*/
      
      SET @c_Facility = ''
      SELECT @c_Facility = Facility
      FROM LOADPLAN WITH (NOLOCK)
      WHERE Loadkey = @c_Loadkey
      /*CS01 End*/

   INSERT INTO #TMP_PCK
      ( Loadkey     
      , Orderkey     
      , PickSlipNo
      , Storerkey
      , Brand
      )
   SELECT DISTINCT 
          LOADPLANDETAIL.Loadkey
         ,LOADPLANDETAIL.Orderkey
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,ORDERS.Storerkey
         ,#TMP_BRAND.Brand 
   FROM LOADPLANDETAIL  WITH (NOLOCK)  
   JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.ORderkey) 
   JOIN #TMP_BRAND                    ON (ORDERS.Orderkey = #TMP_BRAND.ORderkey)    --(JH01) ORDERS.Orderkey CHANGE TO #TMP_BRAND.ORderkey
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)
                                      AND(LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)
   WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
   GROUP BY LOADPLANDETAIL.Loadkey
         ,  LOADPLANDETAIL.Orderkey
         ,  ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,  ORDERS.Storerkey
         ,  #TMP_BRAND.Brand 

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
      ,EditWho = SUSER_NAME()
      ,EditDate= GETDATE()
      ,TrafficCop = NULL
   FROM PICKHEADER
   JOIN #TMP_PCK ON (PICKHEADER.PickHeaderKey = #TMP_PCK.PickSlipNo)
   WHERE #TMP_PCK.PickSlipNo <> ''

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END 
   
   SET @n_NoOfReqPSlip  = 0

   SELECT @n_NoOfReqPSlip = COUNT(1)
   FROM #TMP_PCK
   WHERE PickSlipNo = ''


   IF @n_NoOfReqPSlip > 0 
   BEGIN
      EXECUTE nspg_GetKey 
              'PICKSLIP'
            , 9
            , @c_PickSlipNo   OUTPUT
            , @b_Success      OUTPUT
            , @n_Err          OUTPUT
            , @c_Errmsg       OUTPUT
            , 0
            , @n_NoOfReqPSlip

      IF @b_success <> 1 
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Orderkey
      FROM #TMP_PCK
      WHERE PickSlipNo = ''
      ORDER BY Orderkey

      OPEN CUR_PSLIP
   
      FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
      
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo

         BEGIN TRAN

         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
         VALUES (@c_PickHeaderKey, @c_OrderKey, @c_LoadKey, '0', '3', NULL)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         UPDATE #TMP_PCK
         SET PickSlipNo= @c_PickHeaderKey
         WHERE Loadkey = @c_Loadkey
         AND Orderkey  = @c_Orderkey


         WHILE @@TRANCOUNT > 0 
         BEGIN
            COMMIT TRAN
         END 

         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)
         FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey
      END
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END
   
   /*CS01 Start*/
   
   
     DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickSlipNo
         ,OrderKey
         ,Storerkey
   FROM #TMP_PCK
   ORDER BY PickSlipNo

   OPEN CUR_PSNO
   
   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo
                                ,@c_Orderkey
                                ,@c_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_AutoScanIn = '0'
      EXEC nspGetRight  
            @c_Facility   = @c_Facility  
         ,  @c_StorerKey  = @c_StorerKey   
         ,  @c_sku        = ''
         ,  @c_ConfigKey  = 'AutoScanIn'  
         ,  @b_Success    = @b_Success    OUTPUT   
         ,  @c_authority  = @c_AutoScanIn OUTPUT
         ,  @n_err        = @n_err        OUTPUT  
         ,  @c_errmsg     = @c_errmsg     OUTPUT
         
      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      BEGIN TRAN
      IF @c_AutoScanIn = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM PICKINGINFO WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo
                        )
         BEGIN
            INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT_SP
            END
         END
      END

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END 
      FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo
                                   ,@c_Orderkey
                                   ,@c_Storerkey
   END 
   CLOSE CUR_PSNO
   DEALLOCATE CUR_PSNO 
   
   /*CS01 END*/

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)  
   BEGIN
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END 
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
   SELECT #TMP_PCK.PickSlipNo
         ,CustomerGroupName = ISNULL(RTRIM(STORER.CustomerGroupName),'')
         ,#TMP_PCK.Brand
         ,#TMP_PCK.Loadkey
         ,#TMP_PCK.Orderkey
         ,Consigneekey   = ISNULL(RTRIM(ORDERS.C_Company),'')
         ,DeliveryDate   = ORDERS.DeliveryDate
         ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,Notes   = ISNULL(RTRIM(ORDERS.Notes),'')
         ,PICKDETAIL.Loc
         ,PICKDETAIL.Storerkey 
         ,Descr = ISNULL(RTRIM(SKU.Descr),'')
         ,Style = ISNULL(RTRIM(SKU.Style),'')
         ,Color = ISNULL(RTRIM(SKU.Color),'')
         ,StyleColor = ISNULL(RTRIM(SKU.Style),'') + '-' 
                     + ISNULL(RTRIM(SKU.Color),'')
         ,Qty = ISNULL(SUM(PICKDETAIL.Qty),0)  
         ,OB_UOM = ISNULL(MAX(RTRIM(SKU.ob_uom)),'')       
   FROM #TMP_PCK
   JOIN STORER     WITH (NOLOCK) ON (#TMP_PCK.Storerkey = STORER.Storerkey)
   JOIN ORDERS     WITH (NOLOCK) ON (#TMP_PCK.Orderkey  = ORDERS.Orderkey)
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey    = PICKDETAIL.Orderkey)
   JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                 AND(PICKDETAIL.Sku       = SKU.Sku)
   WHERE #TMP_PCK.PickSlipNo <> '' 
   GROUP BY #TMP_PCK.PickSlipNo
         ,  ISNULL(RTRIM(STORER.CustomerGroupName),'')
         ,  #TMP_PCK.Brand
         ,  #TMP_PCK.Orderkey
         ,  #TMP_PCK.Loadkey
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ORDERS.DeliveryDate
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.Notes),'')
         ,  PICKDETAIL.Loc
         ,  PICKDETAIL.Storerkey 
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')
    /*CS01 Start*/  
   ORDER BY #TMP_PCK.PickSlipNo
           ,PICKDETAIL.Loc                      --CS02
         --,  ISNULL(RTRIM(SKU.Style),'')       --CS02
         --,  ISNULL(RTRIM(SKU.Color),'')       --CS02
      
   --ORDER BY ISNULL(RTRIM(STORER.CustomerGroupName),'')
   --      ,  #TMP_PCK.Brand
   --      ,  ORDERS.DeliveryDate
   --      ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
   /*CS01 End*/                                                                     

END -- procedure

GO