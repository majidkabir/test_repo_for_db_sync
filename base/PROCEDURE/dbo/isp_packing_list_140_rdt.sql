SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_140_rdt                                */  
/* Creation Date: 07-JUL-2023                                           */  
/* Copyright: Maersk                                                    */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-22972 -[CN] TMG B2B Packing list_New                    */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_140_rdt                                 */  
/*          :                                                           */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 07-JUL-2023  CSCHONG   1.0 Devops Scripts Combine                    */
/************************************************************************/  
CREATE   PROC [dbo].[isp_Packing_List_140_rdt]
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
            , @c_A7              NVARCHAR(80)   
            , @c_A9              NVARCHAR(80)   
            , @c_A11             NVARCHAR(80) 
            , @c_A15             NVARCHAR(80)   
            , @c_A16             NVARCHAR(80) 
            , @c_A17             NVARCHAR(80) 
            , @c_A18             NVARCHAR(80) 
            , @c_B1              NVARCHAR(80)  
            , @c_B3              NVARCHAR(80)  
            , @c_B5              NVARCHAR(80)  
            , @c_B10             NVARCHAR(80)  
            , @c_B11             NVARCHAR(80)  
            , @c_B12             NVARCHAR(80) 
            , @c_B13             NVARCHAR(80)  
            , @c_B14             NVARCHAR(80)  
            , @c_B15             NVARCHAR(80) 
            , @c_B16             NVARCHAR(80)  
            , @c_B17             NVARCHAR(80)  
            , @c_B18             NVARCHAR(80) 
            , @c_B19             NVARCHAR(80)  
            , @c_C1              NVARCHAR(500)  
            , @c_C2              NVARCHAR(80) 
            , @c_C4              NVARCHAR(80) 
            , @c_ORDTYPE         NVARCHAR(5)
            , @n_TTLWGT          DECIMAL(10,2)
            , @n_TTLCUBE         DECIMAL(10,5)

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = '' 
   SET @c_SummPAck  = 'N'
   SET @c_ORDTYPE   = ''

   IF ISNULL(@c_cartonNoStart,'') = '' SET @c_cartonNoStart = '1'
   IF ISNULL(@c_cartonNoEnd,'') = '' SET @c_cartonNoEnd = '99999'

  

      SELECT @c_A1 = ISNULL(MAX(CASE WHEN CL.Code = 'A1'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A2 = ISNULL(MAX(CASE WHEN CL.Code = 'A2'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A3 = ISNULL(MAX(CASE WHEN CL.Code = 'A3'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A7 = ISNULL(MAX(CASE WHEN CL.Code = 'A7'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A9 = ISNULL(MAX(CASE WHEN CL.Code = 'A9'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A11= ISNULL(MAX(CASE WHEN CL.Code = 'A11' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A15 = ISNULL(MAX(CASE WHEN CL.Code = 'A15'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A16 = ISNULL(MAX(CASE WHEN CL.Code = 'A16'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A17 = ISNULL(MAX(CASE WHEN CL.Code = 'A17'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_A18 = ISNULL(MAX(CASE WHEN CL.Code = 'A18'  THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B1= ISNULL(MAX(CASE WHEN CL.Code = 'B1' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B3= ISNULL(MAX(CASE WHEN CL.Code = 'B3' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B5= ISNULL(MAX(CASE WHEN CL.Code = 'B5' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B10= ISNULL(MAX(CASE WHEN CL.Code = 'B10' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B11= ISNULL(MAX(CASE WHEN CL.Code = 'B11' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B12= ISNULL(MAX(CASE WHEN CL.Code = 'B12' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B13= ISNULL(MAX(CASE WHEN CL.Code = 'B13' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B14= ISNULL(MAX(CASE WHEN CL.Code = 'B14' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B15= ISNULL(MAX(CASE WHEN CL.Code = 'B15' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B16= ISNULL(MAX(CASE WHEN CL.Code = 'B16' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B17= ISNULL(MAX(CASE WHEN CL.Code = 'B17' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B18= ISNULL(MAX(CASE WHEN CL.Code = 'B18' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_B19= ISNULL(MAX(CASE WHEN CL.Code = 'B19' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C1= ISNULL(MAX(CASE WHEN CL.Code = 'C1' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C2= ISNULL(MAX(CASE WHEN CL.Code = 'C2' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
            ,@c_C4= ISNULL(MAX(CASE WHEN CL.Code = 'C4' THEN ISNULL(RTRIM(CL.NOTES),'') ELSE '' END),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'TMGB2BPKL'


     SELECT @n_TTLWGT= SUM(PIF.Weight) ,
            @n_TTLCUBE = CAST(SUM(PIF.Cube) AS DECIMAL(10,5))
     FROM dbo.PackInfo PIF WITH (NOLOCK) WHERE PIF.PickSlipNo=@c_Pickslipno

  
   SELECT ISNULL(OH.Externorderkey,'') AS Externorderkey
        , LTRIM(RTRIM(ISNULL(F.Address1,''))) + ' ,' +  LTRIM(RTRIM(ISNULL(F.Address2,''))) AS FAdd
        , LTRIM(RTRIM(ISNULL(F.Address3,'')))  AS FAdd3 
        , LTRIM(RTRIM(ISNULL(F.Address4,'')))  AS FAdd4
        , OH.BuyerPO   --20  
        , @c_A2 AS A2  
        , @c_A3 AS A3
        , PD.SKU    
        , @c_A1 AS A1
        , SUM(PD.QTY) AS Qty 
        , S.DESCR    
        , PH.PickSlipNo AS Pickslipno
        , PD.LabelNo--20  
        , @c_B1 AS B1
        , @c_B3 AS B3
        , @c_A7 AS A7
        , @c_B5 AS B5
        , @c_A9 AS A9
        , @c_A15 AS A15
        , @c_A11 AS A11
        , @c_A16 AS A16
        , @c_A17 AS A17
        , @c_A18 AS A18
        , @c_B10 AS B10
        , @c_B11 AS B11
        , @c_B12 AS B12
        , @c_B13 AS B13
        , @c_B14 AS B14
        , @c_B15 AS B15
        , @c_B16 AS B16
        , @c_B17 AS B17
        , @c_B18 AS B18
        , @c_B19 AS B19
        , @c_C1 AS C1
        , @c_C2 AS C2
        , @c_C4 AS C4
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) AS BAdd1
        , LTRIM(RTRIM(ISNULL(OH.C_Address2,''))) AS BAdd2
        , LTRIM(RTRIM(ISNULL(OH.C_City,''))) + ' ' +  LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) + ' ' +  LTRIM(RTRIM(ISNULL(OH.C_Country,''))) AS BCityZip
        , PD.CartonNo
        , CAST(SUM(PIF.Weight) AS DECIMAL(10,2)) AS PIFWGT
        , CAST(SUM(PIF.Cube) AS DECIMAL(10,5)) AS PIFCUBE
        , S.Style 
        , S.Color 
        , S.Size  
        , S.MANUFACTURERSKU
        , S.ALTSKU
        , @n_TTLWGT AS TTLWGT
        , @n_TTLCUBE AS TTLCUBE
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON OH.OrderKey = PH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.PickSlipNo                     
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OH.StorerKey
   JOIN dbo.FACILITY F WITH (NOLOCK) ON F.Facility = OH.Facility
   JOIN dbo.PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo=PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   --CROSS APPLY (SELECT PIF.PickSlipNo,PIF.CartonNo,SUM(PIF.Weight) AS PIFWGT,CAST(SUM(PIF.Cube) AS DECIMAL(10,5)) AS PIFCUBE
   --             FROM dbo.PackInfo PIF WITH (NOLOCK) WHERE PIF.PickSlipNo=PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   --             GROUP BY PIF.PickSlipNo,PIF.CartonNo) AS PIF
   WHERE PH.PickSlipNo = @c_Pickslipno
   GROUP BY ISNULL(OH.Externorderkey,'')
          , LTRIM(RTRIM(ISNULL(F.Address1,''))) + ' ,' +  LTRIM(RTRIM(ISNULL(F.Address2,'')))
          , LTRIM(RTRIM(ISNULL(F.Address3,'')))  
          , LTRIM(RTRIM(ISNULL(F.Address4,''))) 
          , OH.BuyerPO,PH.PickSlipNo
          , S.DESCR
          , PD.SKU
          , PH.PickSlipNo
          , PD.LabelNo
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) 
          , LTRIM(RTRIM(ISNULL(OH.C_Address2,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_City,''))) + ' ' +  LTRIM(RTRIM(ISNULL(OH.C_Zip,''))) + ' ' +  LTRIM(RTRIM(ISNULL(OH.C_Country,'')))
          , PD.CartonNo
          , S.Style
          , S.Color 
          , S.Size 
          , S.MANUFACTURERSKU
          , S.ALTSKU
    ORDER BY PH.PickSlipNo,PD.CartonNo


QUIT_SP:  

END -- procedure

GO