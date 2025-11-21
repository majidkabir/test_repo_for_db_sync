SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/    
/* Stored Proc: isp_GetPickSlipWave_33                                  */    
/* Creation Date: 24-Aug-2021                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: Mingle                                                   */    
/*                                                                      */    
/* Purpose:  WMS-17604                                                  */    
/*        :                                                             */    
/* Called By: r_dw_print_wave_pickslip_33                               */    
/*          :                                                           */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickSlipWave_33] (      
   @c_Wavekey NVARCHAR(21) )   
AS       
BEGIN      
   SET NOCOUNT ON      
  -- SET ANSI_WARNINGS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET ANSI_DEFAULTS OFF      
     
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
         , @c_GetStorerkey    NVARCHAR(15)        
        
         , @c_AutoScanIn      NVARCHAR(10)        
         , @c_Facility        NVARCHAR(5)        
         , @c_Logo            NVARCHAR(50)        
         , @n_MaxLine         INT        
         , @n_CntRec          INT        
         , @c_MaxPSlipno      NVARCHAR(10)        
         , @n_LastPage        INT        
         , @n_ReqLine         INT        
         , @c_JCLONG          NVARCHAR(255)        
         , @c_RNotes          NVARCHAR(255)        
         , @c_ecomflag        NVARCHAR(50)      
         , @n_MaxLineno       INT      
         , @n_PrnQty          INT      
         , @n_MaxId           INT      
         , @n_MaxRec          INT      
         , @n_CurrentRec      INT      
         , @n_Page            INT      
         , @n_getPageno       INT      
         , @c_recgroup        INT      
         , @c_RptLogo         NVARCHAR(255)      
         , @c_QRCode          NVARCHAR(255)      
         , @c_sku             NVARCHAR(20)    
-- Create Temp Table     
  
   CREATE TABLE #TMP_PCK33_1        
      ( Wavekey      NVARCHAR(10)   NOT NULL        
      , Orderkey     NVARCHAR(10)   NOT NULL        
      , PickSlipNo   NVARCHAR(10)   NOT NULL        
      , Storerkey    NVARCHAR(15)   NOT NULL          
      )      
-- Create Temp Table     
    
   CREATE TABLE #TMP_PCK33  
      ( rowid             INT NOT NULL identity(1,1) PRIMARY KEY  
      , PickHeaderKey     NVARCHAR(18)   NOT NULL  
      , OrderKey          NVARCHAR(10)   NOT NULL
      , OrderDate         DATETIME  
      , DeliveryDate      DATETIME    
      , C_contact1        NVARCHAR(100)  NULL  
      , dudf01            NVARCHAR(60)   NULL  
      , EcomOrderId       NVARCHAR(45)   NULL  
      , ReferenceId       NVARCHAR(20)   NULL  
      , cl1udf01          NVARCHAR(60)   NULL  
      , loc               NVARCHAR(10)   NULL
      , Sku               NVARCHAR(20)   NULL  
      , ODNotes           NVARCHAR(60)   NULL  
      , qty               INT 
      , CL2Notes          NVARCHAR(2000)   NULL  
      , CL3Notes          NVARCHAR(2000)   NULL      
      , PHBarcode         NVARCHAR(100)
      , OHBarcode         NVARCHAR(100)
      , EcomOrdIDBarcode  NVARCHAR(100)  
      )  
    
   -- Get PickSlipNo And Insert PickHeader  
   Insert Into #TMP_PCK33_1   
      ( Wavekey        
      , Orderkey        
      , PickSlipNo        
      , Storerkey        
      )      
   SELECT DISTINCT        
          WaveDetail.Wavekey        
         ,WaveDetail.Orderkey        
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')        
         ,ORDERS.Storerkey         
   FROM WaveDetail  WITH (NOLOCK)        
   JOIN ORDERS          WITH (NOLOCK) ON (WaveDetail.Orderkey = ORDERS.Orderkey)        
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (WaveDetail.Wavekey  = PICKHEADER.WaveKey)        
                                      AND(WaveDetail.Orderkey = PICKHEADER.Orderkey)        
   WHERE WaveDetail.Wavekey = @c_Wavekey        
   GROUP BY WaveDetail.Wavekey        
         ,  WaveDetail.Orderkey        
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
   JOIN #TMP_PCK33_1 ON (PICKHEADER.PickHeaderKey = #TMP_PCK33_1.PickSlipNo)        
   WHERE #TMP_PCK33_1.PickSlipNo <> ''        
        
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
   FROM #TMP_PCK33_1        
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
      FROM #TMP_PCK33_1        
      WHERE PickSlipNo = ''        
      ORDER BY Orderkey        
        
      OPEN CUR_PSLIP        
        
      FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey        
        
      WHILE @@FETCH_STATUS <> -1        
      BEGIN        
        
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo        
        
         BEGIN TRAN        
        
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)        
         VALUES (@c_PickHeaderKey, @c_OrderKey, @c_Wavekey, '0', '3', NULL)        
        
         SET @n_err = @@ERROR        
         IF @n_err <> 0        
         BEGIN        
            SET @n_Continue = 3        
            GOTO QUIT_SP        
         END        
        
         UPDATE #TMP_PCK33_1        
         SET PickSlipNo= @c_PickHeaderKey        
         WHERE Wavekey = @c_Wavekey        
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
-- Get PickSlipNo And Insert PickHeader  
  
-- Auto Scan In  
   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT PickSlipNo        
         ,OrderKey        
         ,Storerkey        
   FROM #TMP_PCK33_1        
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
-- Auto Scan In  
    
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
    
      INSERT INTO #TMP_PCK33  
                 (    PickHeaderKey       
                    , OrderKey          
                    , OrderDate           
                    , DeliveryDate         
                    , C_contact1          
                    , dudf01              
                    , EcomOrderId         
                    , ReferenceId         
                    , cl1udf01           
                    , loc               
                    , Sku                 
                    , ODNotes             
                    , qty               
                    , CL2Notes            
                    , CL3Notes                
                    , PHBarcode
                    , OHBarcode       
                    , EcomOrdIDBarcode              
                 )     
       SELECT PK.PickHeaderKey,    
                   OH.OrderKey,    
                   convert(varchar, OH.OrderDate, 112) AS orderdate,    
                   convert(varchar, OH.DeliveryDate, 112) AS deliverydate,    
                   OH.C_contact1,    
                   CL.UDF01,    
                   OIF.EcomOrderId,    
                   OIF.ReferenceId,    
                   CL1.UDF01,    
                   PD.Loc,    
                   S.Sku,    
                   OD.Notes,    
                   PD.Qty,     
                   CL2.Notes,    
                   CL3.Notes,
                   dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(t.PICKSLIPNO))),
                   dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OH.ORDERKEY))),  
                   dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OIF.Ecomorderid)))    
    
   FROM #TMP_PCK33_1 t
   JOIN ORDERS OH (NOLOCK) ON t.Orderkey = OH.OrderKey   
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey    
   LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey    
   --JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey    
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.Sku = OD.Sku   
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OD.StorerKey     
   JOIN PICKHEADER PK WITH (NOLOCK) ON PK.OrderKey = OH.OrderKey     
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'PLATFORM' AND CL.Storerkey = OH.StorerKey AND CL.Code = OIF.Platform    
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME = 'ECDLMODE' AND CL1.Storerkey = OH.StorerKey AND CL1.Code = OH.ShipperKey    
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'REPORTCFG' AND CL2.Storerkey = OH.StorerKey AND CL2.Code = OIF.Platform AND CL2.code2 = '01'    
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME = 'REPORTCFG' AND CL3.Storerkey = OH.StorerKey AND CL3.Code = OIF.Platform AND CL3.code2 = '02'    
   WHERE t.Wavekey = @c_Wavekey    
   GROUP BY PK.PickHeaderKey,    
                   OH.OrderKey,    
                   convert(varchar, OH.OrderDate, 112),    
                   convert(varchar, OH.DeliveryDate, 112),    
                   OH.C_contact1,    
                   CL.UDF01,    
                   OIF.EcomOrderId,    
                   OIF.ReferenceId,    
                   CL1.UDF01,    
                   PD.Loc,    
                   S.Sku,    
                   OD.Notes,    
                   PD.Qty,    
                   CL2.Notes,    
                   CL3.Notes,
                   dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(t.PICKSLIPNO))),
                   dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OH.ORDERKEY))),  
                   dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OIF.Ecomorderid)))  

        
  
      SELECT  PickHeaderKey       
                    , OrderKey          
                    , OrderDate           
                    , DeliveryDate         
                    , C_contact1          
                    , dudf01              
                    , EcomOrderId         
                    , ReferenceId         
                    , cl1udf01           
                    , loc               
                    , Sku                 
                    , ODNotes             
                    , qty               
                    , CL2Notes            
                    , CL3Notes                
                    , PHBarcode
                    , OHBarcode  
                    , EcomOrdIDBarcode
      FROM #TMP_PCK33      
  
QUIT_RESULT:  
END -- procedure  
  
SET QUOTED_IDENTIFIER OFF 

GO