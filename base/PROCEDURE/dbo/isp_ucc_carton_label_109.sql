SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: isp_UCC_Carton_Label_109                            */      
/* Creation Date: 07-Aug-2021                                           */      
/* Copyright: LFL                                                       */      
/* Written by: WLChooi                                                  */      
/*                                                                      */      
/* Purpose: WMS-17606 - [CN] LOGIEU SSCC Carton Label                   */      
/*                                                                      */      
/* Input Parameters: @c_StorerKey - StorerKey,                          */      
/*                   @c_PickSlipNo - Pickslipno,                        */      
/*                   @c_FromCartonNo - From CartonNo,                   */      
/*                   @c_ToCartonNo - To CartonNo,                       */      
/*                   @c_Type - Type                                     */      
/*                                                                      */      
/* Usage: Call by dw = r_dw_ucc_carton_label_109                        */      
/*                                                                      */      
/* GitLab Version: 1.0                                                  */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver. Purposes                                  */      
/* 07-Aug-2021  WLChooi  1.0  DevOps Combine Script                     */      
/* 22-Jun-2022  KuanYee  1.1  Cater MultiSKU show respective Udf05(KY01)*/    
/* 27-Feb-2023  Mingle   1.2  WMS-21499 Add boxno(ML01)                 */
/************************************************************************/      
CREATE    PROC [dbo].[isp_UCC_Carton_Label_109] (       
   @c_StorerKey    NVARCHAR(15),      
   @c_PickSlipNo   NVARCHAR(10),       
   @c_FromCartonNo NVARCHAR(10),      
   @c_ToCartonNo   NVARCHAR(10),       
   @c_Type         NVARCHAR(10) = '' )      
      
AS      
BEGIN      
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @b_debug INT      
      
   DECLARE       
      @nFromCartonNo         INT,      
      @nToCartonNo           INT,      
      @c_GetPickslipno       NVARCHAR(10),      
      @c_sku                 NVARCHAR(20),      
      @c_Externorderkey      NVARCHAR(50),       
      @c_packkey             NVARCHAR(20),      
      @n_Casecnt             INT,      
      @n_GetPQty             INT,      
      @n_PQty                INT,      
      @n_GetTTLQty           INT,      
      @n_TTLQty              INT,      
      @n_getctnno            INT,      
      @n_getCtnCount         INT,      
      @n_startCtn            INT,      
      @c_presku              NVARCHAR(20),       
      @n_cntsku              INT,                
      @c_facility            NVARCHAR(10),       
      @c_consigneekey        NVARCHAR(45),       
      @c_getcontact1         NVARCHAR(1)         
         
   DECLARE       
      @d_Trace_StartTime     DATETIME,       
      @d_Trace_EndTime       DATETIME,         
      @c_UserName            NVARCHAR(128),      
      @c_ResultRowCtn        NVARCHAR(20)         
                
   SET @b_debug = 0      
   SET @n_startCtn = 1                           
   SET @c_presku = ''                            
   SET @c_getcontact1 = 'Y'                      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()       
   SET @c_ResultRowCtn = '0'      
   SET @n_cntsku = 1      
     
   SET @nFromCartonNo = CAST( @c_FromCartonNo AS INT)      
   SET @nToCartonNo = CAST( @c_ToCartonNo AS INT)      
      
     
      
   CREATE TABLE #TEMPUCCLBL109 (      
      Rowid         INT IDENTITY (1,1) NOT NULL,      
      Storerkey     NVARCHAR(20),      
      OrderKey      NVARCHAR(10),      
      ExternOrdKey  NVARCHAR(20) NULL,      
      ExtenPOKey    NVARCHAR(20) NULL,      
      CCompany      NVARCHAR(45) NULL,      
      CAddress      NVARCHAR(250) NULL,      
      CCityState    NVARCHAR(100) NULL,      
      CCountry      NVARCHAR(20) NULL,      
      ORDGrp        NVARCHAR(20) NULL,               
      Pickslipno    NVARCHAR(10),      
      labelno       NVARCHAR(20) NULL,      
      SKU           NVARCHAR(20),      
      HFlag         NVARCHAR(5),      
      PQty          NVARCHAR(10),      
      TTLQty        NVARCHAR(10),      
      BoxNo         NVARCHAR(50) NULL,      
      OHRoute       NVARCHAR(20) NULL,                
      CtnNo         INT,                              
      Ctncount      INT,                              
      CContact1     NVARCHAR(50) NULL                 
   )      
      
   INSERT INTO #TEMPUCCLBL109      
   (         
      Storerkey,      
      OrderKey,      
      ExternOrdKey,      
      ExtenPOKey,      
      CCompany,      
      CAddress,      
      CCityState,      
      CCountry,      
      ORDGrp,          
      Pickslipno,      
      labelno,      
      SKU,      
      HFlag,      
      PQty,      
      TTLQty,      
      BoxNo,      
      OHRoute,         
      CtnNo ,      
      Ctncount,           
      CContact1        
   )      
      
   SELECT ORDERS.storerkey,      
          ORDERS.orderkey,       
          RTRIM(ORDERS.ExternOrderKey),      
          ORDERS.ExternPOKey,      
          ORDERS.C_Company,      
          cAddress  = (ISNULL(RTRIM(ORDERS.C_Address1),'') + ' ' +ISNULL(RTRIM(ORDERS.C_Address2),'')       
                      + ' ' + ISNULL(RTRIM(ORDERS.C_Address3),'') + ' ' + ISNULL(RTRIM(ORDERS.C_Address4),'')),      
          ccitystate=( ISNULL(RTRIM(ORDERS.C_City),'') + ' ' + ISNULL(RTRIM(ORDERS.C_state),'') + ' ' + ISNULL(RTRIM(ORDERS.C_Zip),'')) ,      
          ORDERS.C_Country      
          ,ORDERS.OrderGroup,      
          PACKHEADER.PickSlipNo,      
          PACKDETAIL.LabelNo,       
          PACKDETAIL.SKU,      
          SKU.HazardousFlag,      
          0,      
          0,      
          '',      
          ORDERS.Route,      
          PACKDETAIL.CartonNo,      
          SUM(PACKDETAIL.qty) OVER (PARTITION BY PACKDETAIL.sku ORDER BY PACKDETAIL.adddate) / p.casecnt,      
          ORDERS.c_contact1      
   FROM ORDERS ORDERS (NOLOCK)       
   JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)      
   JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)        
   JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)      
   JOIN PACK p (NOLOCK) ON p.packkey=sku.packkey      
   WHERE ORDERS.StorerKey = @c_StorerKey       
   AND PACKHEADER.PickSlipNo = @c_PickSlipNo       
   AND PACKDETAIL.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo       
   GROUP BY ORDERS.storerkey,      
            ORDERS.orderkey,       
            ORDERS.ExternOrderKey,      
            ORDERS.ExternPOKey,      
            ORDERS.C_Company,      
            ORDERS.C_Address1,       
            ORDERS.C_Address2,      
            ORDERS.C_Address3,      
            ORDERS.C_Address4,        
            ORDERS.C_City,       
            ORDERS.C_State,       
            ORDERS.C_Zip,       
            ORDERS.C_Country,       
            ORDERS.OrderGroup,      
            PACKHEADER.PickSlipNo,      
            PACKDETAIL.LabelNo,       
            PACKDETAIL.SKU,      
            SKU.HazardousFlag,      
            ORDERS.Route ,      
            PACKDETAIL.AddDate,      
            PACKDETAIL.qty,      
            p.casecnt,      
            PACKDETAIL.CartonNo,     
            ORDERS.c_contact1      
                
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
   SELECT DISTINCT Pickslipno,sku,ExternOrdKey,CtnNo,Ctncount         
   FROM   #TEMPUCCLBL109          
   WHERE pickslipno = @c_PickSlipNo      
   AND Storerkey = @c_StorerKey        
   ORDER BY SKU      
        
   OPEN CUR_RESULT         
           
   FETCH NEXT FROM CUR_RESULT INTO @c_GetPickslipno,@c_sku,@c_Externorderkey,@n_getctnno ,@n_getCtnCount         
           
   WHILE @@FETCH_STATUS <> -1        
   BEGIN           
      SELECT @n_startCtn = MIN(cartonno)      
      FROM   PACKDETAIL PD WITH (NOLOCK)      
      WHERE  PD.PickSlipNo = @c_GetPickslipno      
      AND sku = @c_sku      
      
      SELECT @c_packkey = Packkey      
      FROM   SKU(NOLOCK)      
      WHERE  SKU       = @c_sku      
      AND StorerKey  = @c_StorerKey      
      
      SELECT @n_Casecnt = Casecnt      
      FROM   PACK P WITH (NOLOCK)      
      WHERE  P.PackKey = @c_packkey      
       
      SELECT @n_GetPQty = SUM(qty)      
      FROM PACKDETAIL PD WITH (NOLOCK)      
      WHERE PD.PickSlipNo = @c_GetPickslipno      
      AND sku = @c_sku      
      AND PD.CartonNo BETWEEN @n_startCtn AND @n_getctnno      
      GROUP BY PD.SKU      
            
      IF @n_Casecnt IS NULL OR @n_Casecnt=0      
      BEGIN      
         SET @n_Casecnt = 1      
      END      
          
      SET @n_PQty = @n_GetPQty/@n_Casecnt      
          
      SELECT @n_GetTTLQty = SUM(OD.QtyAllocated + OD.QtyPicked)      
      FROM ORDERDETAIL OD WITH (NOLOCK)      
      WHERE OD.ExternOrderKey=@c_Externorderkey      
      AND od.Sku = @c_sku      
      AND od.StorerKey=@c_StorerKey       
      
      SET @n_TTLQty = @n_GetTTLQty/@n_Casecnt      
      
      SET @c_facility = ''        
      SET @c_consigneekey = ''        
      SET @c_getcontact1 = 'Y'        
             
      SELECT TOP 1 @c_facility = facility        
                 , @c_consigneekey = consigneekey        
      FROM ORDERS (nolock)        
      WHERE externorderkey = @c_Externorderkey        
      AND storerkey = @c_StorerKey        
           
      IF (@c_facility='WGQAP' and @c_consigneekey='1096')  OR         
         (@c_facility='YPCN1' and @c_consigneekey='1098') OR          
         (@c_facility='BULIM' and @c_consigneekey='1096')         
      BEGIN        
         SET @c_getcontact1 = 'Y'        
      END        
      ELSE        
      BEGIN        
         SET @c_getcontact1 = 'N'        
      END        
      
      UPDATE #TEMPUCCLBL109      
      SET PQTY   = CONVERT(Nvarchar(10),@n_PQty),      
          TTLQty = CONVERT(Nvarchar(10),@n_TTLQty),      
          BoxNo  = CONVERT(Nvarchar(10),@n_PQty) + ' of ' + CONVERT(Nvarchar(10),@n_TTLQty),      
          CContact1 = CASE WHEN @c_getcontact1 = 'N' THEN '' ELSE CContact1 END      
      WHERE Pickslipno=@c_PickSlipNo      
      AND SKU = @c_sku      
      AND ExternOrdKey=@c_Externorderkey        
      AND CtnNo = @n_getctnno        
          
      SET @c_packkey = ''      
      SET @n_Casecnt = 1      
      SET @n_GetPQty = 0      
      SET @n_PQty = 0      
      SET @n_TTLQty = 0      
      SET @n_GetTTLQty = 0      
      SET @c_presku = @c_sku      
          
      FETCH NEXT FROM CUR_RESULT INTO @c_GetPickslipno,@c_sku,@c_Externorderkey ,@n_getctnno,@n_getCtnCount        
   END          
   CLOSE CUR_RESULT      
   DEALLOCATE CUR_RESULT    
     
   IF @c_Type = 'SSCC'      
   BEGIN       
      GOTO SSCC_Label      
   END      
   ELSE IF @c_Type = 'H'      
   BEGIN      
      SELECT TOP 1 @c_StorerKey          
                 , @c_PickSlipNo        
                 , @c_FromCartonNo      
                 , @c_ToCartonNo        
                 , CASE WHEN ISNULL(CL.Code,'') = OH.ConsigneeKey THEN 'Y' ELSE 'N' END AS SSCCLabel      
      FROM PACKHEADER PH (NOLOCK)      
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno      
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = PH.ORDERKEY      
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'LGAMZNLBL'       
                                    AND CL.Code = OH.ConsigneeKey AND CL.Storerkey = OH.StorerKey      
      WHERE PH.Storerkey = @c_StorerKey      
      AND PH.PickSlipNo = @c_PickSlipNo      
      AND PD.CartonNo BETWEEN CAST(@c_FromCartonNo AS INT) AND CAST(@c_ToCartonNo AS INT)      
            
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))       
      
      GOTO QUIT_SP      
   END      
             
   SET @n_cntsku = 1          
   SELECT @n_cntsku = COUNT(DISTINCT sku)      
   FROM #TEMPUCCLBL109      
   WHERE Pickslipno= @c_PickSlipNo      
      
   IF @n_cntsku > 1      
   BEGIN      
      SELECT TOP 1 Pickslipno,      
                   labelno,      
                   ExternOrdKey,      
                   ExtenPOKey,      
                   Storerkey,      
                   CCompany,      
                   CAddress,      
                   CCityState,      
                   CCountry,      
                   ORDGrp,      
                   'MIX-' + CONVERT(NVARCHAR(5),@n_cntsku)  SKU,      
                   CASE WHEN HFlag = 'Y' THEN '*' ELSE '' END AS Hflag,      
                   CASE WHEN ORDGrp = 'S01' THEN ' 'ELSE PQty END AS PQty,      
                   CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE TTLQty END  AS TTLQty,      
                   OrderKey,      
                   CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE BoxNo END  AS BoxNo,      
                   OHRoute,      
                   CContact1      
      FROM #TEMPUCCLBL109 AS t       
      ORDER BY t.Pickslipno,t.SKU      
              
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))       
   END          
   ELSE      
 BEGIN      
      SELECT Pickslipno,      
             labelno,      
             ExternOrdKey,      
             ExtenPOKey,      
             Storerkey,      
             CCompany,      
             CAddress,      
             CCityState,      
             CCountry,      
             ORDGrp,      
             SKU,      
             CASE WHEN HFlag = 'Y' THEN '*' ELSE '' END AS Hflag,      
             CASE WHEN ORDGrp = 'S01' THEN ' 'ELSE PQty END AS PQty,      
             CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE TTLQty END  AS TTLQty,      
             OrderKey,      
             CASE WHEN ORDGrp = 'S01' THEN ' ' ELSE BoxNo END  AS BoxNo,      
             OHRoute,      
             CContact1      
      FROM #TEMPUCCLBL109 AS t       
      ORDER BY t.Pickslipno,t.SKU      
           
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))       
 END   
   
   
      
SSCC_Label:      
   IF @c_Type = 'SSCC'      
   BEGIN       
      SELECT F.Descr      
           , ISNULL(TRIM(F.Address1),'') + ISNULL(TRIM(F.Address2),'') +       
             ISNULL(TRIM(F.Address3),'') + ISNULL(TRIM(F.Address4),'') AS FAddresses      
           , ISNULL(OH.C_Company,'')  AS C_Company      
           , ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') +       
             ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'') AS C_Addresses      
           , OH.ExternPOKey      
           , ISNULL(OD.UserDefine05,'') AS UserDefine05      
           , S.AltSKU      
           , PD.Qty      
           , PD.CartonNo      
           , PD.LabelNo      
           , SN.SerialNo      
           , 'China' AS COO   
           , T.BoxNo AS BOXNO --ML01  
      FROM ORDERS OH (NOLOCK)      
      --CROSS APPLY (SELECT TOP 1 ORDERDETAIL.UserDefine05              --KY01       
      --             FROM ORDERDETAIL (NOLOCK)      
      --             WHERE ORDERDETAIL.OrderKey = OH.OrderKey) AS OD      
      JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY      
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno      
      CROSS APPLY (SELECT TOP 1 ORDERDETAIL.UserDefine05    --KY01    
      FROM ORDERDETAIL (NOLOCK)                             --KY01    
      WHERE ORDERDETAIL.OrderKey = OH.OrderKey              --KY01    
      AND ORDERDETAIL.STORERKEY = PD.STORERKEY   --KY01    
      AND ORDERDETAIL.SKU = PD.SKU) AS OD                   --KY01    
      JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility      
      JOIN SKU S (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU    
      JOIN #TEMPUCCLBL109 T (NOLOCK) ON T.Pickslipno = PH.PickSlipNo --ML01   
      LEFT JOIN SerialNo SN (NOLOCK) ON SN.StorerKey = PH.StorerKey AND SN.PickSlipNo = PD.PickSlipNo       
                                AND SN.CartonNo = PD.CartonNo      
      WHERE OH.StorerKey = @c_StorerKey       
      AND PH.PickSlipNo = @c_PickSlipNo       
      AND PD.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo       
      ORDER BY PH.Pickslipno, PD.CartonNo, PD.SKU      
       
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10))        
   END      
      
QUIT_SP:      
   SET @d_Trace_EndTime = getdate()      
         
   --EXEC isp_InsertTraceInfo             
   --   @c_TraceCode = 'CartonLabel_104',            
   --   @c_TraceName = 'isp_UCC_Carton_Label_109',            
   --   @c_starttime = @d_Trace_StartTime,            
   --   @c_endtime   = @d_Trace_EndTime,            
   --   @c_step1     = @c_UserName,            
   --   @c_step2 = @c_StorerKey,                   
   --   @c_step3 = @c_PickSlipNo,                  
   --   @c_step4 = @c_FromCartonNo,                
   --   @c_step5 = @c_ToCartonNo,                  
   --   @c_col1 = @c_Type,                     
   --   @c_col2 = @c_ResultRowCtn,            
   --   @c_col3 = @n_cntsku,            
   --   @c_col4 = '',            
   --   @c_col5 = '',            
   --   @b_Success = 1,            
   --   @n_Err = 0,            
   --   @c_ErrMsg = ''                        
            
END   

GO