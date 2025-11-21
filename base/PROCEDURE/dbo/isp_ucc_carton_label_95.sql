SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_95                                 */
/* Creation Date: 28-AUG-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-14914 - [CN]Natural Beauty UCCLABEL by carton          */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_95                                  */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2021-08-06   WLChooi   1.1 WMS-17647 - Use ReportCFG to control new  */
/*                            layout (WL01)                             */
/* 2021-10-06   WLChooi   1.2 DevOps Combine Script                     */
/* 2021-10-06   WLChooi   1.3 WMS-18075 - Use ReportCFG to show Notes   */
/*                            (WL02)                                    */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_95]
           @c_Storerkey       NVARCHAR(15)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_StartCartonNo   NVARCHAR(10)
         , @c_EndCartonNo     NVARCHAR(10)
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

   SELECT dbo.ORDERS.Storerkey
        , dbo.ORDERS.Orderkey
        , ExternOrderkey= ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'')
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
        , PrintNewLayout = ISNULL(CLK.Short,'')   --WL01  
        , ShowOrdNotes   = ISNULL(CL1.Short,'N')  --WL02
        , OrdNotes       = ISNULL(ORDERS.Notes,'')   --WL02                          
   FROM dbo.PACKHEADER WITH (NOLOCK) 
   JOIN dbo.ORDERS WITH (NOLOCK)   
      ON (dbo.PACKHEADER.Orderkey = dbo.ORDERS.Orderkey) 
   JOIN dbo.PACKDETAIL WITH (NOLOCK) 
      ON (dbo.PACKHEADER.PickSlipNo = dbo.PACKDETAIL.PickSlipNo) 
   OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
               CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND
               (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL
   LEFT JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'REPORTCFG' AND CLK.Storerkey = ORDERS.StorerKey         --WL01
                                  AND CLK.Long = 'r_dw_ucc_carton_label_95' AND CLK.Code = 'PrintNewLayout'   --WL01
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON CL1.LISTNAME = 'REPORTCFG' AND CL1.Storerkey = ORDERS.StorerKey         --WL02
                                  AND CL1.Long = 'r_dw_ucc_carton_label_95' AND CL1.Code = 'ShowOrdNotes'     --WL02
   WHERE (dbo.PACKHEADER.PickSlipNo= @c_PickSlipNo)
      AND (dbo.PACKHEADER.Storerkey = @c_Storerkey)
      AND (dbo.PACKDETAIL.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
   GROUP BY dbo.ORDERS.Storerkey
        , dbo.ORDERS.Orderkey
        , ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'')
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
        , ISNULL(CLK.Short,'')   --WL01
        , ISNULL(CL1.Short,'N')  --WL02
        , ISNULL(ORDERS.Notes,'')   --WL02 
 ORDER BY dbo.PACKDETAIL.CartonNo

QUIT_SP:
END -- procedure

GO