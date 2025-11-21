SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPickSlipOrders69                                 */
/* Creation Date: 20-FEB-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-1082 - FBR New Picklist Report Format                   */
/*        :                                                             */
/* Called By:r_dw_print_pickorder69                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 07-JUL-2020  WLChooi   1.1 WMS-13926 - Add Report Config (WL01)      */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipOrders69]  
            @c_Loadkey   NVARCHAR(10)
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

         , @c_ConsoOrderkey   NVARCHAR(30)
         , @c_PrintedFlag     CHAR(1)

         , @c_PickDetailKey   NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_Err      = 0
   SET @c_Errmsg   = ''


   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END 
   
   CREATE TABLE #TMP_PCK
   ( PickSlipNo      NVARCHAR(10)   NOT NULL DEFAULT('')
   , PrintedFlag     CHAR(1)        NOT NULL DEFAULT('N')
   , Loadkey         NVARCHAR(10)   NOT NULL
   , Orderkey        NVARCHAR(10)   NOT NULL
   , ConsoOrderkey   NVARCHAR(30)   NOT NULL
   , LocLevel        NVARCHAR(10)   NOT NULL DEFAULT('')
   )
   
   INSERT INTO #TMP_PCK 
         (Loadkey
         ,Orderkey
         ,ConsoOrderkey
         ,LocLevel
         )  
   SELECT DISTINCT 
          ORDERS.Loadkey
         ,ORDERS.Orderkey
         ,ConsoOrderkey = CASE WHEN LOC.Loclevel = '1' THEN '1' ELSE '2' END
         ,LOC.Loclevel
   FROM ORDERS WITH (NOLOCK)
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
   WHERE ORDERS.Loadkey = @c_Loadkey

   IF NOT EXISTS (SELECT 1
                  FROM #TMP_PCK
               )
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @n_NoOfReqPSlip  = 0

   SELECT @n_NoOfReqPSlip = COUNT(DISTINCT TPK.Loadkey + TPK.Orderkey + TPK.ConsoOrderkey)
   FROM #TMP_PCK TPK
   WHERE NOT EXISTS ( SELECT 1
                      FROM PICKHEADER PH WITH (NOLOCK) 
                      WHERE PH.ExternOrderKey =  TPK.Loadkey 
                      AND PH.Orderkey = TPK.OrderKey
                      AND PH.ConsoOrderkey = TPK.ConsoOrderKey
                    )

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
   END

   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          TPK.Loadkey
         ,TPK.Orderkey
         ,TPK.ConsoOrderkey
         ,PickHeaderkey = ISNULL(RTRIM(PH.PickHeaderKey),'')
   FROM #TMP_PCK TPK
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (TPK.Loadkey = PH.ExternOrderKey)
                                         AND(TPK.Orderkey = PH.Orderkey)
                                         AND(TPK.ConsoOrderkey = PH.ConsoOrderKey)
   ORDER BY TPK.Loadkey
         ,  TPK.Orderkey
         ,  TPK.ConsoOrderkey
         ,  ISNULL(RTRIM(PH.PickHeaderKey),'')

   OPEN CUR_PSLIP
   
   FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey
                                 ,@c_Orderkey
                                 ,@c_ConsoOrderkey
                                 ,@c_PickHeaderKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN
      IF @c_PickHeaderKey = ''
      BEGIN
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo

         INSERT INTO PICKHEADER (PickHeaderKey, Orderkey, ExternOrderKey, ConsoOrderkey, PickType, Zone, TrafficCop)
         VALUES (@c_PickHeaderKey, @c_Orderkey, @c_LoadKey, @c_ConsoOrderkey, '0', 'LB', NULL)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)

         SET @c_PrintedFlag = 'N'
      END
      ELSE 
      BEGIN 
         IF EXISTS ( SELECT 1
                       FROM PICKHEADER WITH (NOLOCK)
                       WHERE PickHeaderKey = @c_PickHeaderKey
                       AND PickType <> '1'
                     )
         BEGIN
            UPDATE PICKHEADER WITH (ROWLOCK)
            SET PickType = '1'
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
               ,TrafficCop = NULL
            FROM PICKHEADER
            WHERE PickHeaderKey = @c_PickHeaderKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT_SP
            END
         END
         SET @c_PrintedFlag = 'Y'
      END

      DECLARE CUR_PD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT 
              PD.PickDetailKey
            , PD.Orderkey
            , PD.OrderLineNumber
      FROM #TMP_PCK TPK
      JOIN PICKDETAIL PD   WITH (NOLOCK) ON (TPK.Orderkey  = PD.Orderkey)
      JOIN LOC        LOC  WITH (NOLOCK) ON (PD.Loc  = LOC.Loc)
                                         AND(TPK.LocLevel = LOC.LocLevel)
      WHERE TPK.Loadkey = @c_Loadkey
      AND   TPK.Orderkey= @c_Orderkey
      AND   TPK.ConsoOrderkey = @c_ConsoOrderkey
      ORDER BY PD.PickDetailKey

      OPEN CUR_PD
   
      FETCH NEXT FROM CUR_PD INTO @c_PickDetailkey
                                 ,@c_Orderkey
                                 ,@c_OrderLineNumber

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         IF EXISTS ( SELECT 1
                     FROM REFKEYLOOKUP WITH (NOLOCK)
                     WHERE Pickdetailkey = @c_PickDetailKey
                  )
         BEGIN
            UPDATE REFKEYLOOKUP WITH (ROWLOCK)
            SET PickSlipNo = @c_PickHeaderKey
               ,EditWho = SUSER_NAME()
               ,EditDate= GETDATE()
               ,ArchiveCop = NULL
            WHERE PickDetailKey = @c_PickDetailKey
            AND PickSlipNo <> @c_PickHeaderKey
         END
         ELSE
         BEGIN
            INSERT INTO REFKEYLOOKUP (Pickdetailkey, Pickslipno, Orderkey, OrderLineNumber, Loadkey)
            VALUES (@c_PickDetailkey, @c_PickHeaderKey, @c_OrderKey, @c_OrderLineNumber, @c_loadkey)
         END

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_PD INTO @c_PickDetailkey
                                    ,@c_Orderkey
                                    ,@c_OrderLineNumber
      END
      CLOSE CUR_PD
      DEALLOCATE CUR_PD

      UPDATE #TMP_PCK
      SET PickSlipNo  = @c_PickHeaderKey
         ,PrintedFlag = @c_PrintedFlag
      WHERE Loadkey   = @c_Loadkey
      AND   Orderkey  = @c_Orderkey
      AND ConsoOrderkey  = @c_ConsoOrderkey

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
          
      FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey
                                    ,@c_OrderKey
                                    ,@c_ConsoOrderkey
                                    ,@c_PickHeaderKey

   END
   CLOSE CUR_PSLIP
   DEALLOCATE CUR_PSLIP

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)  
   BEGIN
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PD') in (0 , 1)  
   BEGIN
      CLOSE CUR_PD
      DEALLOCATE CUR_PD
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

   SELECT TPK.PickSlipNo      
      ,  TPK.PrintedFlag
      ,  TPK.LoadKey   
      ,  TPK.Orderkey 
      ,  TPK.LocLevel          
      ,  DocNo = TPK.Orderkey + ' / ' + TPK.LoadKey 
      ,  Route = ISNULL(RTRIM(LOADPLAN.Route),'')
      ,  Carrierkey = ISNULL(RTRIM(LOADPLAN.Carrierkey),'')
      ,  Truck_Type = ISNULL(RTRIM(LOADPLAN.Truck_Type),'')
      ,  Carrier    = ISNULL(RTRIM(LOADPLAN.Carrierkey),'') + ' / ' 
                    + ISNULL(RTRIM(LOADPLAN.Truck_Type),'')
      ,  ExternOrderkey= ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
      ,  Consigneekey  = ISNULL(RTRIM(ORDERS.Consigneekey),'')  
      ,  C_Company = ISNULL(RTRIM(ORDERS.C_Company),'')
      ,  Shipto    = ISNULL(RTRIM(ORDERS.Consigneekey),'') + ' / '
                   + ISNULL(RTRIM(ORDERS.C_Company),'')
      ,  C_Address1= ISNULL(RTRIM(ORDERS.C_Address1),'')
      ,  C_City    = ISNULL(RTRIM(ORDERS.C_City),'')
      ,  PrintDate = GETDATE()
      ,  ORDERS.DeliveryDate
      ,  Notes     = ISNULL(RTRIM(ORDERS.Notes),'')
      ,  PICKDETAIL.Storerkey       
      ,  PICKDETAIL.Sku             
      ,  SkuDescr = ISNULL(RTRIM(SKU.Descr),'')
      ,  PICKDETAIL.Loc             
      ,  StdGrossWgt = ISNULL(RTRIM(SKU.StdGrossWgt),0.00) 
      ,  StdCube = ISNULL(RTRIM(SKU.StdCube),0.00)   
      ,  CaseCnt = ISNULL(PACK.CaseCnt,0)                       
      ,  QtyInCS = CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END        
      ,  QtyInEA = SUM(PICKDETAIL.Qty)     
      ,  ShowSKUBarcode = ISNULL(CL.Short,'N')   --WL01 
   FROM #TMP_PCK TPK 
   JOIN LOADPLAN   WITH (NOLOCK) ON (TPK.Loadkey = LOADPLAN.Loadkey)
   JOIN ORDERS     WITH (NOLOCK) ON (TPK.Orderkey= ORDERS.Orderkey)
   JOIN PICKDETAIL WITH (NOLOCK) ON (TPK.Orderkey = PICKDETAIL.Orderkey)
   JOIN LOC        WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
                                 AND(TPK.LocLevel = LOC.LocLevel)
   JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                 AND(PICKDETAIL.Sku = SKU.Sku)
   JOIN PACK       WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   LEFT OUTER JOIN Codelkup CL (NOLOCK) ON (ORDERS.Storerkey = CL.Storerkey AND CL.Code = 'ShowSKUBarcode'
                                        AND CL.Listname = 'REPORTCFG' AND CL.Long = 'r_dw_print_pickorder69' AND ISNULL(CL.Short,'') <> 'N')
   GROUP BY TPK.PickSlipNo      
         ,  TPK.PrintedFlag
         ,  TPK.LoadKey   
         ,  TPK.Orderkey 
         ,  TPK.LocLevel                 
         ,  ISNULL(RTRIM(LOADPLAN.Route),'')
         ,  ISNULL(RTRIM(LOADPLAN.Carrierkey),'')
         ,  ISNULL(RTRIM(LOADPLAN.Truck_Type),'')
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
         ,  ISNULL(RTRIM(ORDERS.Consigneekey),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,  ISNULL(RTRIM(ORDERS.C_City),'')
         ,  ORDERS.DeliveryDate
         ,  ISNULL(RTRIM(ORDERS.Notes),'')
         ,  PICKDETAIL.Storerkey       
         ,  PICKDETAIL.Sku             
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  PICKDETAIL.Loc             
         ,  ISNULL(RTRIM(SKU.StdGrossWgt),0.00) 
         ,  ISNULL(RTRIM(SKU.StdCube),0.00)   
         ,  ISNULL(PACK.CaseCnt,0)  
         ,  ISNULL(CL.Short,'N')   --WL01
   ORDER BY TPK.PickSlipNo
      ,  TPK.LocLevel
      ,  PICKDETAIL.Loc  
      ,  PICKDETAIL.Storerkey
      ,  PICKDETAIL.Sku

END -- procedure

GO