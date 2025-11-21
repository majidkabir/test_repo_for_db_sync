SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/************************************************************************/  
/* Trigger: isp_ECOMP_GetPackTaskOrderStatus                            */  
/* Creation Date: 19-APR-2016                                           */  
/* Copyright: Maersk                                                    */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#361901 - New ECOM Packing                               */  
/*        :                                                             */  
/* Called By: isp_Ecom_GetPackTaskOrders_M                              */  
/*          : isp_Ecom_GetPackTaskOrders_S                              */  
/*          :                                                           */  
/*   Notes  : change return column must change call SPs                 */  
/* PVCS Version: 2.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date           Author      Purposes                                  */  
/* 11-Apr-2023    Allen       #JIRA PAC-4 Initial                       */ 
/************************************************************************/  
CREATE   PROC [API].[isp_ECOMP_GetPackTaskOrderStatus] 
         @c_TaskBatchNo NVARCHAR(10)  
      ,  @c_PickSlipNo  NVARCHAR(10)  = ''    
      ,  @c_Orderkey    NVARCHAR(10)  = ''    
AS           
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
            @n_StartTCnt         INT               --(Wan04)  
  
   DECLARE  @n_RowRef            BIGINT            --(Wan03)  
         ,  @n_OD_QtyAllocated   INT               --(Wan03)  
           
   DECLARE @c_OrderMode          NVARCHAR(10)      --(Wan06)  
     
   --Wan07 - START  
   DECLARE @n_Cnt                INT           = 0  
         , @c_Storerkey          NVARCHAR(20)  = ''     
         , @c_Sku                NVARCHAR(20)  = ''   
         , @dt_PTDAddDate        DATETIME      
           
         , @c_Facility           NVARCHAR(5)    = ''  --(Wan11)  
         , @c_Orderkey_PT        NVARCHAR(10)   = ''  --(Wan11)             
         , @c_EPACK4PickedOrder  NVARCHAR(30)   = '0' --(Wan11)    
  
   DECLARE @TMPSkuQty            TABLE  
         (  Orderkey       NVARCHAR(10) NOT NULL PRIMARY KEY   
         ,  Storerkey      NVARCHAR(15) NULL  
         ,  Sku            NVARCHAR(20) NULL  
         ,  QtyAllocated   INT          NULL  
         ,  EditDate       DATETIME     NULL  
         ,  RowRef_PTD     INT          NOT NULL DEFAULT(0)       --(Wan09)  
         )  
   
   --DECLARE @TMPPTDSkuQty         TABLE                          --(Wan09)  
   --      (  RowRef         INT          NOT NULL                --(Wan09)  
   --      ,  Orderkey       NVARCHAR(10) NOT NULL PRIMARY KEY    --(Wan09)  
   --      ,  Storerkey      NVARCHAR(15) NULL                    --(Wan09)  
   --      ,  Sku            NVARCHAR(20) NULL                    --(Wan09)  
   --      ,  QtyAllocated   INT          NULL                    --(Wan09)  
   --      ,  AddDate        DATETIME     NULL                    --(Wan09)  
   --      )                                                      --(Wan09)  
  
   --DECLARE @TMPORDER       TABLE                                --Wan08  
   --      (  Orderkey       NVARCHAR(10) NOT NULL PRIMARY KEY    --Wan08  
   --      )                                                      --Wan08  
  
   --Wan07 - END  
  
   --SET @n_StartTCnt = @@TRANCOUNT  
  
   --(Wan04) - START  
   --WHILE @@TRANCOUNT > 0  
   --BEGIN  
   --   COMMIT TRAN  
   --END  
   --(Wan04) - END  
  
   IF RTRIM(@c_TaskBatchNo) = '' OR @c_TaskBatchNo IS NULL  
   BEGIN  
      GOTO QUIT_SP                                 --(Wan04)   
   END  
  
   --Wan07 - START  
   --(Wan03) - Fixed to Update PACKTASKDETAIL.QtyAllocated - START  
   --IF EXISTS ( SELECT 1  
   --            FROM PACKTASKDETAIL WITH (NOLOCK)  
   --            WHERE TaskBatchNo = @c_TaskBatchNo  
   --         )  
   SELECT TOP 1 @n_Cnt = 1  
         , @dt_PTDAddDate = ADDDate  
   FROM PACKTASKDETAIL WITH (NOLOCK)  
   WHERE TaskBatchNo = @c_TaskBatchNo  
   ORDER BY ADDDate   
  
   IF @n_Cnt > 0  
   BEGIN  
      IF ISNULL(@c_PickSlipNo,'') = ''  
      BEGIN  
         GOTO QUIT_SP     
      END  
  
      --(Wan09) - START  
      --SELECT TOP 1 @c_Storerkey = PD.Storerkey  
      --            ,@c_Sku = PD.Sku  
      --FROM PACKDETAIL PD WITH (NOLOCK)   
      --WHERE PD.PickSlipNo = @c_PickSlipNo  
      --ORDER BY PD.CartonNo DESC  
      --      ,  PD.labelline DESC  
  
      --IF @c_Sku = ''  
      --BEGIN  
      --   GOTO QUIT_SP     
      --END  
      --(Wan09) - END  
  
      IF @c_Orderkey = ''  
      BEGIN  
         --(Wan08) - START  
         --INSERT INTO @TMPORDER ( Orderkey )  
         --SELECT DISTINCT OD.Orderkey         --(Wan08)  
         --FROM PACKTASK PT WITH (NOLOCK)  
         --JOIN ORDERDETAIL OD WITH (NOLOCK) ON PT.Orderkey = OD.Orderkey  
         --WHERE PT.TaskBatchNo = @c_TaskBatchNo  
         --AND   OD.Storerkey = @c_Storerkey  
         --AND   OD.Sku = @c_Sku  
         --AND   OD.[Status] < '5'  
         --AND   OD.EditDate > @dt_PTDAddDate  
  
         --(Wan09) - START  
  
         --INSERT INTO @TMPPTDSkuQty ( RowRef, Orderkey, Storerkey, Sku, QtyAllocated, AddDate )  
         --SELECT TOP 100 PTD.RowRef  
         --      ,  PTD.Orderkey  
         --      ,  PTD.Storerkey  
         --      ,  PTD.Sku  
         --      ,  PTD.QtyAllocated  
         --      ,  PTD.AddDate   
         --FROM PACKTASKDETAIL PTD WITH (NOLOCK)    
         --WHERE PTD.TaskBatchNo = @c_TaskBatchNo  
         --AND   PTD.Storerkey = @c_Storerkey  
         --AND   PTD.Sku = @c_Sku  
         --AND   PTD.[Status] < '9'  
         --ORDER BY PTD.RowRef  
         --  
         --IF NOT EXISTS (SELECT 1 FROM @TMPPTDSkuQty)  
         --BEGIN  
         --   GOTO QUIT_SP     
         --END  
         --  
         --INSERT INTO @TMPSkuQty ( Orderkey, Storerkey, Sku, QtyAllocated, EditDate )  
         --SELECT   OD.Orderkey  
         --      ,  OD.Storerkey  
         --      ,  OD.Sku  
         --      ,  QtyAllocated = ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)  
         --      ,  EditDate = MAX(OD.EditDate)  
         --FROM  @TMPPTDSkuQty PTD  
         --JOIN  ORDERDETAIL OD WITH (NOLOCK) ON PTD.Orderkey = OD.Orderkey  
         --WHERE OD.Storerkey = @c_Storerkey  
         --AND   OD.Sku = @c_Sku  
         --AND   OD.[Status] < '5'  
         --GROUP BY OD.Orderkey  
         --      ,  OD.Storerkey  
         --      ,  OD.Sku  
         --      ,  PTD.QtyAllocated                                                                 --(Wan08)  
         --      ,  PTD.AddDate                                                                      --(Wan08)  
         --HAVING MAX(OD.EditDate) > PTD.AddDate                                                     --(Wan08)  
         --AND  ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0) <> PTD.QtyAllocated    --(Wan08)  
  
         INSERT INTO @TMPSkuQty ( Orderkey, Storerkey, Sku, QtyAllocated, EditDate, RowRef_PTD )  
         SELECT   OD.Orderkey  
               ,  OD.Storerkey  
               ,  OD.Sku  
               ,  QtyAllocated = ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)  
               ,  EditDate = MAX(OD.EditDate)    
               ,  PTD.RowRef   
         FROM PACKTASKDETAIL PTD WITH (NOLOCK)  
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  PTD.Orderkey = OD.Orderkey  
                                           AND PTD.Storerkey= OD.Storerkey  
                                           AND PTD.Sku      = OD.Sku  
         WHERE PTD.TaskBatchNo = @c_TaskBatchNo  
         AND   OD.[Status] < '9'  
         AND   PTD.[Status] < '9'  
         GROUP BY OD.Orderkey  
               ,  OD.Storerkey  
               ,  OD.Sku  
               ,  PTD.QtyAllocated                                                                   
               ,  PTD.AddDate    
               ,  PTD.RowRef                                                                      
         HAVING MAX(OD.EditDate) > PTD.AddDate                                                       
         AND  ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0) <> PTD.QtyAllocated      
         --(Wan09) - END  
  
         IF NOT EXISTS (SELECT 1 FROM @TMPSkuQty)  
         BEGIN  
            GOTO QUIT_SP     
         END  
         --(Wan08) - END  
      END  
      ELSE  
      BEGIN  
         --(Wan09) - START  
         --INSERT INTO @TMPSkuQty ( Orderkey, Storerkey, Sku, QtyAllocated, EditDate )  
         --SELECT   OD.Orderkey  
         --      ,  OD.Storerkey  
         --      ,  OD.Sku  
         --      ,  QtyAllocated = ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)  
         --      ,  EditDate = MAX(OD.EditDate)  
         --FROM ORDERDETAIL OD WITH (NOLOCK)   
         --WHERE OD.Orderkey  = @c_Orderkey  
         --AND   OD.Storerkey = @c_Storerkey         
         --AND   OD.Sku = @c_Sku                     
         --AND   OD.[Status] < '5'                    
         --GROUP BY OD.Orderkey  
         --      ,  OD.Storerkey  
         --      ,  OD.Sku  
         --HAVING MAX(OD.EditDate) > @dt_PTDAddDate  
         --  
         --IF NOT EXISTS (SELECT 1 FROM @TMPSkuQty)  
         --BEGIN  
         --   GOTO QUIT_SP     
         --END           
  
         --(Wan08) - START  
         --INSERT INTO @TMPPTDSkuQty ( RowRef, Orderkey, Storerkey, Sku, QtyAllocated, AddDate )  
         --SELECT   PTD.RowRef  
         --      ,  PTD.Orderkey  
         --      ,  PTD.Storerkey  
         --      ,  PTD.Sku  
         --      ,  PTD.QtyAllocated  
         --      ,  PTD.AddDate   
         --FROM @TMPSkuQty OD  
         --JOIN  PACKTASKDETAIL PTD WITH (NOLOCK) ON  OD.Orderkey = PTD.Orderkey   
         --                                       AND OD.Storerkey= PTD.Storerkey  
         --                                       AND OD.Sku = PTD.Sku  
         --WHERE PTD.TaskBatchNo= @c_TaskBatchNo  
         --AND   PTD.Orderkey  = @c_Orderkey  
         --AND   PTD.Storerkey = @c_Storerkey  
         --AND   PTD.Sku = @c_Sku  
         --AND   PTD.[Status] < '9'  
         --AND   OD.QtyAllocated <> PTD.QtyAllocated   
         --AND   OD.EditDate > PTD.AddDate  
  
         --IF NOT EXISTS (SELECT 1 FROM @TMPPTDSkuQty)  
         --BEGIN  
         --   GOTO QUIT_SP     
         --END      
         --(Wan08) - END  
  
         INSERT INTO @TMPSkuQty ( Orderkey, Storerkey, Sku, QtyAllocated, EditDate, RowRef_PTD)  
         SELECT   OD.Orderkey  
               ,  OD.Storerkey  
               ,  OD.Sku  
               ,  QtyAllocated = ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)  
               ,  EditDate = MAX(OD.EditDate)    
               ,  PTD.RowRef   
         FROM PACKTASKDETAIL PTD WITH (NOLOCK)  
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON  PTD.Orderkey = OD.Orderkey  
                                           AND PTD.Storerkey= OD.Storerkey  
                                           AND PTD.Sku      = OD.Sku  
         WHERE PTD.TaskBatchNo = @c_TaskBatchNo  
         AND   PTD.Orderkey    = @c_Orderkey  
         AND   OD.[Status] < '9'  
         AND   PTD.[Status] < '9'  
         GROUP BY OD.Orderkey  
               ,  OD.Storerkey  
               ,  OD.Sku  
               ,  PTD.QtyAllocated                                                                   
               ,  PTD.AddDate  
               ,  PTD.RowRef                                                                         
         HAVING MAX(OD.EditDate) > PTD.AddDate                                                       
         AND  ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0) <> PTD.QtyAllocated    
           
         IF NOT EXISTS (SELECT 1 FROM @TMPSkuQty)  
         BEGIN  
            GOTO QUIT_SP     
         END        
         --(Wan09) - END  
      END  
        
      --DECLARE CUR_UPDPTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      --(Wan09) - START  
      --SELECT PTD.RowRef                                               --(Wan09)  
      --   ,   OD.QtyAllocated                                          --(Wan09)  
      --FROM @TMPSkuQty OD                                              --(Wan09)  
      --JOIN @TMPPTDSkuQty PTD ON  OD.Orderkey = PTD.Orderkey           --(Wan09)  
      --                       AND OD.Storerkey= PTD.Storerkey          --(Wan09)  
      --                       AND OD.Sku = PTD.Sku                     --(Wan09)  
      --WHERE OD.QtyAllocated <> PTD.QtyAllocated                       --(Wan09)  
      --AND   OD.EditDate > PTD.AddDate                                 --(Wan09)  
      --Wan07 - END                                                     --(Wan09)  
                                                                        --(Wan09)  
      DECLARE CUR_UPDPTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        --(Wan09)  
      SELECT OD.RowRef_PTD                                              --(Wan09)  
         ,   OD.QtyAllocated                                            --(Wan09)  
      FROM @TMPSkuQty OD                                                --(Wan09)  
      ORDER BY OD.RowRef_PTD                                            --(Wan09) - END  
  
      OPEN CUR_UPDPTD  
     
      FETCH NEXT FROM CUR_UPDPTD INTO @n_RowRef  
                                    , @n_OD_QtyAllocated  
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
         --BEGIN TRAN                                --(Wan04)  
         UPDATE PACKTASKDETAIL WITH (ROWLOCK)  
         SET QtyAllocated = @n_OD_QtyAllocated  
           , EditDate = GETDATE()  
           , EditWho  = SUSER_NAME()  
         WHERE RowRef = @n_RowRef  
         AND Status < '9'  
         AND QtyAllocated <> @n_OD_QtyAllocated    --(Wan04) Avoid Multi User process same single mode batch # to re-update  
     
         --(Wan04) - START  
         --IF @@ERROR <> 0   
         --BEGIN  
         --   IF @@TRANCOUNT > 0   
         --   BEGIN  
         --      ROLLBACK TRAN  
         --   END  
         --END        
  
         --WHILE @@TRANCOUNT > 0           
         --BEGIN  
         --   COMMIT TRAN  
         --END    
         --(Wan04) - END  
   
         FETCH NEXT FROM CUR_UPDPTD INTO @n_RowRef  
                                       , @n_OD_QtyAllocated  
      END  
      CLOSE CUR_UPDPTD  
 DEALLOCATE CUR_UPDPTD  
  
      GOTO QUIT_SP  
   END  
  
   ---------------------------  
   /* Create PackTaskDetail */  
   ---------------------------  
   DECLARE @TMP_PTSTATUS TABLE   
      (  RowRef         BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY   
      ,  TaskBatchNo    NVARCHAR(10)   NOT NULL     
      ,  LogicalName    NVARCHAR(10)   NOT NULL  
      ,  DevicePosition NVARCHAR(10)   NOT NULL  
      ,  Storerkey      NVARCHAR(15)   NOT NULL  
      ,  Orderkey       NVARCHAR(10)   NOT NULL  
      ,  PickSlipNo     NVARCHAR(10)   NOT NULL  
      ,  Status         NVARCHAR(10)   NOT NULL  
      ,  SOStatus       NVARCHAR(10)   NOT NULL  
      ,  OrdStatus      NVARCHAR(10)   NOT NULL  
      )  
  
      --(Wan06) - START  
      SET @c_OrderMode = ''  
      SELECT TOP 1 @c_OrderMode = PT.OrderMode  
               ,  @c_Orderkey_PT = PT.Orderkey     --(Wan11)  
      FROM PACKTASK PT WITH (NOLOCK)  
      WHERE PT.TaskBatchNo = @c_TaskBatchNo  
      --(Wan06) - END  
        
      --(Wan11) - START  
      SELECT @c_Facility = OH.Facility  
            ,@c_Storerkey = OH.StorerKey   
      FROM ORDERS OH WITH (NOLOCK)   
      WHERE OH.OrderKey = @c_Orderkey_PT  
        
      SELECT @c_EPACK4PickedOrder = SC.Authority  
      FROM fnc_SelectGetRight (@c_Facility, @c_Storerkey, '', 'EPACK4PickedOrder') SC  
      --(Wan11) - START  
  
      INSERT INTO @TMP_PTSTATUS  
      (  TaskBatchNo   
      ,  LogicalName   
      ,  DevicePosition  
      ,  Storerkey    
      ,  Orderkey          
      ,  PickSlipNo        
      ,  Status   
      ,  SOStatus   
      ,  OrdStatus         --(Wan01) --12-OCT-2016    
      )  
      SELECT DISTINCT PT.TaskBatchNo                              -- (Wan04) Make sure it is unique taskbatchno + orderkey  
         , LogicalName    = ISNULL(RTRIM(PT.LogicalName),'')   
         , DevicePosition = ISNULL(RTRIM(PT.DevicePosition),'')  
         , OH.Storerkey  
         , OH.Orderkey  
         , ''    
         , CASE WHEN SOStatus IN ('CANC', 'HOLD')      THEN 'X'      
                --WHEN OH.SOStatus = ISNULL(CL1.Code,'') THEN 'X'   
                --WHEN OH.SOStatus = ISNULL(CL2.Code,'') AND CL.Storerkey IS NULL THEN 'X'                     
                WHEN OH.SOStatus = CL1.Code AND OH.SOStatus IS NOT NULL THEN 'X' --NJOW01  
                WHEN OH.SOStatus = CL2.Code AND OH.SOStatus IS NOT NULL AND CL.Storerkey IS NULL THEN 'X' --NJOW01  
           ELSE '0' END          
         , OH.SOStatus  
         , OH.Status    
      FROM PACKTASK        PT WITH (NOLOCK)  
      JOIN ORDERS          OH WITH (NOLOCK) ON (PT.Orderkey = OH.Orderkey)  
      LEFT JOIN CODELKUP CL  WITH (NOLOCK)  ON (CL.ListName = 'NONEPACKSO')  
                                            AND(CL.Storerkey = OH.Storerkey)   
      LEFT JOIN CODELKUP CL1 WITH (NOLOCK)  ON (CL1.ListName = 'NONEPACKSO')  
                                            AND(CL1.Code = OH.SOStatus)  
                                            AND(CL1.Storerkey = OH.Storerkey)   
      LEFT JOIN CODELKUP CL2 WITH (NOLOCK)  ON (CL2.ListName = 'NONEPACKSO')  
                                            AND(CL2.Code = OH.SOStatus)  
                                            AND(CL2.Storerkey = '')  
      WHERE PT.TaskBatchNo = @c_TaskBatchNo  
  
      IF LEFT(@c_OrderMode,1) = 'M'       --(Wan06)    
      BEGIN  
         IF EXISTS ( SELECT 1  
                     FROM @TMP_PTSTATUS  
                     WHERE TaskBatchNo = @c_TaskBatchNo  
                     AND DevicePosition <> ''  
                     )  
         BEGIN  
            UPDATE @TMP_PTSTATUS  
            SET LogicalName = DevicePosition   
            WHERE TaskBatchNo = @c_TaskBatchNo  
            AND DevicePosition <> ''  
            AND RowRef > 0                --(Wan06)  
         END  
      END                                 --(Wan06)  
  
      --(Wan11) - START  
      IF @c_EPACK4PickedOrder = '1'  
      BEGIN  
         ;WITH PIP_O ( Orderkey )  
          AS ( SELECT S.Orderkey  
               FROM @TMP_PTSTATUS S  
               JOIN PICKDETAIL pd WITH (NOLOCK) ON s.Orderkey = pd.OrderKey  
               GROUP BY S.Orderkey  
               HAVING MIN(pd.[Status]) < '3' AND MAX(pd.[Status]) BETWEEN '0' AND '5'  
             )  
         
         UPDATE S  
            SET [Status] = 'P'  
         FROM @TMP_PTSTATUS S  
         JOIN PIP_O ON S.Orderkey = PIP_O.Orderkey  
      END  
      --(Wan11) - END  
        
      IF EXISTS ( SELECT 1  
                  FROM @TMP_PTSTATUS S  
                  JOIN PACKHEADER PH WITH (NOLOCK) ON (S.TaskBatchNo = PH.TaskBatchNo)  
                                                   AND(S.Orderkey = PH.Orderkey)  
                  WHERE S.TaskBatchNo = @c_TaskBatchNo  
                  AND S.Status  IN ('0', 'P')      --(Wan11)  
                  AND PH.Status IN ('0', '9')  
                  AND S.RowRef > 0                 --(Wan06)  
                  )  
      BEGIN  
         UPDATE @TMP_PTSTATUS  
            SET Status = CASE WHEN PH.Status = '9' THEN '9' ELSE '3' END   
               ,PickSlipNo = PH.PickSlipNo  
         FROM @TMP_PTSTATUS S  
         JOIN PACKHEADER PH WITH (NOLOCK) ON (S.TaskBatchNo = PH.TaskBatchNo)  
                                          AND(S.Orderkey = PH.Orderkey)  
         WHERE S.TaskBatchNo = @c_TaskBatchNo  
         AND S.Status  IN ('0', 'P')      --(Wan11)  
         AND PH.Status IN ('0', '9')  
         AND S.RowRef > 0                 --(Wan06)  
      END  
  
      -- Exception update to '9' if Shipment Order status >= '5' but not in PackHeader.  
      IF EXISTS ( SELECT 1  
                  FROM @TMP_PTSTATUS S  
                  WHERE S.TaskBatchNo = @c_TaskBatchNo  
                  AND S.OrdStatus >= '5' AND S.Status  IN ('0', 'P')       --(Wan11)  
                  AND S.RowRef > 0        --(Wan06)  
                  )  
      BEGIN  
         UPDATE @TMP_PTSTATUS  
            SET Status = '9'   
         FROM @TMP_PTSTATUS S  
         WHERE S.TaskBatchNo = @c_TaskBatchNo  
         AND S.OrdStatus >= '5' AND S.Status  IN ('0', 'P')                --(Wan11)  
         AND S.RowRef > 0                 --(Wan06)  
      END  
  
      --BEGIN TRAN  
         BEGIN TRY  
            IF LEFT(@c_OrderMode,1) = 'M'  
            BEGIN  
               INSERT INTO PACKTASKDETAIL  
                        (  TaskBatchNo  
                        ,  LogicalName  
                        ,  Orderkey  
                        ,  Storerkey  
                        ,  Sku  
                        ,  QtyAllocated  
                        ,  PickSlipNo  
                        ,  Status  
                        )  
               SELECT PS.TaskBatchNo  
                  , PS.LogicalName  
                  , OD.Orderkey  
                  , OD.Storerkey  
                  , OD.Sku  
                  , QtyAllocated = SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)  
                  , PS.PickSlipNo  
                  , PS.Status  
               FROM @TMP_PTSTATUS PS     
               JOIN ORDERDETAIL   OD WITH (NOLOCK) ON (PS.Orderkey = OD.Orderkey)  
               WHERE PS.TaskBatchNo = @c_TaskBatchNo  
               AND NOT EXISTS ( SELECT 1 FROM PACKTASKDETAIL PTD WITH (NOLOCK)  --(Wan04) Avoid Multi User process same single mode batch # to re-insert  
                                WHERE PS.TaskBatchNo = PTD.TaskBatchNo )  
               AND PS.RowRef > 0           
               GROUP BY PS.TaskBatchNo  
                     , PS.LogicalName  
                     , OD.Orderkey  
                     , OD.Storerkey  
                     , OD.Sku  
                     , PS.PickSlipNo  
                     , PS.Status  
            END  
            ELSE  
            BEGIN  
               INSERT INTO PACKTASKDETAIL  
                        (  TaskBatchNo  
                        ,  LogicalName  
                        ,  Orderkey  
                        ,  Storerkey  
                        ,  Sku  
                        ,  QtyAllocated  
                        ,  PickSlipNo  
                   ,  Status  
                        )  
               SELECT PS.TaskBatchNo     --(Wan11)  
                  , PS.LogicalName  
                  , OD.Orderkey  
                  , OD.Storerkey  
                  , OD.Sku  
                  , OD.QtyAllocated                --(Wan09)  
                  , PS.PickSlipNo  
                  , PS.Status  
               FROM @TMP_PTSTATUS PS     
               JOIN ORDERDETAIL   OD WITH (NOLOCK) ON (PS.Orderkey = OD.Orderkey)  
               JOIN PICKDETAIL    PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber)    --(Wan11) 2021-05-06  
               WHERE PS.TaskBatchNo = @c_TaskBatchNo  
               AND NOT EXISTS ( SELECT 1 FROM PACKTASKDETAIL PTD WITH (NOLOCK)    
                                WHERE PS.TaskBatchNo = PTD.TaskBatchNo )  
               AND PS.RowRef > 0    
               AND OD.QtyAllocated > 0             --(Wan09)  
               ORDER BY CASE WHEN PD.[Status]= 4 THEN 9 ELSE 0 END   --(Wan11) 2021-05-06  
                      , PD.Orderkey                                  --(Wan11) 2021-05-06  
            END  
  
         END TRY  
         BEGIN CATCH  
            INSERT INTO ERRLOG ( LogDate, UserId, ErrorID, SystemState, Module, ErrorText )  
            SELECT GETDATE(), SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), 'isp_ECOMP_GetPackTaskOrderStatus', ERROR_MESSAGE()  
  
         END CATCH  
  
      --WHILE @@TRANCOUNT > 0  
      --BEGIN  
      --   COMMIT TRAN  
      --END  
  
   QUIT_SP:  
   --(Wan04) - START  
   --WHILE @@TRANCOUNT < @n_StartTCnt  
   --BEGIN  
   --   BEGIN TRAN  
   --END  
   --(Wan04) - END  
END  
GO