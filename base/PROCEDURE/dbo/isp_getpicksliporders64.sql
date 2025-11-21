SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetPickSlipOrders64                                     */
/* Creation Date: 02-SEP-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:r_dw_print_pickorder64                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 22-JAN-2018  CSCHONG   1.0 WMS-3710 - add new field (CS01)           */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipOrders64] 
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
         , @c_Facility        NVARCHAR(5)
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

         , @c_AutoScanIn      NVARCHAR(10)

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
      , PSlip2SO     INT            NOT NULL
      )

   
   SET @c_Facility = ''
   SELECT @c_Facility = Facility
   FROM LOADPLAN WITH (NOLOCK)
   WHERE Loadkey = @c_Loadkey

   INSERT INTO #TMP_PCK
      ( Loadkey     
      , Orderkey     
      , PickSlipNo
      , Storerkey
      , PSlip2SO  
      )
   SELECT DISTINCT 
          LOADPLANDETAIL.Loadkey
         ,LOADPLANDETAIL.Orderkey
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,ORDERS.Storerkey
         ,PSlip2SO  = ISNULL(MAX(CASE WHEN CFG.Code = 'PSlip2SO' THEN 1 ELSE 0 END),0) 
   FROM LOADPLANDETAIL  WITH (NOLOCK)  
   JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.ORderkey) 
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)
                                      AND(LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)
   LEFT JOIN CODELKUP CFG  WITH (NOLOCK) ON (CFG.ListName = 'REPORTCFG')
                                         AND(CFG.Storerkey= ORDERS.Storerkey)
                                         AND(CFG.Long = 'r_dw_print_pickorder64')
                                         AND(ISNULL(RTRIM(CFG.Short),'') <> 'N')                                        
   WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
   GROUP BY LOADPLANDETAIL.Loadkey
         ,  LOADPLANDETAIL.Orderkey
         ,  ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,  ORDERS.Storerkey


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


QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)  
   BEGIN
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSNO') in (0 , 1)  
   BEGIN
      CLOSE CUR_PSNO
      DEALLOCATE CUR_PSNO
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


   SELECT LOADPLANDETAIL.Loadkey
         ,LOADPLANDETAIL.Orderkey
         ,#TMP_PCK.PickSlipNo
         ,Route          = ISNULL(RTRIM(LOADPLANDETAIL.Route),'') + ' ' + ISNULL(RTRIM(ROUTEMASTER.Descr),'')
         ,Consigneekey   = ISNULL(RTRIM(LOADPLANDETAIL.Consigneekey),'')
         ,DeliveryDate   = LOADPLANDETAIL.DeliveryDate
         ,CustomerName   = ISNULL(RTRIM(LOADPLANDETAIL.CustomerName),'')
         ,ExternOrderkey = ISNULL(RTRIM(LOADPLANDETAIL.ExternOrderkey),'')
         ,ItemClass = ISNULL(RTRIM(IC.Short),'')
         ,Qty = ISNULL(SUM(PICKDETAIL.Qty),0)  
         ,Sourcekey = CASE WHEN  PSlip2SO = 1 THEN  LOADPLANDETAIL.Orderkey ELSE #TMP_PCK.PickSlipNo END                 
         ,#TMP_PCK.PSlip2SO     
         ,PickZone = L.PickZone                                                      --CS01        
   FROM #TMP_PCK
   JOIN LOADPLANDETAIL  WITH (NOLOCK) ON (#TMP_PCK.Loadkey = LOADPLANDETAIL.Loadkey)  
                                      AND(#TMP_PCK.Orderkey= LOADPLANDETAIL.Orderkey)
   JOIN ROUTEMASTER     WITH (NOLOCK) ON (LOADPLANDETAIL.Route = ROUTEMASTER.Route) 
   JOIN PICKDETAIL      WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey)
   JOIN SKU             WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                      AND(PICKDETAIL.Sku       = SKU.Sku)
   LEFT JOIN CODELKUP  IC    WITH (NOLOCK) ON (IC.ListName = 'ItemClass')     -- Add Left Join to show blank itemclass if not setup
                                           AND(IC.Code     = SKU.ItemClass)
                                           AND(IC.Storerkey= SKU.Storerkey)
                                           --CS01 Start
  --CS01 Start
   JOIN LOC L WITH (NOLOCK) ON L.Loc=PICKDETAIL.Loc
   --CS01 End 
   WHERE #TMP_PCK.PickSlipNo <> '' 
   GROUP BY LOADPLANDETAIL.Loadkey
         ,  LOADPLANDETAIL.Orderkey
         ,  #TMP_PCK.PickSlipNo
         ,  ISNULL(RTRIM(LOADPLANDETAIL.Route),'') 
         ,  ISNULL(RTRIM(ROUTEMASTER.Descr),'')
         ,  ISNULL(RTRIM(LOADPLANDETAIL.Consigneekey),'')
         ,  LOADPLANDETAIL.DeliveryDate
         ,  ISNULL(RTRIM(LOADPLANDETAIL.CustomerName),'')
         ,  ISNULL(RTRIM(LOADPLANDETAIL.ExternOrderkey),'')
         ,  ISNULL(RTRIM(IC.Short),'')
         ,  CASE WHEN  PSlip2SO = 1 THEN  LOADPLANDETAIL.Orderkey ELSE #TMP_PCK.PickSlipNo END
         ,  #TMP_PCK.PSlip2SO  
         , L.PickZone                                                    --CS01
   ORDER BY Consigneekey
         ,  LOADPLANDETAIL.DeliveryDate
         ,  ExternOrderkey  
         ,  ItemClass                                                                        

END -- procedure

GO