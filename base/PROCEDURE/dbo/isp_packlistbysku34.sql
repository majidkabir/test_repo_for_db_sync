SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_PackListBySku34                                     */  
/* Creation Date: 26-JUL-2023                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-22887 -[CN] Desigual B2C Packing list_New               */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_by_sku34                                */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 26-JUL-2023  CSCHONG   1.1 Devops Scripts Combine                    */
/************************************************************************/  
CREATE   PROC [dbo].[isp_PackListBySku34]
            @c_Pickslipno    NVARCHAR(15)
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


    DECLARE   @c_A2              NVARCHAR(80)  
            , @c_A3              NVARCHAR(80)  
            , @c_A4              NVARCHAR(80)  
            , @c_A5              NVARCHAR(80)  
            , @c_B1              NVARCHAR(80)  
            , @c_B2              NVARCHAR(80)  
            , @c_B8              NVARCHAR(80) 
            , @c_B9              NVARCHAR(80) 
            , @c_B10             NVARCHAR(80) 
            , @c_B14             NVARCHAR(80)
            , @c_C1              NVARCHAR(80)  
            , @c_C2              NVARCHAR(80)  
            , @c_C3              NVARCHAR(80)  
            , @c_C4              NVARCHAR(80)  
            , @c_C5              NVARCHAR(80)  
            , @c_C10             NVARCHAR(80)  
            , @c_C11             NVARCHAR(80) 
            , @c_D1              NVARCHAR(80)    
            , @c_D2              NVARCHAR(80)  
            , @c_D3              NVARCHAR(80)   
            , @c_D4              NVARCHAR(80)  
            , @c_D5              NVARCHAR(80)  
            , @c_D6              NVARCHAR(500)  
            , @c_D7              NVARCHAR(80)  
            , @c_D8              NVARCHAR(80)  
            , @c_D9              NVARCHAR(80)  
            , @c_D10             NVARCHAR(80)  
            , @c_D12             NVARCHAR(80) 
            , @c_D13             NVARCHAR(80) 
            , @c_D15             NVARCHAR(80) 
            , @c_ORDTYPE         NVARCHAR(5)
            , @c_getstorerkey    NVARCHAR(20) = N''  
            , @c_getcountry      NVARCHAR(45) = N''  
            , @c_Orderkey        NVARCHAR(10) = ''

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

  

      SELECT
             @c_A2 = ISNULL(MAX(CASE WHEN CL.Code = 'A2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A3 = ISNULL(MAX(CASE WHEN CL.Code = 'A3'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A4 = ISNULL(MAX(CASE WHEN CL.Code = 'A4'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A5 = ISNULL(MAX(CASE WHEN CL.Code = 'A5'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')     
            ,@c_B1 = ISNULL(MAX(CASE WHEN CL.Code = 'B1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B2 = ISNULL(MAX(CASE WHEN CL.Code = 'B2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')    
            ,@c_B8 = ISNULL(MAX(CASE WHEN CL.Code = 'B8' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B9 = ISNULL(MAX(CASE WHEN CL.Code = 'B9' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B10= ISNULL(MAX(CASE WHEN CL.Code = 'B10' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B14= ISNULL(MAX(CASE WHEN CL.Code = 'B14' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C1 = ISNULL(MAX(CASE WHEN CL.Code = 'C1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C2 = ISNULL(MAX(CASE WHEN CL.Code = 'C2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C3 = ISNULL(MAX(CASE WHEN CL.Code = 'C3' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C4 = ISNULL(MAX(CASE WHEN CL.Code = 'C4' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C5 = ISNULL(MAX(CASE WHEN CL.Code = 'C5' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C10 = ISNULL(MAX(CASE WHEN CL.Code = 'C10' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C11 = ISNULL(MAX(CASE WHEN CL.Code = 'C11' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D1 = ISNULL(MAX(CASE WHEN CL.Code = 'D1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D2 = ISNULL(MAX(CASE WHEN CL.Code = 'D2' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D3 = ISNULL(MAX(CASE WHEN CL.Code = 'D3' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D4 = ISNULL(MAX(CASE WHEN CL.Code = 'D4' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D5 = ISNULL(MAX(CASE WHEN CL.Code = 'D5' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D6 = ISNULL(MAX(CASE WHEN CL.Code = 'D6' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D7 = ISNULL(MAX(CASE WHEN CL.Code = 'D7' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D8 = ISNULL(MAX(CASE WHEN CL.Code = 'D8' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D9 = ISNULL(MAX(CASE WHEN CL.Code = 'D9' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D10 = ISNULL(MAX(CASE WHEN CL.Code = 'D10'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D12 = ISNULL(MAX(CASE WHEN CL.Code = 'D12'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D15= ISNULL(MAX(CASE WHEN CL.Code = 'D15' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_D13= ISNULL(MAX(CASE WHEN CL.Code = 'D13' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE  CL.LISTNAME='DSGLB2CPKL' AND CL.code2=@c_getcountry AND CL.Storerkey = @c_getstorerkey
   
   SELECT LTRIM(RTRIM(ISNULL(OH.C_Zip,'''')))  AS C_Zip
        , CONVERT(NVARCHAR(10),OH.OrderDate,105) AS ORDDate  
        , LTRIM(RTRIM(ISNULL(OH.C_contact1,'''')))  AS C_contact
        , LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + ' ' + 
          LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) AS c_addresses 
        , OH.C_Phone1 
        , @c_A2 AS A2  
        , @c_A3 AS A3
        , PD.SKU    
        , @c_A4 AS A4
        , SUM(PD.QTY) AS Qty 
        , S.DESCR 
        , OH.OrderKey  
        , @c_A5 AS A5
        , @c_D2 AS D2
        , @c_D4 AS D4
        , @c_B8 AS B8
        , @c_B9 AS B9
        , @c_B10 AS B10
        , @c_B14 AS B14
        , @c_D7 AS D7
        , @c_D8 AS D8
        , LTRIM(RTRIM(ISNULL(OH.C_State,'''')))  AS C_State
        , @c_D9 AS D9
        , LTRIM(RTRIM(ISNULL(OH.BuyerPO,'''')))  AS BuyerPO
        , @c_B1 AS B1
        , @c_B2 AS B2  
        , @c_D10 AS D10
        , @c_D13 AS D13
        , @c_D15 AS D15  
        , @c_C1 AS C1
        , @c_C2 AS C2  
        , @c_C3 AS C3
        , @c_C4 AS C4
        , @c_C5 AS C5  
        , @c_C10 AS C10
        , @c_C11 AS C11
        , @c_D1 AS D1 
        , @c_D3 AS D3
        , @c_D5 AS D5  
        , @c_D6 AS D6
        , S.Style  --20 
        , S.Size  --10 
        , SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) +LTRIM(RTRIM(ISNULL(OH.C_Address3,'''')))  ,1,CHARINDEX(' ', LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) 
             + LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))))) AS ADDLine1
        , SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) +LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) ,CHARINDEX(' ', LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) 
          + LTRIM(RTRIM(ISNULL(OH.C_Address3,'''')))),LEN(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) +LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))))) AS ADDLine2
        , @c_D12 AS D12 
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo                     
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OH.StorerKey
   LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   WHERE PH.PickSlipNo = @c_Pickslipno
   AND OH.DocType='E'
   GROUP BY LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + ' ' + 
            LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) 
           , CONVERT(NVARCHAR(10),OH.OrderDate,105)     
           , LTRIM(RTRIM(ISNULL(OH.C_Zip,'''')))    
           , LTRIM(RTRIM(ISNULL(OH.C_State,'''')))  
           , LTRIM(RTRIM(ISNULL(OH.C_contact1,'''')))  
           , OH.C_Phone1 
           , S.DESCR
           , PD.SKU
           , LTRIM(RTRIM(ISNULL(OH.BuyerPO,'''')))  
           , OH.OrderKey
           , S.Style 
           , S.Size   
        , SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) +LTRIM(RTRIM(ISNULL(OH.C_Address3,'''')))  ,1,CHARINDEX(' ', LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) 
             + LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))))) 
        , SUBSTRING(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) +LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) ,CHARINDEX(' ', LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) 
          + LTRIM(RTRIM(ISNULL(OH.C_Address3,'''')))),LEN(LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) +LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))))) 


QUIT_SP:  

END -- procedure

GO