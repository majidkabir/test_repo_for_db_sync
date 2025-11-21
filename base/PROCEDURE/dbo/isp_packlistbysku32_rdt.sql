SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_PackListBySku32_rdt                            */  
/* Creation Date: 02-Sep-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-20690 - [CN]BALMAIN_B2C_PackingList                     */  
/*                                                                      */  
/* Called By: report dw = r_dw_packing_list_by_sku32_rdt                */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver.  Purposes                                 */  
/* 02-Sep-2022  WLChooi  1.0   DevOps Combine Script                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListBySku32_rdt] (  
      @c_Pickslipno NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey     NVARCHAR(10)
         , @n_Continue     INT = 1
         , @n_MaxLine      INT = 13
  
   SET @c_Orderkey = @c_Pickslipno  
  
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)  
   BEGIN  
      SELECT @c_Orderkey = OrderKey  
      FROM PACKHEADER (NOLOCK)  
      WHERE PickSlipNo = @c_Pickslipno  
   END  
   
   CREATE TABLE #TMP_PACKLIST (
      DeliveryDate   DATETIME
    , M_Company      NVARCHAR(100)
    , C_Contact1     NVARCHAR(100)
    , C_Addr         NVARCHAR(500)
    , DESCR          NVARCHAR(250)
    , Sku            NVARCHAR(20)
    , Qty            INT
    , UserDefine02   INT
    , Long           NVARCHAR(250)
    , Notes          NVARCHAR(250)
    , Notes2         NVARCHAR(250)
    , Footer1        NVARCHAR(250)
    , Footer2        NVARCHAR(250)
    , RecGrp         INT
   )

   INSERT INTO #TMP_PACKLIST
   SELECT OH.DeliveryDate
        , ISNULL(OH.M_Company,'')  AS M_Company
        , ISNULL(OH.C_Contact1,'') AS C_Contact1
        , ISNULL(TRIM(OH.C_State),'') + ISNULL(TRIM(OH.C_City),'') + ISNULL(TRIM(OH.C_Address1),'') + 
          ISNULL(TRIM(OH.C_Address2),'') + ISNULL(TRIM(OH.C_Address3),'') + ISNULL(TRIM(OH.C_Address4),'') AS C_Addr
        , ISNULL(TRIM(S.DESCR),'') AS DESCR
        , TRIM(PD.Sku) AS Sku
        , SUM(PD.Qty) AS Qty
        , CASE WHEN ISNUMERIC(TRIM(OD.UserDefine02)) = 1 THEN CAST(TRIM(OD.UserDefine02) AS FLOAT) ELSE 0.00 END AS UserDefine02
        , ISNULL(CL.Long,N'BALMAIN官方旗舰店') AS Long
        , ISNULL(CL.Notes,N'BALMAIN_QRCode.jpg')  AS Notes
        , ISNULL(CL.Notes2,N'BALMAIN_PARIS.png') AS Notes2
        ,N'亲爱的顾客，感谢您选购BALMAIN。为了保障您的权益，请妥善保管本货运单，退换货请具体参考背面《在线退换货说明》或咨询店铺客服。' AS Footer1
        ,N'客服服务时间：周一至周日9am – 8pm (春节假期除外)' AS Footer2
        , (Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey ASC) - 1 ) / @n_MaxLine + 1 AS RecGrp
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.Orderkey = OD.Orderkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber
                              --AND PD.SKU = OD.Sku
   JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.Sku
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'BALDN' AND CL.Storerkey = OH.StorerKey 
                                 AND CL.code2 = OH.Salesman
   WHERE OH.OrderKey = @c_Orderkey
   GROUP BY OH.DeliveryDate
          , ISNULL(OH.M_Company,'')
          , ISNULL(OH.C_Contact1,'')
          , ISNULL(TRIM(OH.C_State),'') + ISNULL(TRIM(OH.C_City),'') + ISNULL(TRIM(OH.C_Address1),'') + 
            ISNULL(TRIM(OH.C_Address2),'') + ISNULL(TRIM(OH.C_Address3),'') + ISNULL(TRIM(OH.C_Address4),'')
          , ISNULL(TRIM(S.DESCR),'')
          , TRIM(PD.Sku)
          , CASE WHEN ISNUMERIC(TRIM(OD.UserDefine02)) = 1 THEN CAST(TRIM(OD.UserDefine02) AS FLOAT) ELSE 0.00 END
          , ISNULL(CL.Long,N'BALMAIN官方旗舰店')  
          , ISNULL(CL.Notes,N'BALMAIN_QRCode.jpg') 
          , ISNULL(CL.Notes2,N'BALMAIN_PARIS.png')
          , OH.OrderKey

   SELECT TP.DeliveryDate 
        , TP.M_Company    
        , TP.C_Contact1   
        , TP.C_Addr       
        , TP.DESCR        
        , TP.Sku          
        , TP.Qty          
        , TP.UserDefine02 
        , TP.Long         
        , TP.Notes        
        , TP.Notes2       
        , TP.Footer1      
        , TP.Footer2      
        , TP.RecGrp  
   FROM #TMP_PACKLIST TP

END  

GO