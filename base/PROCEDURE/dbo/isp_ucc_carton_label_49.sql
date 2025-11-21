SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_49                                 */
/* Creation Date: 16-DEC-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-815 - Converse - Change the mapping on Shipping Label  */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_49                                  */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2021-03-19   WLChooi   1.1 WMS-16612 - Add ReportCFG to reduce font  */
/*                            size (WL01)                               */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_49]
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
         , @n_ReduceFontSize        INT   --WL01
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @n_PrintOrderAddresses = 0
   SET @n_ReduceFontSize      = 0   --WL01

   SELECT @n_PrintOrderAddresses = MAX(CASE WHEN Code = 'PrintOrderAddresses' THEN 1 ELSE 0 END)
        , @n_ReduceFontSize      = MAX(CASE WHEN Code = 'ReduceFontSize'      THEN 1 ELSE 0 END)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Storerkey = @c_Storerkey
   AND   Long = 'r_dw_ucc_carton_label_49'
   AND   ISNULL(Short,'') <> 'N'

   SELECT ExternOrderkey   = ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'')
          , ConsigneeKey   = ISNULL(RTRIM(dbo.ORDERS.ConsigneeKey),'')
          , C_Contact1     = ISNULL(RTRIM(dbo.ORDERS.C_Contact1),'')
          , C_Company      = ISNULL(RTRIM(dbo.ORDERS.C_Company),'')
          , C_Address1     = ISNULL(RTRIM(dbo.ORDERS.C_Address1),'') 
          , C_Address2     = ISNULL(RTRIM(dbo.ORDERS.C_Address2),'')  
          , C_Address3     = ISNULL(RTRIM(dbo.ORDERS.C_Address3),'')  
          , C_Address4     = ISNULL(RTRIM(dbo.ORDERS.C_Address4),'') 
          , C_State        = ISNULL(RTRIM(dbo.ORDERS.C_State),'') 
          , C_City         = ISNULL(RTRIM(dbo.ORDERS.C_City),'') 
          , C_Country      = ISNULL(RTRIM(dbo.ORDERS.C_Country),'') 
          , C_Phone1       = ISNULL(RTRIM(dbo.ORDERS.C_Phone1),'') 
          , BillToKey      = ISNULL(RTRIM(dbo.ORDERS.BillToKey),'') 
          , MarkForKey     = ISNULL(RTRIM(dbo.ORDERS.MarkForKey),'') 
          , dbo.PACKDETAIL.PickSlipNo
          , dbo.PACKDETAIL.CartonNo
          , LabelNo        = ISNULL(RTRIM(dbo.PACKDETAIL.LabelNo),'') 
          , Qty = SUM(dbo.PACKDETAIL.Qty)
          , CS_Storerkey   = CASE WHEN @n_PrintOrderAddresses = 1 THEN NULL ELSE dbo.STORER.Storerkey END
          , CS_Contact1    = ISNULL(RTRIM(dbo.STORER.Contact1),'') 
          , CS_Company     = ISNULL(RTRIM(dbo.STORER.Company),'') 
          , CS_Address1    = ISNULL(RTRIM(dbo.STORER.Address1),'')  
          , CS_Address2    = ISNULL(RTRIM(dbo.STORER.Address2),'')  
          , CS_Address3    = ISNULL(RTRIM(dbo.STORER.Address3),'')  
          , CS_Address4    = ISNULL(RTRIM(dbo.STORER.Address4),'')  
          , CS_State       = ISNULL(RTRIM(dbo.STORER.State),'')  
          , CS_City        = ISNULL(RTRIM(dbo.STORER.City),'')  
          , CS_Phone1      = ISNULL(RTRIM(dbo.STORER.Phone1),'')  
          , TotalCarton    = (SELECT COUNT(DISTINCT CARTONNO) FROM PACKDETAIL WITH (NOLOCK) 
                              WHERE PickSlipNo = dbo.PACKDETAIL.PickSlipNo)
          , CS_SUSR2       = ISNULL(RTRIM(dbo.STORER.SUSR2),'')  
          , ReduceFontSize = @n_ReduceFontSize   --WL01
   FROM dbo.PACKHEADER WITH (NOLOCK) 
   JOIN dbo.ORDERS WITH (NOLOCK)   
      ON (dbo.PACKHEADER.Orderkey = dbo.ORDERS.Orderkey) 
   JOIN dbo.PACKDETAIL WITH (NOLOCK) 
      ON (dbo.PACKHEADER.PickSlipNo = dbo.PACKDETAIL.PickSlipNo) 
   LEFT JOIN dbo.STORER WITH (NOLOCK) 
      ON (dbo.STORER.Storerkey =  RTRIM(dbo.ORDERS.ConsigneeKey))
   WHERE (dbo.PACKHEADER.PickSlipNo= @c_PickSlipNo)
      AND (dbo.PACKHEADER.Storerkey = @c_Storerkey)
      AND (dbo.PACKDETAIL.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
   GROUP BY ISNULL(RTRIM(dbo.ORDERS.ExternOrderkey),'')
          , ISNULL(RTRIM(dbo.ORDERS.ConsigneeKey),'')
          , ISNULL(RTRIM(dbo.ORDERS.C_Contact1),'')
          , ISNULL(RTRIM(dbo.ORDERS.C_Company),'')
          , ISNULL(RTRIM(dbo.ORDERS.C_Address1),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_Address2),'')  
          , ISNULL(RTRIM(dbo.ORDERS.C_Address3),'')  
          , ISNULL(RTRIM(dbo.ORDERS.C_Address4),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_State),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_City),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_Country),'') 
          , ISNULL(RTRIM(dbo.ORDERS.C_Phone1),'') 
          , ISNULL(RTRIM(dbo.ORDERS.BillToKey),'') 
          , ISNULL(RTRIM(dbo.ORDERS.MarkForKey),'') 
          , dbo.PACKDETAIL.PickSlipNo
          , dbo.PACKDETAIL.CartonNo
          , ISNULL(RTRIM(dbo.PACKDETAIL.LabelNo),'') 
          , dbo.STORER.Storerkey
          , ISNULL(RTRIM(dbo.STORER.Contact1),'') 
          , ISNULL(RTRIM(dbo.STORER.Company),'') 
          , ISNULL(RTRIM(dbo.STORER.Address1),'')  
          , ISNULL(RTRIM(dbo.STORER.Address2),'')  
          , ISNULL(RTRIM(dbo.STORER.Address3),'')  
          , ISNULL(RTRIM(dbo.STORER.Address4),'')  
          , ISNULL(RTRIM(dbo.STORER.State),'')  
          , ISNULL(RTRIM(dbo.STORER.City),'')  
          , ISNULL(RTRIM(dbo.STORER.Phone1),'')  
          , ISNULL(RTRIM(dbo.STORER.SUSR2),'')  
   ORDER BY dbo.PACKDETAIL.CartonNo

QUIT_SP:
END -- procedure

GO