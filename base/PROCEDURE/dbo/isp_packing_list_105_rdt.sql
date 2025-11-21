SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_105_rdt                                */  
/* Creation Date: 28-JUL-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-17509 -[CN] APEDEMOD_Packing list for B2C&B2B           */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_105_rdt                                 */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 11-AUG-2021  CSCHONG   1.1 WMs-17509 revised print logic (CS01)      */
/************************************************************************/  
CREATE PROC [dbo].[isp_Packing_List_105_rdt]
            @c_Pickslipno    NVARCHAR(15),     
            @c_cartonNoStart NVARCHAR(5) = '', 
            @c_cartonNoEnd   NVARCHAR(5) =''  
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
            , @c_A8              NVARCHAR(80)  
            , @c_A9              NVARCHAR(80)  
            , @c_A10             NVARCHAR(80)  
            , @c_A11             NVARCHAR(80)  
            , @c_A12             NVARCHAR(80)  
            , @c_A13             NVARCHAR(80)  
            , @c_ORDTYPE         NVARCHAR(5)

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 
   SET @c_SummPAck  = 'N'
   SET @c_ORDTYPE   = ''

   IF ISNULL(@c_cartonNoStart,'') = '' SET @c_cartonNoStart = '1'
   IF ISNULL(@c_cartonNoEnd,'') = '' SET @c_cartonNoEnd = '99999'

   IF @c_cartonNoStart ='1' AND @c_cartonNoEnd ='99999' 
   BEGIN 
        SET @c_SummPAck  = 'Y'     
   END
  

      SELECT @c_A1 = ISNULL(MAX(CASE WHEN CL.Code = 'A1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A2 = ISNULL(MAX(CASE WHEN CL.Code = 'A2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A3 = ISNULL(MAX(CASE WHEN CL.Code = 'A3'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A4 = ISNULL(MAX(CASE WHEN CL.Code = 'A4'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A5 = ISNULL(MAX(CASE WHEN CL.Code = 'A5'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A6 = ISNULL(MAX(CASE WHEN CL.Code = 'A6'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A7 = ISNULL(MAX(CASE WHEN CL.Code = 'A7'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A8 = ISNULL(MAX(CASE WHEN CL.Code = 'A8'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A9 = ISNULL(MAX(CASE WHEN CL.Code = 'A9'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A10= ISNULL(MAX(CASE WHEN CL.Code = 'A10' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A11= ISNULL(MAX(CASE WHEN CL.Code = 'A11' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A12= ISNULL(MAX(CASE WHEN CL.Code = 'A12' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A13= ISNULL(MAX(CASE WHEN CL.Code = 'A13' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'APMDPAC'


   SELECT TOP 1 @c_ORDTYPE = CASE WHEN ISNULL(c.notes,'') LIKE '%B2B%' THEN 'B2B' 
                                  WHEN ISNULL(c.notes,'') LIKE '%B2C%' THEN 'B2C' ELSE '' END
   FROM dbo.PackHeader ph (NOLOCK)
   JOIN orders oh (NOLOCK) ON oh.OrderKey=ph.OrderKey
   LEFT JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.LISTNAME='APEDEPCK' AND C.Short = oh.DocType AND C.long=oh.ConsigneeKey AND UDF01='r_dw_packing_list_105_rdt'
   WHERE ph.PickSlipNo= @c_Pickslipno
   
   SELECT ISNULL(OH.Externorderkey,'') AS Externorderkey
        , ISNULL(OH.M_Company,'') AS M_Company  
        , LTRIM(RTRIM(ISNULL(OH.C_Contact1,'''')))  AS C_Contact 
        , LTRIM(RTRIM(ISNULL(OH.C_State,''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_City,''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + ' ' + 
          LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + ' ' +  LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))) AS C_Addresses
        , OH.C_Phone1  
      --  , @c_A1 AS A1
        , @c_A2 AS A2  
        , @c_A3 AS A3
        , PD.SKU    
        , @c_A4 AS A4
        , SUM(PD.QTY) AS Qty 
        , S.DESCR    
        , CASE WHEN @c_ORDTYPE = 'B2C' THEN PH.TaskBatchNo 
               WHEN  @c_ORDTYPE = 'B2B' THEN RTRIM(PH.PickSlipNo) + '-' + CAST(PD.CartonNo AS NVARCHAR(10)) ELSE '' END AS Pickslipno
        , OH.OrderKey  
        , @c_A5 AS A5
        , @c_A6 AS A6
        , @c_A7 AS A7
        , @c_A8 AS A8
        , @c_A9 AS A9
        , @c_A10 AS A10
        , @c_A11 AS A11
        , @c_A12 AS A12
        , @c_A13 AS A13
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo                     
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OH.StorerKey
   WHERE PH.PickSlipNo = @c_Pickslipno
   AND PD.CartonNo BETWEEN CAST(@c_cartonNoStart AS INT) AND CAST(@c_cartonNoEnd AS INT) 
   AND ISNULL(@c_ORDTYPE,'') <> ''                                                          --(CS01)
   GROUP BY ISNULL(OH.Externorderkey,'')
          , ISNULL(OH.M_Company,'')
          , LTRIM(RTRIM(ISNULL(OH.C_Contact1,'''')))
          , LTRIM(RTRIM(ISNULL(OH.C_State,''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_City,''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address1,''''))) + ' ' + 
            LTRIM(RTRIM(ISNULL(OH.C_Address2,''''))) + ' ' +  LTRIM(RTRIM(ISNULL(OH.C_Address3,''''))) + ' ' + LTRIM(RTRIM(ISNULL(OH.C_Address4,''''))) 
          , OH.C_Phone1
          , S.DESCR
          , PD.SKU
          , CASE WHEN @c_ORDTYPE = 'B2C' THEN PH.TaskBatchNo 
               WHEN  @c_ORDTYPE = 'B2B' THEN RTRIM(PH.PickSlipNo) + '-' + CAST(PD.CartonNo AS NVARCHAR(10)) ELSE '' END
          , OH.OrderKey


QUIT_SP:  

END -- procedure

GO