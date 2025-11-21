SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_packing_list_25_rpt                                 */
/* Creation Date: 22-JAN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3828 - [TW] PMA add New View Report --Packlist New      */
/*        :                                                             */
/* Called By:r_dw_packing_list_25_rpt                                   */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_packing_list_25_rpt]
        @c_PickSlipNoFrom     NVARCHAR(10)
      , @c_PickSlipNoTo       NVARCHAR(10)
      , @c_LoadKeyFrom        NVARCHAR(10)
      , @c_LoadKeyTo          NVARCHAR(10)
      , @c_OrderkeyFrom       NVARCHAR(10)
      , @c_OrderKeyTo         NVARCHAR(10)
      , @c_ExternOrderkeyFrom NVARCHAR(50)  --tlting_ext
      , @c_ExternOrderKeyTo   NVARCHAR(50)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT OH.Storerkey
         ,OH.Orderkey      
         ,ExternORdekrey = ISNULL(RTRIM(OH.ExternOrderkey),'')      
         ,CustomerCode = CASE WHEN LEN(ISNULL(RTRIM(OH.ConsigneeKey),'')) < 4
                              THEN '' 
                              ELSE SUBSTRING(ISNULL(RTRIM(OH.ConsigneeKey),''), 4, LEN(ISNULL(RTRIM(OH.ConsigneeKey),'')) - 4 + 1)
                              END
         ,Consigneekey = ISNULL(RTRIM(OH.ConsigneeKey),'')
         ,C_Company = ISNULL(RTRIM(OH.C_Company),'')
         ,PONo  = CASE WHEN ST.Storerkey IS NULL THEN '' 
                       ELSE ( SELECT TOP 1 OD.UserDefine04
                              FROM ORDERDETAIL OD WITH (NOLOCK)
                              WHERE OD.Orderkey  = OH.Orderkey 
                            )  
                       END
         ,Addresses = ISNULL(RTRIM(OH.C_Address1),'') + ' ' + ISNULL(RTRIM(OH.C_Address2),'')
         ,Notes = ISNULL(RTRIM(OH.Notes),'')
         ,lpuserdefdate01 = ISNULL(LP.lpuserdefdate01,'1900-01-01')
         ,PD.PickSlipNo
         ,PD.CartonNo
         ,RowNo = ROW_NUMBER() OVER (PARTITION BY PD.PickSlipNo, PD.CartonNo 
                                     ORDER BY PD.PickSlipNo, PD.CartonNo, SKU.Style, SKU.Color)
         ,SKU.Style
         ,SKU.Color
         ,Descr = MAX(SKU.Descr)
         ,Qty = SUM(PD.Qty)
         ,UOM = ISNULL(RTRIM(CL.Description),'')
   FROM LOADPLAN       LP  WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
   JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   JOIN PACKHEADER     PH  WITH (NOLOCK) ON (OH.Orderkey  = PH.Orderkey)
   JOIN PACKDETAIL     PD  WITH (NOLOCK) ON (PH.PickSlipNo= PD.PickSlipNo)
   JOIN SKU            SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                         AND(PD.Sku       = SKU.Sku)
   JOIN PACK          PACK WITH (NOLOCK) ON (SKU.Packkey  = PACK.Packkey)
   LEFT JOIN STORER    ST  WITH (NOLOCK) ON (OH.Consigneekey = ST.Storerkey)
                                         AND(ST.ConsigneeFor = 'RTL')
   LEFT JOIN CODELKUP  CL  WITH (NOLOCK) ON (CL.ListName  = 'PMAUOM')
                                         AND(CL.Code      = PACK.PackUOM3)
   WHERE LP.Loadkey  BETWEEN @c_LoadkeyFrom AND @c_LoadkeyTo
   AND   OH.Orderkey BETWEEN @c_OrderkeyFrom AND @c_OrderkeyTo
   AND   OH.ExternOrderkey BETWEEN @c_ExternOrderkeyFrom AND @c_ExternOrderkeyTo
   AND   PD.PickSlipNo BETWEEN @c_PickSlipNoFrom AND @c_PickSlipNoTo
   GROUP BY OH.Storerkey
         ,  OH.Orderkey      
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')      
         ,  CASE WHEN LEN(ISNULL(RTRIM(OH.ConsigneeKey),'')) < 4
                 THEN '' 
                 ELSE SUBSTRING(ISNULL(RTRIM(OH.ConsigneeKey),''), 4, LEN(ISNULL(RTRIM(OH.ConsigneeKey),'')) - 4 + 1)
                 END
         ,  ISNULL(RTRIM(OH.ConsigneeKey),'')
         ,  ISNULL(RTRIM(OH.C_Company),'')
         ,  ST.Storerkey
         ,  ISNULL(RTRIM(OH.C_Address1),'') + ' '
         ,  ISNULL(RTRIM(OH.C_Address2),'')
         ,  ISNULL(RTRIM(OH.Notes),'')
         ,  ISNULL(LP.lpuserdefdate01,'1900-01-01')
         ,  PD.PickSlipNo
         ,  PD.CartonNo
         ,  SKU.Style
         ,  SKU.Color
         ,  ISNULL(RTRIM(CL.Description),'')
   ORDER BY PD.PickSlipNo
         ,  PD.CartonNo
         ,  SKU.Style
         ,  SKU.Color
END -- procedure

GO