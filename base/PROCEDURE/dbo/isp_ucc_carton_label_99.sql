SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_99                                 */
/* Creation Date: 30-Dec-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-15937 - Fabory ESR Carton Label                        */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_99                                  */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2021-01-18   WLChooi   1.1 Bug Fix - Qty Doubled (WL01)              */
/* 2021-07-10   Mingle    1.2 Add new mappings (ML01)                   */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_99]
           @c_Storerkey       NVARCHAR(15) 
         , @c_PickSlipNo      NVARCHAR(10) 
         , @c_StartCartonNo   NVARCHAR(10)
         , @c_EndCartonNo     NVARCHAR(10)
         , @c_Type            NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT
         
         , @n_PrintOrderAddresses   INT
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   IF ISNULL(@c_Type,'') = '' SET @c_Type = ''
   
   IF @c_Type = 'D'
   BEGIN
      SELECT PD.CartonNo,
             OD.AltSku,
             OD.SKU,
             (SELECT SUM(PACKDETAIL.Qty) FROM PACKDETAIL (NOLOCK) WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo AND PACKDETAIL.SKU = OD.SKU   --WL01
   	                                                              AND PACKDETAIL.CartonNo = PD.CartonNo),                                  --WL01
             OD.Notes,     --ML01
             ShowNotes = ISNULL(CL2.SHORT,'N')     --ML01
      FROM PACKDETAIL PD (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = PH.OrderKey AND PD.SKU = OD.SKU
      LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.LISTNAME = 'REPORTCFG' AND CL2.Code = 'RepSKUtoNotes'                    
                                      AND CL2.Long = 'r_dw_ucc_carton_label_99' AND CL2.Storerkey = PD.StorerKey     --ML01
      WHERE (PD.PickSlipNo= @c_PickSlipNo)
      AND (PD.Storerkey = @c_Storerkey)
      AND (PD.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
      GROUP BY PD.CartonNo, OD.AltSku, OD.SKU,OD.Notes,ISNULL(CL2.SHORT,'N')     --ML01

   	GOTO QUIT_SP
   END
   
   SELECT dbo.ORDERS.Storerkey
        , dbo.ORDERS.Orderkey
        , M_Company     = ISNULL(RTRIM(dbo.ORDERS.M_Company),'')
        , ConsigneeKey  = ISNULL(RTRIM(dbo.ORDERS.ConsigneeKey),'')
        , C_Company     = ISNULL(RTRIM(dbo.ORDERS.C_Company),'')
        , C_Address1    = ISNULL(RTRIM(dbo.ORDERS.C_Address1),'') 
        , C_Address2    = ISNULL(RTRIM(dbo.ORDERS.C_Address2),'')  
        , C_Address3    = ISNULL(RTRIM(dbo.ORDERS.C_Address3),'')  
        , C_Address4    = ISNULL(RTRIM(dbo.ORDERS.C_Address4),'') 
        , C_State       = ISNULL(RTRIM(dbo.ORDERS.C_State),'') 
        , C_City        = ISNULL(RTRIM(dbo.ORDERS.C_City),'') 
        , C_Contact1    = ISNULL(RTRIM(dbo.ORDERS.C_Contact1),'')
        , C_Contact2    = ISNULL(RTRIM(dbo.ORDERS.C_Contact2),'')         
        , C_Phone1      = ISNULL(RTRIM(dbo.ORDERS.C_Phone1),'') 
        , Customerpo    = ISNULL(RTRIM(dbo.ORDERS.UserDefine01),'') 
        , dbo.PACKDETAIL.PickSlipNo
        , dbo.PACKDETAIL.CartonNo
        , dbo.PACKDETAIL.LabelNo
        , DropID        = ISNULL(RTRIM(dbo.PACKDETAIL.LabelNo),'') 
        , Qty           = (SELECT SUM(Qty) FROM PACKDETAIL PCK WITH (NOLOCK) 
                           WHERE PCK.PickSlipNo = dbo.PACKDETAIL.PickSlipNo
                           AND   PCK.CartonNo = dbo.PACKDETAIL.CartonNo)
        , NewLabelNo    = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN        
                          CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(dbo.PACKDETAIL.LabelNo,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)
                         ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))
                          WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN            
                          CL.UDF01 + dbo.PACKDETAIL.LabelNo                                            
                          ELSE '' END              
        , HidePrintTime = ISNULL(CL1.Short,'N')                                                 
   FROM dbo.PACKHEADER WITH (NOLOCK) 
   JOIN dbo.ORDERS WITH (NOLOCK)   
      ON (dbo.PACKHEADER.Orderkey = dbo.ORDERS.Orderkey) 
   JOIN dbo.PACKDETAIL WITH (NOLOCK) 
      ON (dbo.PACKHEADER.PickSlipNo = dbo.PACKDETAIL.PickSlipNo) 
   JOIN dbo.ORDERDETAIL WITH (NOLOCK)
      ON (dbo.ORDERDETAIL.OrderKey = dbo.PackHeader.OrderKey)
   OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND
               (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Code = 'HidePrintTime'                    
                                  AND CL1.Long = 'r_dw_ucc_carton_label_99' AND CL1.Storerkey = ORDERS.StorerKey
   WHERE (dbo.PACKHEADER.PickSlipNo= @c_PickSlipNo)
     AND (dbo.PACKHEADER.Storerkey = @c_Storerkey)
     AND (dbo.PACKDETAIL.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
   GROUP BY dbo.ORDERS.Storerkey
          , dbo.ORDERS.Orderkey
          , ISNULL(RTRIM(dbo.ORDERS.M_Company),'')
          , ISNULL(RTRIM(dbo.ORDERS.ConsigneeKey),'')
          , ISNULL(RTRIM(dbo.ORDERS.C_Company),'')
          , ISNULL(RTRIM(dbo.ORDERS.C_Address1),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_Address2),'')  
          , ISNULL(RTRIM(dbo.ORDERS.C_Address3),'')  
          , ISNULL(RTRIM(dbo.ORDERS.C_Address4),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_State),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_City),'')
          , ISNULL(RTRIM(dbo.ORDERS.C_Contact1),'')         
          , ISNULL(RTRIM(dbo.ORDERS.C_Contact2),'')    
          , ISNULL(RTRIM(dbo.ORDERS.C_Phone1),'')
          , ISNULL(RTRIM(dbo.ORDERS.UserDefine01),'')          
          , dbo.PACKDETAIL.PickSlipNo
          , dbo.PACKDETAIL.CartonNo
          , dbo.PACKDETAIL.LabelNo
          , ISNULL(RTRIM(dbo.PACKDETAIL.LabelNo),'') 
          , ISNULL(CL.SHORT,'N')
          , CL.LONG  
          , CL.UDF01 
          , CL.UDF02 
          , CL.UDF03 
          , ISNULL(CL1.Short,'N')  
   ORDER BY dbo.PACKDETAIL.CartonNo

QUIT_SP:
END -- procedure

GO