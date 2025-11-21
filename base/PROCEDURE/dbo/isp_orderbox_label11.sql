SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Orderbox_Label11                                    */  
/* Creation Date: 24-Jun-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-13900 [TW] MLB_New Fn1637 Despatch Manifest             */  
/*        :                                                             */  
/* Called By:r_dw_Orderbox_Label11                                      */  
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
  
CREATE PROC [dbo].[isp_Orderbox_Label11]  
            @c_Storerkey     NVARCHAR(15),
            @c_Containerkey  NVARCHAR(20)
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
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 

   IF(@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT ISNULL(CL.UDF01,'') AS Logo,
             ISNULL(CD.ContainerKey, '') AS ContainerKey, 
             ISNULL(MB.ExternMBOLkey, '') AS  ExternMBOLkey, 
             CONVERT(NVARCHAR(10),Getdate(),111) AS  ShipDate, 
             ISNULL(OH.Door, '') AS Door, 
             CONVERT(NVARCHAR(10),Getdate(),120) AS  PrintDate, 
             ISNULL(OH.C_Company, '') AS C_Company, 
             LTRIM(RTRIM(ISNULL(OH.C_Address1, ''))) +  LTRIM(RTRIM(ISNULL(OH.C_Address2, ''))) AS  C_Addresses, 
             ISNULL(OH.OrderKey, '') AS OrderKey, 
             CASE WHEN OH.[Type] = 'ECOM' THEN OH.TrackingNo ELSE PH.PickSlipNo END AS Pickslipno,
             CONVERT(NVARCHAR(10),LP.lpuserdefdate01,111) AS lpuserdefdate01, 
             ISNULL(OH.Storerkey, '') AS Storerkey, 
             ISNULL(CL.Notes,'') AS Notes,
             PD.LabelNo AS LabelNo
      INTO #TEMP_Result
      FROM ORDERS OH WITH (NOLOCK)  
      JOIN PACKHEADER PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey AND OH.STORERKEY = PH.STORERKEY)  
      JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
      JOIN MBOL MB WITH (NOLOCK) ON (MB.MBOLKey = MD.MBOLKey)
      JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON (MB.EXTERNMBOLKEY = CD.PALLETKEY)
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
      JOIN LOADPLAN LP WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'MnfstCfg' AND CL.Storerkey = OH.Storerkey 
                                          AND CL.Code = '01'
                                          AND CL.code2 = '1637')
      WHERE OH.Storerkey = @c_Storerkey AND CD.ContainerKey = @c_Containerkey
   END
      
QUIT_SP:  
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

   SELECT  Logo
         , ContainerKey
         , ExternMBOLkey
         , ShipDate
         , Door
         , PrintDate
         , C_Company
         , C_Addresses
         , OrderKey
         , Pickslipno
         , lpuserdefdate01
         , Storerkey
         , Notes          
         , COUNT(DISTINCT LabelNo) AS LabelNoCount
         , N'貨櫃號碼: ' AS t1
         , N'棧板編號: ' AS t2
         , N'出貨日期: ' AS t3
         , N'貨運行: ' AS t4
         , N'列印時間' AS t5
         , N'Page' AS t6
         , N'收件人' AS t7
         , N'地址' AS t8
         , N'WMS訂單' AS t9
         , N'箱號(條碼)' AS t10
         , N'件數' AS t11
         , N'指定到貨日' AS t12
         , N'訂單數小計' AS t13
         , N'件數小計' AS t14
         , N'總訂單數' AS t15
         , N'共_______板' AS t16
         , N'總件數' AS t17
         , N'倉管簽名: ' AS t18
         , N'司機簽名: ' AS t19
         , N'貨主: ' AS t20
   FROM #TEMP_Result 
   GROUP BY  Logo
           , ContainerKey
           , ExternMBOLkey
           , ShipDate
           , Door
           , PrintDate
           , C_Company
           , C_Addresses
           , OrderKey
           , Pickslipno
           , lpuserdefdate01
           , Storerkey
           , Notes      
  
   IF OBJECT_ID('tempdb..#TEMP_Result') IS NOT NULL
      DROP TABLE #TEMP_Result

   
END -- procedure


GO