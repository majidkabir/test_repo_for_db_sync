SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_70_rdt                        */
/* Creation Date: 16-Aug-2019                                           */
/* Copyright: LFL                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose:  WMS-10202 - [CN] Super Hub Project _                       */ 
/*                       Mast_Carton Label Change (CR)                  */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Convert from query to calling SP                              */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_70_rdt                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 2020-08-19   WLChooi  1.1  WMS-14775 Add Last Carton Indicator (WL01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_70_rdt] (
	        @c_StorerKey      NVARCHAR(20), 
           @c_PickSlipNo     NVARCHAR(20),
           @c_StartCartonNo  NVARCHAR(20),
           @c_EndCartonNo    NVARCHAR(20)
            )
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT = 1   
         , @n_SumPickedQty    INT = 0   --WL01
         , @n_SumPackedQty    INT = 0   --WL01
         , @n_LastCarton      INT = 0   --WL01
         , @n_MaxCarton       INT = 0   --WL01  

   --WL01 START
   SELECT @n_SumPickedQty = SUM(PD.Qty)
   FROM PICKDETAIL PD (NOLOCK) 
   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
   JOIN PICKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.ExternOrderkey 
   WHERE PH.Pickheaderkey = @c_PickSlipNo   

   SELECT @n_SumPackedQty = SUM(PD.Qty)
   FROM PACKDETAIL PD (NOLOCK) 
   WHERE PD.Pickslipno = @c_PickSlipNo AND PD.Storerkey = @c_StorerKey

   IF @n_SumPickedQty = @n_SumPackedQty 
   BEGIN
      SELECT @n_LastCarton = MAX(CartonNo)
      FROM PACKDETAIL PD (NOLOCK) 
      WHERE PD.Pickslipno = @c_PickSlipNo AND PD.Storerkey = @c_StorerKey
   END
   --WL01 END  

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN       
      SELECT MIN(dbo.ORDERS.ExternOrderkey) as ExternOrderkey --INC0244576
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.ConsigneeKey ELSE CHILDORD.Consigneekey END AS Consigneekey
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Company ELSE CHILDORD.C_Company END AS C_Company
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address1 ELSE CHILDORD.C_Address1 END AS C_Address1
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address2 ELSE CHILDORD.C_Address2 END AS C_Address2
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address3 ELSE CHILDORD.C_Address3 END AS C_Address3
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address4 ELSE CHILDORD.C_Address4 END AS C_Address4
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_State ELSE CHILDORD.C_State END AS C_State
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_City ELSE CHILDORD.C_City END AS C_City
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') <> '' THEN CHILDORD.ExternOrderkey ELSE '' END AS ChildExternOrderkey
            , dbo.ORDERS.BillToKey
            , dbo.ORDERS.MarkForKey
            , dbo.PackDetail.PickSlipNo
            , dbo.PackDetail.CartonNo
            , CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN ISNULL(Packinfo.CartonGID,'') ELSE PackDetail.LabelNo END AS LabelNo
            /*Qty = SUM(dbo.PackDetail.Qty)*/
            , Qty = (SELECT SUM(PD.QTY) FROM dbo.PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = dbo.PackDetail.Pickslipno
                 AND PD.cartonno = dbo.PackDetail.Cartonno)
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.STORER.Storerkey ELSE NULL END AS Storerkey
            , dbo.STORER.Company
            , dbo.STORER.Address1
            , dbo.STORER.Address2
            , dbo.STORER.Address3
            , dbo.STORER.Address4
            , dbo.STORER.State
            , dbo.STORER.City
            , ORDERS.loadkey
            , ORDERS.userdefine02
            , TTLREC = (SELECT  COUNT(DISTINCT (S.Style+S.Busr9)+S.Busr7+S.Busr5) FROM dbo.PACKDETAIL PD (NOLOCK) 
                        JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.storerkey AND S.sku = PD.sku WHERE PD.Pickslipno =dbo.PackDetail.Pickslipno
                        AND PD.cartonno = dbo.PackDetail.Cartonno)     
            , CASE WHEN PICKDETAIL.UOM = '2' THEN RIGHT(RTRIM(PICKDETAIL.CaseID),4) ELSE '' END AS CaseID
            , CASE WHEN PackDetail.CartonNo = @n_LastCarton THEN N'尾箱' ELSE N'' END AS LastCartonFlag   --WL01
     FROM dbo.PackHeader WITH (NOLOCK) 
     JOIN dbo.LoadPlanDetail WITH (NOLOCK) ON (dbo.LoadPlanDetail.Loadkey = dbo.Packheader.Loadkey) 
     JOIN dbo.ORDERS WITH (NOLOCK) ON (dbo.Orders.Orderkey = dbo.LoadPlanDetail.Orderkey) 
     JOIN dbo.PackDetail WITH (NOLOCK) ON (dbo.PackHeader.PickSlipNo = dbo.PackDetail.PickSlipNo) 
     JOIN dbo.STORER SR WITH (NOLOCK) ON (dbo.ORDERS.Storerkey = SR.Storerkey)
     LEFT JOIN dbo.STORER WITH (NOLOCK) ON (dbo.STORER.Storerkey =  RTRIM(dbo.ORDERS.BillToKey)+RTRIM(dbo.ORDERS.ConsigneeKey))
     LEFT JOIN dbo.CODELKUP WITH (NOLOCK) ON (dbo.ORDERS.BillToKey = dbo.CODELKUP.Code AND dbo.CODELKUP.Listname = 'LFA2LFK')     
     LEFT JOIN dbo.ORDERS CHILDORD WITH (NOLOCK) ON (SR.Susr2 = CHILDORD.Storerkey AND dbo.ORDERS.BuyerPO = CHILDORD.ExternOrderkey
                                                AND ISNULL(dbo.CODELKUP.Code,'') <> '')
     JOIN dbo.PICKDETAIL WITH (NOLOCK) ON (dbo.PICKDETAIL.Orderkey = dbo.ORDERS.Orderkey) AND (dbo.PICKDETAIL.DropID = dbo.PackDetail.LabelNo)
     OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                  CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND
                 (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL 
     LEFT JOIN dbo.Packinfo WITH (NOLOCK) ON (dbo.PackDetail.Pickslipno = dbo.Packinfo.Pickslipno) 
                                         AND (dbo.PackDetail.CartonNo = dbo.Packinfo.CartonNo)
     WHERE (dbo.PackHeader.PickSlipNo= @c_PickSlipNo)        
     AND   (dbo.PackHeader.Storerkey = @c_StorerKey)
     AND   (dbo.PackDetail.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
     GROUP BY --//dbo.ORDERS.ExternOrderkey	//INC0244576
              CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.ConsigneeKey ELSE CHILDORD.Consigneekey END
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Company ELSE CHILDORD.C_Company END 
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address1 ELSE CHILDORD.C_Address1 END
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address2 ELSE CHILDORD.C_Address2 END
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address3 ELSE CHILDORD.C_Address3 END
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_Address4 ELSE CHILDORD.C_Address4 END
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_State ELSE CHILDORD.C_State END 
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.ORDERS.C_City ELSE CHILDORD.C_City END 
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') <> '' THEN CHILDORD.ExternOrderkey ELSE '' END 
            , dbo.ORDERS.BillToKey
            , dbo.ORDERS.MarkForKey
            , dbo.PackDetail.PickSlipNo
            , dbo.PackDetail.CartonNo
            , dbo.PackDetail.LabelNo
            , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN dbo.STORER.Storerkey ELSE NULL END
            , dbo.STORER.Company
            , dbo.STORER.Address1
            , dbo.STORER.Address2
            , dbo.STORER.Address3
            , dbo.STORER.Address4
            , dbo.STORER.State
            , dbo.STORER.City
            , ORDERS.loadkey
            , ORDERS.userdefine02
            , CASE WHEN PICKDETAIL.UOM = '2' THEN RIGHT(RTRIM(PICKDETAIL.CaseID),4) ELSE '' END
            , ISNULL(CL.Short,'N')
            , CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN ISNULL(Packinfo.CartonGID,'') ELSE PackDetail.LabelNo END
            , CASE WHEN PackDetail.CartonNo = @n_LastCarton THEN N'尾箱' ELSE N'' END   --WL01
      ORDER BY dbo.PackDetail.CartonNo,ORDERS.userdefine02
  END

END

GO