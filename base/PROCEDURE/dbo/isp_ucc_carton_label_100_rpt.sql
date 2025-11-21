SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_100_rpt                            */
/* Creation Date: 13-Aug-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-17705 - [CN] CONVERSE_B2B_UCC Label_Viewreport_CR      */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_100_rpt                             */
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
CREATE PROC [dbo].[isp_UCC_Carton_Label_100_rpt]
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

   DECLARE @n_StartTCnt             INT
         , @n_Continue              INT
         , @n_PrintOrderAddresses   INT
         , @n_TotalQty              INT
         , @n_TotalPackedQty        INT
         , @c_Loadkey               NVARCHAR(10)
         , @c_OnlyPrintNewLayout    NVARCHAR(1) = 'N'
         , @c_ExcludeNewLayout      NVARCHAR(1) = 'Y'
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_PrintOrderAddresses = 0

   IF ISNULL(@c_Type,'') = ''
   BEGIN
      SET @c_Type = 'H'
   END

   IF @c_Type = 'NL'   --Only Print New Layout
   BEGIN
      SET @c_OnlyPrintNewLayout = 'Y'
      SET @c_Type = 'H'
   END
   ELSE IF @c_Type = 'ALL'   --Print All pages including the summary page
   BEGIN
      SET @c_Type = 'H'
      SET @c_ExcludeNewLayout = 'N'
   END

   --Copy from isp_UCC_Carton_Label_100
   SELECT @n_PrintOrderAddresses = MAX(CASE WHEN Code = 'PrintOrderAddresses' THEN 1 ELSE 0 END)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Storerkey = @c_Storerkey
   AND   Long = 'r_dw_ucc_carton_label_100'
   AND   ISNULL(Short,'') <> 'N'
   
   SELECT @c_Loadkey = LoadKey
   FROM PACKHEADER (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   
   SELECT @n_TotalQty = SUM(PD.Qty)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey

   IF ISNULL(@c_StartCartonNo,'') = ''
      SET @c_StartCartonNo = '1'

   IF ISNULL(@c_EndCartonNo,'') = ''
      SET @c_EndCartonNo = '99999'
  
   IF @c_Type = 'H'
   BEGIN
      SELECT ExternOrderkey= MAX(ISNULL(RTRIM(ORDERS.ExternOrderkey),''))
           , ConsigneeKey  = MAX(ISNULL(RTRIM(ORDERS.ConsigneeKey),''))
           , C_Contact1    = MAX(ISNULL(RTRIM(ORDERS.C_Contact1),''))
           , C_Company     = MAX(ISNULL(RTRIM(ORDERS.C_Company),''))
           , C_Address1    = MAX(ISNULL(RTRIM(ORDERS.C_Address1),''))
           , C_Address2    = MAX(ISNULL(RTRIM(ORDERS.C_Address2),'')) 
           , C_Address3    = MAX(ISNULL(RTRIM(ORDERS.C_Address3),''))  
           , C_Address4    = MAX(ISNULL(RTRIM(ORDERS.C_Address4),'')) 
           , C_State       = MAX(ISNULL(RTRIM(ORDERS.C_State),'')) 
           , C_City        = MAX(ISNULL(RTRIM(ORDERS.C_City),'')) 
           , C_Country     = MAX(ISNULL(RTRIM(ORDERS.C_Country),'')) 
           , C_Phone1      = MAX(ISNULL(RTRIM(ORDERS.C_Phone1),'')) 
           , BillToKey     = MAX(ISNULL(RTRIM(ORDERS.BillToKey),''))
           , MarkForKey    = MAX(ISNULL(RTRIM(ORDERS.MarkForKey),'')) 
           , PACKDETAIL.PickSlipNo
           , PACKDETAIL.CartonNo
           , LabelNo       = SUBSTRING(ISNULL(LTRIM(RTRIM(PACKDETAIL.LabelNo)),''),1, LEN(ISNULL(LTRIM(RTRIM(PACKDETAIL.LabelNo)),'')) - 4)
           , Qty = SUM(PACKDETAIL.Qty)
           , CS_Storerkey  = CASE WHEN @n_PrintOrderAddresses = 1 THEN NULL ELSE STORER.Storerkey END
           , CS_Contact1   = ISNULL(RTRIM(STORER.Contact1),'') 
           , CS_Company    = ISNULL(RTRIM(STORER.Company),'') 
           , CS_Address1   = ISNULL(RTRIM(STORER.Address1),'')  
           , CS_Address2   = ISNULL(RTRIM(STORER.Address2),'')  
           , CS_Address3   = ISNULL(RTRIM(STORER.Address3),'')  
           , CS_Address4   = ISNULL(RTRIM(STORER.Address4),'')  
           , CS_State      = ISNULL(RTRIM(STORER.State),'')  
           , CS_City       = ISNULL(RTRIM(STORER.City),'')  
           , CS_Phone1     = ISNULL(RTRIM(STORER.Phone1),'')  
           , TotalCarton   = (SELECT COUNT(DISTINCT CARTONNO) FROM PACKDETAIL WITH (NOLOCK) 
                              WHERE PickSlipNo = @c_PickSlipNo)
           , CS_SUSR2      = ISNULL(RTRIM(STORER.SUSR2),'')  
           , Last4LabelNo  = RIGHT(ISNULL(LTRIM(RTRIM(PACKDETAIL.LabelNo)),''),4)
           , Loadkey       = SUBSTRING(ISNULL(LTRIM(RTRIM(PACKHEADER.LoadKey)),''),1, LEN(ISNULL(LTRIM(RTRIM(PACKHEADER.LoadKey)),'')) - 4)
           , Last4Loadkey  = RIGHT(ISNULL(LTRIM(RTRIM(PACKHEADER.LoadKey)),''),4)
           , NewLayout     = 'N'
      INTO #TMP_CtnLbl100
      FROM PACKHEADER WITH (NOLOCK) 
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo) 
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.Loadkey = PACKHEADER.LoadKey
      JOIN ORDERS WITH (NOLOCK) ON LPD.Orderkey = ORDERS.Orderkey
      LEFT JOIN STORER WITH (NOLOCK) ON (STORER.Storerkey =  RTRIM(ORDERS.ConsigneeKey))
      WHERE (PACKHEADER.PickSlipNo= @c_PickSlipNo)
         AND (PACKHEADER.Storerkey = @c_Storerkey)
         AND (PACKDETAIL.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
      GROUP BY PACKDETAIL.PickSlipNo
             , PACKDETAIL.CartonNo
             , SUBSTRING(ISNULL(LTRIM(RTRIM(PACKDETAIL.LabelNo)),''),1, LEN(ISNULL(LTRIM(RTRIM(PACKDETAIL.LabelNo)),'')) - 4)
             , STORER.Storerkey
             , ISNULL(RTRIM(STORER.Contact1),'') 
             , ISNULL(RTRIM(STORER.Company),'') 
             , ISNULL(RTRIM(STORER.Address1),'')  
             , ISNULL(RTRIM(STORER.Address2),'')  
             , ISNULL(RTRIM(STORER.Address3),'')  
             , ISNULL(RTRIM(STORER.Address4),'')  
             , ISNULL(RTRIM(STORER.State),'')  
             , ISNULL(RTRIM(STORER.City),'')  
             , ISNULL(RTRIM(STORER.Phone1),'')  
             , ISNULL(RTRIM(STORER.SUSR2),'')  
             , RIGHT(ISNULL(LTRIM(RTRIM(PACKDETAIL.LabelNo)),''),4)
             , SUBSTRING(ISNULL(LTRIM(RTRIM(PACKHEADER.LoadKey)),''),1, LEN(ISNULL(LTRIM(RTRIM(PACKHEADER.LoadKey)),'')) - 4)
             , RIGHT(ISNULL(LTRIM(RTRIM(PACKHEADER.LoadKey)),''),4)
             
      IF (@c_StartCartonNo <> @c_EndCartonNo) OR @c_OnlyPrintNewLayout = 'Y' OR @c_ExcludeNewLayout = 'N'
      BEGIN
         INSERT INTO #TMP_CtnLbl100
         SELECT TOP 1 ExternOrderkey
              , ConsigneeKey
              , C_Contact1  
              , C_Company   
              , C_Address1  
              , C_Address2  
              , C_Address3  
              , C_Address4  
              , C_State     
              , C_City      
              , C_Country   
              , C_Phone1    
              , BillToKey   
              , MarkForKey  
              , PickSlipNo
              , '99999'
              , ''
              , 0
              , CS_Storerkey 
              , CS_Contact1  
              , CS_Company   
              , CS_Address1  
              , CS_Address2  
              , CS_Address3  
              , CS_Address4  
              , CS_State     
              , CS_City      
              , CS_Phone1    
              , TotalCarton           
              , CS_SUSR2     
              , '' 
              , Loadkey      
              , Last4Loadkey 
              , 'Y'
         FROM #TMP_CtnLbl100 WITH (NOLOCK) 
      END
      
      IF @c_OnlyPrintNewLayout = 'Y'
      BEGIN
         SELECT * FROM #TMP_CtnLbl100
         WHERE NewLayout = 'Y'
      END
      ELSE IF @c_ExcludeNewLayout = 'Y'
      BEGIN
         SELECT * FROM #TMP_CtnLbl100
         WHERE NewLayout = 'N'
         ORDER BY CartonNo
      END
      ELSE
      BEGIN
         SELECT * FROM #TMP_CtnLbl100
         ORDER BY CartonNo
      END
   END

   IF @c_Type = 'D1'
   BEGIN
      SELECT PackDetail.CartonNo as Cartonno
           , SKU.Style as style
           , SKU.Color as color
           , CASE WHEN ISNULL(C.short,'')='Y' THEN 
             CASE WHEN sku.measurement IN ('','U') THEN SKU.Size ELSE ISNULL(sku.measurement,'') END
                  ELSE SKU.Size END [Size]
           , PackDetail.Qty as qty
      FROM PackDetail WITH (NOLOCK) 
      JOIN SKU WITH (NOLOCK) ON (Sku.Storerkey = PackDetail.Storerkey)  
                                AND (Sku.Sku = PackDetail.Sku)
      LEFT JOIN CODELKUP C WITH (nolock) ON C.Storerkey = PackDetail.Storerkey
                                        AND C.listname = 'REPORTCFG' and C.Code = 'GetSkuMeasurement'
                                        AND C.Long = 'r_dw_ucc_carton_label_100'
      WHERE (PackDetail.PickSlipNo = @c_PickSlipNo)
        AND (PackDetail.CartonNo = @c_StartCartonNo)
   END
   
   IF @c_Type = 'D2'
   BEGIN
      SELECT @n_TotalPackedQty = SUM(PDET.Qty)
      FROM PACKDETAIL PDET (NOLOCK)
      WHERE PDET.PickSlipNo = @c_PickSlipNo
      AND PDET.CartonNo BETWEEN 1 AND CAST(@c_StartCartonNo AS INT)

      SELECT @c_StartCartonNo AS CartonNo, 
             Qty = (SELECT SUM(Qty) FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @c_StartCartonNo),
             COUNT(Distinct dbo.PackDetail.CartonNo) AS totalCarton,
             PackHeader.[Status],
             LastCarton = CASE WHEN @n_TotalQty = @n_TotalPackedQty THEN 'Y' ELSE 'N' END 
      FROM PackHeader WITH (NOLOCK) 
      JOIN PackDetail WITH (NOLOCK) ON dbo.Packheader.Pickslipno = dbo.Packdetail.Pickslipno
      WHERE (PackHeader.PickSlipNo = @c_PickSlipNo)
      GROUP BY PackHeader.[Status]
   END
   
   IF @c_Type = 'D3'
   BEGIN
      SELECT OH.ExternOrderkey, SUM(PD.Qty)
      FROM LoadPlanDetail LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey
      GROUP BY OH.ExternOrderKey
   END
   
   IF @c_Type = 'D4'
   BEGIN
      SELECT COUNT(DISTINCT OH.ExternOrderkey), SUM(PD.Qty)
      FROM LoadPlanDetail LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey
   END

QUIT_SP:
END -- procedure

GO