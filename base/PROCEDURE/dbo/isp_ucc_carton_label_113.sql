SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/
/* Store Procedure: isp_UCC_Carton_Label_113                            */
/* Creation Date: 29-Mar-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19336 - [CN] LOGIUS SSCC Carton Label                   */
/*          Copy AND modify from isp_UCC_Carton_Label_109               */
/*                                                                      */
/* Input Parameters: @c_StorerKey - StorerKey,                          */
/*                   @c_PickSlipNo - Pickslipno,                        */
/*                   @c_FromCartonNo - From CartonNo,                   */
/*                   @c_ToCartonNo - To CartonNo,                       */
/*                   @c_Type - Type                                     */
/*                                                                      */
/* Usage: Call by dw = r_dw_ucc_carton_label_113                        */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 29-Mar-2021  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_113] ( 
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

   DECLARE @b_debug INT

   DECLARE 
      @n_FromCartonNo        INT,
      @n_ToCartonNo          INT,
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

   SET @n_FromCartonNo = CAST(@c_FromCartonNo AS int)
   SET @n_ToCartonNo = CAST(@c_ToCartonNo AS int)

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
      AND PD.CartonNo BETWEEN CAST(@c_FromCartonNo as INT) AND CAST(@c_ToCartonNo as INT)
      
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10)) 

      GOTO QUIT_SP
   END

   CREATE TABLE #TEMPUCCLBL113 (
      Rowid	        INT IDENTITY (1,1) NOT NULL,
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

   INSERT INTO #TEMPUCCLBL113
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
   AND PACKDETAIL.CartonNo BETWEEN @n_FromCartonNo AND @n_ToCartonNo 
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
   FROM   #TEMPUCCLBL113    
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
     
      IF (@c_facility='WGQAP' AND @c_consigneekey='1096')  OR   
         (@c_facility='YPCN1' AND @c_consigneekey='1098') OR    
         (@c_facility='BULIM' AND @c_consigneekey='1096')   
      BEGIN  
         SET @c_getcontact1 = 'Y'  
      END  
      ELSE  
      BEGIN  
         SET @c_getcontact1 = 'N'  
      END  

      UPDATE #TEMPUCCLBL113
      SET PQTY   = CONVERT(Nvarchar(10),@n_PQty),
          TTLQty = CONVERT(Nvarchar(10),@n_TTLQty),
          BoxNo  = CONVERT(Nvarchar(10),@n_PQty) + ' of ' + CONVERT(Nvarchar(10),@n_TTLQty),
          CContact1 = CASE WHEN @c_getcontact1 = 'N' THEN '' ELSE CContact1 END
      WHERE Pickslipno = @c_PickSlipNo
      AND SKU = @c_sku
      AND ExternOrdKey = @c_Externorderkey  
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
       
   SET @n_cntsku = 1    
   SELECT @n_cntsku = COUNT(DISTINCT sku)
   FROM #TEMPUCCLBL113
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
      FROM #TEMPUCCLBL113 AS t 
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
      FROM #TEMPUCCLBL113 AS t 
      ORDER BY t.Pickslipno,t.SKU
     
      SET @c_ResultRowCtn = CAST(@@ROWCOUNT AS VARCHAR(10)) 
	END	

SSCC_Label:
   IF @c_Type = 'SSCC'
   BEGIN 
      CREATE TABLE #TMP_SSCCLBL (
         Descr             NVARCHAR(100)
       , FAddresses        NVARCHAR(500)
       , C_Company         NVARCHAR(100)
       , C_Addresses       NVARCHAR(500)
       , ExternPOKey       NVARCHAR(50)
       , ExtendedField08   NVARCHAR(100)
       , MANUFACTURERSKU   NVARCHAR(20)
       , Qty               INT
       , CartonNo          INT
       , LabelNo           NVARCHAR(20)
       , SKU               NVARCHAR(20)
       , COO               NVARCHAR(50)
       , ExternOrderKey    NVARCHAR(50)
       , CtnCount          INT
       , Pickslipno        NVARCHAR(10)
       , Storerkey         NVARCHAR(15)
       , ActualCtnNo       INT
      )
      INSERT INTO #TMP_SSCCLBL
      SELECT F.Descr
           , ISNULL(TRIM(F.Address1),'') + CHAR(13) + ISNULL(TRIM(F.Address2),'') + CHAR(13) + 
             ISNULL(TRIM(F.Address3),'') + CHAR(13) + ISNULL(TRIM(F.Address4),'') AS FAddresses
           , ISNULL(OH.C_Company,'')  AS C_Company
           , ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') + 
             ISNULL(OH.C_Address3,'') + ISNULL(OH.C_Address4,'') + CHAR(13) +
             ISNULL(OH.C_City,'') + ' ' + ISNULL(OH.C_State,'') + ' ' + 
             ISNULL(OH.C_Zip,'') + ' ' + ISNULL(OH.C_Country,'') AS C_Addresses
           , OH.ExternPOKey
           , ISNULL(OD.UserDefine05,'') AS ExtendedField08
           , ISNULL(S.MANUFACTURERSKU,'') AS MANUFACTURERSKU
           , PD.Qty
           , PD.CartonNo
           , PD.LabelNo
           , PD.SKU
           , 'China' AS COO
           , OH.ExternOrderKey
           , 0
           , PH.PickSlipNo
           , PH.StorerKey
           , (Row_Number() OVER (PARTITION BY PD.SKU ORDER BY PD.CartonNo ASC)) AS ActualCtnNo
      FROM ORDERS OH (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
      JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey AND OD.SKU = PD.SKU 
                                  AND OD.StorerKey = PD.StorerKey
      JOIN FACILITY F (NOLOCK) ON F.Facility = OH.Facility
      JOIN SKU S (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU
      WHERE OH.StorerKey = @c_StorerKey 
        AND PH.PickSlipNo = @c_PickSlipNo 
        --AND PD.CartonNo BETWEEN @n_FromCartonNo AND @n_ToCartonNo 
      ORDER BY PH.Pickslipno, PD.CartonNo, PD.SKU

      DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT T.Pickslipno, T.SKU, T.ExternOrderKey, ISNULL(P.CaseCnt,1)
      FROM #TMP_SSCCLBL T WITH (NOLOCK)
      JOIN SKU S (NOLOCK) ON S.StorerKey = T.Storerkey AND S.SKU = T.SKU
      JOIN PACK P (NOLOCK) ON P.PackKey = S.Packkey
      WHERE T.Pickslipno = @c_PickSlipNo 
      ORDER BY T.SKU
      
      OPEN CUR_RESULT   
        
      FETCH NEXT FROM CUR_RESULT INTO @c_GetPickslipno, @c_sku, @c_Externorderkey, @n_Casecnt 
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN     
         SELECT @n_GetTTLQty = SUM(OD.QtyAllocated + OD.QtyPicked)
         FROM ORDERDETAIL OD WITH (NOLOCK)
         WHERE OD.ExternOrderKey = @c_Externorderkey
         AND OD.Sku = @c_sku
         AND OD.StorerKey = @c_StorerKey	

         SET @n_TTLQty = @n_GetTTLQty / @n_Casecnt
      
         UPDATE #TMP_SSCCLBL
         SET CtnCount = @n_TTLQty
         WHERE Pickslipno = @c_PickSlipNo
         AND SKU = @c_sku
         AND ExternOrderKey = @c_Externorderkey   

         FETCH NEXT FROM CUR_RESULT INTO @c_GetPickslipno, @c_sku, @c_Externorderkey, @n_Casecnt
      END    
      CLOSE CUR_RESULT
      DEALLOCATE CUR_RESULT

      SELECT  Descr           
            , FAddresses      
            , C_Company       
            , C_Addresses     
            , ExternPOKey     
            , ExtendedField08 
            , MANUFACTURERSKU 
            , Qty             
            , ActualCtnNo        
            , LabelNo         
            , SKU             
            , COO             
            , ExternOrderKey  
            , CtnCount        
            , Pickslipno      
            , Storerkey       
      FROM #TMP_SSCCLBL TS
      WHERE TS.CartonNo BETWEEN @n_FromCartonNo AND @n_ToCartonNo 
      ORDER BY TS.SKU, TS.CartonNo
   END

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_SSCCLBL') IS NOT NULL
      DROP TABLE #TMP_SSCCLBL

   IF OBJECT_ID('tempdb..#TEMPUCCLBL113') IS NOT NULL
      DROP TABLE #TEMPUCCLBL113

   IF CURSOR_STATUS('LOCAL', 'CUR_RESULT') IN (0 , 1)
   BEGIN
      CLOSE CUR_RESULT
      DEALLOCATE CUR_RESULT   
   END
END

GO