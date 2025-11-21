SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_82                            */
/* Creation Date: 01-Apr-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose:  WMS-8457 - [CN] Super Hub Project _                        */ 
/*                      Mizuno Carton Label Change (CR                  */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_82                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 2019-04-29    WLCHOOI 1.0  WMS-8454 - Add new condition (WL01)      */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_82] (
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

  IF (@n_Continue = 1 OR @n_Continue = 2)
  BEGIN       
     SELECT DISTINCT dbo.Orders.ExternOrderkey
		  , dbo.Orders.ConsigneeKey
	  	  , dbo.Orders.C_Company
	  	  , dbo.Orders.C_Address1
	  	  , dbo.Orders.C_Address2
	  	  , dbo.Orders.C_Address3
	  	  , dbo.Orders.C_State
	  	  , dbo.Orders.C_City
	  	  , dbo.Orders.Storerkey
	  	  , dbo.PackHeader.LoadKey
	  	  , dbo.PackHeader.PickSlipNo
        , dbo.PackDetail.CartonNo
        , dbo.PackDetail.LabelNo
        , dbo.Sku.SkuGroup
        , dbo.CodeLkUp.Short
		  , dbo.PackInfo.CartonType
        , TotalCTN = (SELECT COUNT(Distinct PD.CartonNo)
							 FROM dbo.PackDetail PD WITH (NOLOCK) 
			  				 WHERE PD.PickSlipNo = dbo.PackHeader.PickSlipNo)    
        , TotalQty = (SELECT SUM(PD.Qty)
							 FROM dbo.PackDetail PD WITH (NOLOCK) 
			  				 WHERE PD.PickSlipNo = dbo.PackHeader.PickSlipNo
                      AND PD.CartonNo = dbo.Packdetail.CartonNo)    
        , dbo.Orders.IntermodalVehicle
        , TotalCarton = (SELECT COUNT(DISTINCT PD.LabelNo) 
                         FROM dbo.PACKDETAIL PD (NOLOCK)
                         WHERE PD.Pickslipno = dbo.PackHeader.Pickslipno) 
        , dbo.Packheader.Status 
        ,buyerpobarcode = (orders.buyerpo + '-' + RIGHT('00'+CONVERT(NVARCHAR(5),packdetail.cartonno),3))
        ,showbuyerpobarcode = ISNULL(CLR1.Short,'N')
        ,showfield = ISNULL(CLR2.Short,'N')
        ,ISNULL(Orders.Door,'') as door
        ,ISNULL(CLR3.Short,'N') as showDC
        ,'' as Lottable02
        ,CASE WHEN ISNULL(CLR4.SHORT,'N') = 'Y' AND CAST(CLR4.LONG AS INT) <> 0 THEN    --WL01
         CLR4.UDF01 + RIGHT(REPLICATE('0',CLR4.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CLR4.UDF02 AS INT),CAST(CLR4.UDF03 AS INT)-CAST(CLR4.UDF02 AS INT)+1)
                                       ,CAST(CLR4.LONG AS INT)-LEN(CLR4.UDF01))
         WHEN ISNULL(CLR4.SHORT,'N') = 'Y' AND CAST(CLR4.LONG AS INT) = 0 THEN     --WL01
         CLR4.UDF01 + PACKDETAIL.LABELNO                                           --WL01
         ELSE '' END AS NewLabelNo                
     FROM dbo.PackHeader WITH (NOLOCK) 
     JOIN dbo.Orders WITH (NOLOCK) ON (dbo.PackHeader.Orderkey = dbo.Orders.Orderkey)
     --JOIN dbo.Orderdetail WITH (NOLOCK) ON (dbo.Orderdetail.Orderkey = dbo.Orders.Orderkey) 
     JOIN dbo.PackDetail WITH (NOLOCK) ON (dbo.PackDetail.PickSlipNo = dbo.PackHeader.PickSlipNo) 
     JOIN dbo.Sku WITH (NOLOCK) ON (dbo.PackDetail.Storerkey = dbo.Sku.Storerkey) AND (dbo.PackDetail.Sku = dbo.SKU.Sku)
     JOIN dbo.CodeLkUp WITH (NOLOCK) ON (dbo.CodeLkUp.ListName like '%WESKUGRP%') AND (dbo.CodeLkUp.Code like '%MIX%')
     LEFT JOIN dbo.PackInfo WITH (NOLOCK) ON (dbo.PackInfo.PickSlipNo = dbo.PackDetail.PickSlipNo) AND (dbo.PackInfo.CartonNo = dbo.PackDetail.CartonNo)
     LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (Orders.Storerkey = CLR1.Storerkey AND CLR1.Code = 'ShowbuyerpoBarcode'   
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_ucc_carton_label_82' AND ISNULL(CLR1.Short,'') <> 'N')
     LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (Orders.Storerkey = CLR2.Storerkey AND CLR2.Code = 'showfield'   
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_dw_ucc_carton_label_82' AND ISNULL(CLR2.Short,'') <> 'N')
     LEFT OUTER JOIN Codelkup CLR3 (NOLOCK) ON (Orders.Storerkey = CLR3.Storerkey AND CLR3.Code = 'showDC'   
                                       AND CLR3.Listname = 'REPORTCFG' AND CLR3.Long = 'r_dw_ucc_carton_label_82' AND ISNULL(CLR3.Short,'') <> 'N')
     --LEFT OUTER JOIN CODELKUP CLR4 WITH (NOLOCK) ON (CLR4.LISTNAME = 'BARCODELEN' AND CLR4.STORERKEY = ORDERS.STORERKEY AND CLR4.CODE = 'SUPERHUB')
    -- CROSS APPLY (SELECT TOP 1 OD.LOTTABLE02 FROM ORDERDETAIL OD (NOLOCK) WHERE OD.SKU = PACKDETAIL.SKU AND OD.ORDERKEY = ORDERS.ORDERKEY) AS ORDERDETAIL
     OUTER APPLY (SELECT TOP 1 CLR4.SHORT, CLR4.LONG, CLR4.UDF01, CLR4.UDF02, CLR4.UDF03, CLR4.CODE2 FROM
                  CODELKUP CLR4 WITH (NOLOCK) WHERE (CLR4.LISTNAME = 'BARCODELEN' AND CLR4.STORERKEY = ORDERS.STORERKEY AND CLR4.CODE = 'SUPERHUB' AND
                 (CLR4.CODE2 = ORDERS.FACILITY OR CLR4.CODE2 = '') ) ORDER BY CASE WHEN CLR4.CODE2 = '' THEN 2 ELSE 1 END ) AS CLR4
     WHERE (dbo.PackHeader.PickSlipNo= @c_PickSlipNo) AND  (dbo.PackHeader.Storerkey = @c_StorerKey)
     AND  (dbo.PackDetail.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
     ORDER BY dbo.PackDetail.CartonNo
  END

END

GO