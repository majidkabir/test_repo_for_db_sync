SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_138_rdt                                */  
/* Creation Date: 24-JUL-2023                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-22886 -[CN] Desigual B2B Packing list_New               */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_138_rdt                                 */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 24-JUL-2023  CSCHONG   1.1 Devops Scripts Combine                    */
/************************************************************************/  
CREATE   PROC [dbo].[isp_Packing_List_138_rdt]
            @c_Pickslipno    NVARCHAR(15),     
            @c_cartonNo      NVARCHAR(5) = ''
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
         , @c_SummPAck        NVARCHAR(5)


    DECLARE   @c_A1              NVARCHAR(80)  
            , @c_A2              NVARCHAR(80)  
            , @c_A3              NVARCHAR(80)  
            , @c_A4              NVARCHAR(80)  
            , @c_A5              NVARCHAR(80)  
            , @c_A6              NVARCHAR(80)  
            , @c_A7              NVARCHAR(80)  
            , @c_B1              NVARCHAR(80)  
            , @c_B2              NVARCHAR(80)  
            , @c_B3              NVARCHAR(80)  
            , @c_B4              NVARCHAR(80)  
            , @c_B5              NVARCHAR(80)  
            , @c_B6              NVARCHAR(80)  
            , @c_B7              NVARCHAR(80) 
            , @c_B8              NVARCHAR(80) 
            , @c_B9              NVARCHAR(80) 
            , @c_B10             NVARCHAR(80) 
            , @c_B11             NVARCHAR(80)
            , @c_B12             NVARCHAR(80)
            , @c_B13             NVARCHAR(80)
            , @c_C1              NVARCHAR(80)  
            , @c_C2              NVARCHAR(80)  
            , @c_C3              NVARCHAR(80)  
            , @c_C4              NVARCHAR(80)  
            , @c_C5              NVARCHAR(80)  
            , @c_C6              NVARCHAR(80)  
            , @c_C7              NVARCHAR(80) 
            , @c_D1              NVARCHAR(80)    
            , @c_D3              NVARCHAR(80)   
            , @c_D5              NVARCHAR(80)  
            , @c_D6              NVARCHAR(500)  
            , @c_ORDTYPE         NVARCHAR(5)
            , @c_getstorerkey    NVARCHAR(20) = N''  
            , @c_getcountry      NVARCHAR(45) = N''  
            , @c_Orderkey        NVARCHAR(10) = ''
            , @n_TTLBox          INT 

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 
   SET @c_SummPAck  = 'N'
   SET @c_ORDTYPE   = ''


        SELECT TOP 1 @c_Orderkey = PH.Orderkey
        FROM PACKHEADER PH WITH (NOLOCK)
        WHERE PH.PickSlipNo = @c_pickslipno


   SELECT TOP 1 @c_getcountry=OH.C_Country
               ,@c_getstorerkey = OH.StorerKey
   FROM ORDERS OH WITH (NOLOCK)  
   WHERE oh.OrderKey=@c_Orderkey


 SELECT @n_TTLBox = COUNT(DISTINCT PD.LabelNo)
        FROM dbo.PackDetail PD WITH (NOLOCK)
        WHERE PD.PickSlipNo = @c_pickslipno
  

      SELECT @c_A1 = ISNULL(MAX(CASE WHEN CL.Code = 'A1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A2 = ISNULL(MAX(CASE WHEN CL.Code = 'A2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A3 = ISNULL(MAX(CASE WHEN CL.Code = 'A3'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A4 = ISNULL(MAX(CASE WHEN CL.Code = 'A4'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A5 = ISNULL(MAX(CASE WHEN CL.Code = 'A5'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A6 = ISNULL(MAX(CASE WHEN CL.Code = 'A6'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A7 = ISNULL(MAX(CASE WHEN CL.Code = 'A7'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B1 = ISNULL(MAX(CASE WHEN CL.Code = 'B1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B2 = ISNULL(MAX(CASE WHEN CL.Code = 'B2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B3 = ISNULL(MAX(CASE WHEN CL.Code = 'B3' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B4 = ISNULL(MAX(CASE WHEN CL.Code = 'B4' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B5 = ISNULL(MAX(CASE WHEN CL.Code = 'B5' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B6 = ISNULL(MAX(CASE WHEN CL.Code = 'B6' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B7 = ISNULL(MAX(CASE WHEN CL.Code = 'B7' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B8 = ISNULL(MAX(CASE WHEN CL.Code = 'B8' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B9 = ISNULL(MAX(CASE WHEN CL.Code = 'B9' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B10= ISNULL(MAX(CASE WHEN CL.Code = 'B10' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B11= ISNULL(MAX(CASE WHEN CL.Code = 'B11' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B12= ISNULL(MAX(CASE WHEN CL.Code = 'B12' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B13= ISNULL(MAX(CASE WHEN CL.Code = 'B13' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C1 = ISNULL(MAX(CASE WHEN CL.Code = 'C1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C2 = ISNULL(MAX(CASE WHEN CL.Code = 'C2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C3 = ISNULL(MAX(CASE WHEN CL.Code = 'C3' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C4 = ISNULL(MAX(CASE WHEN CL.Code = 'C4' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C5 = ISNULL(MAX(CASE WHEN CL.Code = 'C5' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C6 = ISNULL(MAX(CASE WHEN CL.Code = 'C6' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C7 = ISNULL(MAX(CASE WHEN CL.Code = 'C7' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D1 = ISNULL(MAX(CASE WHEN CL.Code = 'D1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D3 = ISNULL(MAX(CASE WHEN CL.Code = 'D3' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D5 = ISNULL(MAX(CASE WHEN CL.Code = 'D5' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D6 = ISNULL(MAX(CASE WHEN CL.Code = 'D6' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE  CL.LISTNAME='DSGLB2BPKL' AND CL.code2=@c_getcountry AND CL.Storerkey = @c_getstorerkey
   
   SELECT LTRIM(RTRIM(ISNULL(OH.C_Zip,'''')))  AS C_Zip 
        , ISNULL(OH.C_Company,'') AS c_Company  
        , LTRIM(RTRIM(ISNULL(OH.Salesman,'''')))  AS salesman
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + ' ' + 
          LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) AS c_addresses
        , OH.C_Phone1  
        , @c_A2 AS A2  
        , @c_A3 AS A3
        , PD.SKU    
        , @c_A4 AS A4
        , (PADET.QTY) AS Qty 
        , S.DESCR 
        , LTRIM(RTRIM(ISNULL(OH.C_Country,'''')))  AS C_Country 
        , OH.LoadKey  
        , @c_A5 AS A5
        , @c_A6 AS A6
        , @c_A7 AS A7
        , @c_B8 AS B8
        , @c_B9 AS B9
        , @c_B10 AS B10
        , @c_B11 AS B11
        , @c_B12 AS B12
        , @c_B13 AS B13
        , LTRIM(RTRIM(ISNULL(OH.C_City,'''')))  AS C_City
        , LTRIM(RTRIM(ISNULL(OH.C_State,'''')))  AS C_State
        , @c_A1 AS A1  
        , LTRIM(RTRIM(ISNULL(OH.BuyerPO,'''')))  AS BuyerPO
        , PD.CartonNo
        , PD.LabelNo
        , @c_B1 AS B1
        , @c_B2 AS B2  
        , @c_B3 AS B3
        , @c_B4 AS B4
        , @c_B5 AS B5  
        , @c_B6 AS B6
        , @c_B7 AS B7
        , @c_C1 AS C1
        , @c_C2 AS C2  
        , @c_C3 AS C3
        , @c_C4 AS C4
        , @c_C5 AS C5  
        , @c_C6 AS C6
        , @c_C7 AS C7
        , @c_D1 AS D1 
        , @c_D3 AS D3
        , @c_D5 AS D5  
        , @c_D6 AS D6
        , PIF.Length  AS PLength
        , PIF.Width   AS PWidth
        , PIF.Height AS PHeight
        , S.ALTSKU
        , S.Style  
        , S.Color 
        , S.Size  
        , @n_TTLBox AS TTLBox
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PH.LoadKey = OH.LoadKey
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo                     
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OH.StorerKey
   LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   CROSS APPLY (SELECT pickslipno , cartonno, SUM(qty) AS qty FROM PACKDETAIL PAD WITH (NOLOCK) where PAD.PickSlipNo = PD.PickSlipNo 
    AND PAD.CartonNo=PD.CartonNo AND PAD.SKU=PD.sku GROUP BY pickslipno , cartonno) AS PADET
   WHERE PH.PickSlipNo = @c_Pickslipno
   AND PD.CartonNo = CAST(@c_cartonNo AS INT)  
   AND OH.DocType='N'
   GROUP BY LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + ' ' + 
            LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) 
           , ISNULL(OH.C_Company,'')   
           , LTRIM(RTRIM(ISNULL(OH.C_Country,'''')))  
           , LTRIM(RTRIM(ISNULL(OH.C_Zip,'''')))  
           , LTRIM(RTRIM(ISNULL(OH.C_City,'''')))  
           , LTRIM(RTRIM(ISNULL(OH.C_State,'''')))  
           , LTRIM(RTRIM(ISNULL(OH.Salesman,'''')))  
           , OH.C_Phone1 
           , S.DESCR
           , PD.SKU
           , LTRIM(RTRIM(ISNULL(OH.BuyerPO,'''')))  
           , OH.LoadKey
           , PD.CartonNo
           , PD.LabelNo
           , PIF.Length  
           , PIF.Width  
           , PIF.Height 
           , S.ALTSKU
           , S.Style 
           , S.Color 
           , S.Size   
           ,  (PADET.QTY) 
   ORDER BY S.ALTSKU


QUIT_SP:  

END -- procedure

GO