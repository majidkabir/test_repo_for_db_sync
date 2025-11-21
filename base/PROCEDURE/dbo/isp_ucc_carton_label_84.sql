SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_84                            */
/* Creation Date: 01-Apr-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose:  WMS-8457 - [CN] Super Hub Project _                        */ 
/*                      Zippo-Carton Label Change (CR)                  */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_84                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_84] (
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
     SELECT dbo.ORDERS.Orderkey
		  , dbo.ORDERS.ExternOrderkey
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.ConsigneeKey
               ELSE CHILDORD.Consigneekey END AS Consigneekey
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Company
               ELSE CHILDORD.C_Company END AS C_Company
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address1
               ELSE CHILDORD.C_Address1 END AS C_Address1
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address2
               ELSE CHILDORD.C_Address2 END AS C_Address2
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address3
               ELSE CHILDORD.C_Address3 END AS C_Address3
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address4
               ELSE CHILDORD.C_Address4 END AS C_Address4
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_State
               ELSE CHILDORD.C_State END AS C_State
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_City
               ELSE CHILDORD.C_City END AS C_City
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') <> '' THEN 
                 CHILDORD.ExternOrderkey
               ELSE '' END AS ChildExternOrderkey
        , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN
            dbo.ORDERS.B_Company
            ELSE CHILDORD.B_Company END AS B_Company 
	  	  , dbo.ORDERS.BillToKey
	  	  , dbo.ORDERS.MarkForKey
        , dbo.PackDetail.PickSlipNo
        , dbo.PackDetail.CartonNo
        , dbo.PackDetail.LabelNo 
        /*, Qty = SUM(dbo.PackDetail.Qty)*/
        , Qty = (SELECT SUM(PD.QTY) FROM dbo.PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = dbo.PackDetail.Pickslipno
                 AND PD.cartonno = dbo.PackDetail.Cartonno)
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 NULL /* dbo.STORER.Storerkey */
               ELSE dbo.STORER.Storerkey /* NULL */ END AS Storerkey
	  	  , dbo.STORER.Company
	  	  , dbo.STORER.Address1
	  	  , dbo.STORER.Address2
	  	  , dbo.STORER.Address3
	  	  , dbo.STORER.Address4
	  	  , dbo.STORER.State
	  	  , dbo.STORER.City
        , CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN
			 CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)
                              ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))
          WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN
          CL.UDF01 + PACKDETAIL.LABELNO
          ELSE '' END AS NewLabelNo
     FROM dbo.PackHeader WITH (NOLOCK) 
     JOIN dbo.ORDERS WITH (NOLOCK)   
	    ON (dbo.PackHeader.Orderkey = dbo.ORDERS.Orderkey) 
     JOIN dbo.PackDetail WITH (NOLOCK) 
	    ON (dbo.PackHeader.PickSlipNo = dbo.PackDetail.PickSlipNo) 
     JOIN dbo.STORER SR WITH (NOLOCK)
       ON (dbo.ORDERS.Storerkey = SR.Storerkey)
     LEFT JOIN dbo.STORER WITH (NOLOCK) 
	    ON (dbo.STORER.Storerkey =  RTRIM(dbo.ORDERS.BillToKey)+RTRIM(dbo.ORDERS.ConsigneeKey))
     LEFT JOIN dbo.CODELKUP WITH (NOLOCK)
       ON (dbo.ORDERS.BillToKey = dbo.CODELKUP.Code AND dbo.CODELKUP.Listname = 'LFA2LFK')     
     LEFT JOIN dbo.ORDERS CHILDORD WITH (NOLOCK)
       ON (SR.Susr2 = CHILDORD.Storerkey AND dbo.ORDERS.BuyerPO = CHILDORD.ExternOrderkey
           AND ISNULL(dbo.CODELKUP.Code,'') <> '')
     --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB')
     OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                              CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = ORDERS.STORERKEY AND CL.CODE = 'SUPERHUB' AND
                             (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL 
    WHERE (dbo.PackHeader.PickSlipNo= @c_PickSlipNo)
	   AND (dbo.PackHeader.Storerkey = @c_StorerKey)
	   AND (dbo.PACKDETAIL.CartonNo BETWEEN CAST(@c_StartCartonNo as int) AND CAST(@c_EndCartonNo as Int) )
      GROUP BY dbo.ORDERS.Orderkey
		  , dbo.ORDERS.ExternOrderkey
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.ConsigneeKey
               ELSE CHILDORD.Consigneekey END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Company
               ELSE CHILDORD.C_Company END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address1
               ELSE CHILDORD.C_Address1 END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address2
               ELSE CHILDORD.C_Address2 END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address3
               ELSE CHILDORD.C_Address3 END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_Address4
               ELSE CHILDORD.C_Address4 END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_State
               ELSE CHILDORD.C_State END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 dbo.ORDERS.C_City
               ELSE CHILDORD.C_City END
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') <> '' THEN 
                 CHILDORD.ExternOrderkey
               ELSE '' END 
        , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN
            dbo.ORDERS.B_Company
            ELSE CHILDORD.B_Company END 
		  , dbo.ORDERS.BillToKey
		  , dbo.ORDERS.MarkForKey
		  , dbo.PackDetail.PickSlipNo
		  , dbo.PackDetail.CartonNo
		  , dbo.PackDetail.LabelNo
		  , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                 NULL /* dbo.STORER.Storerkey */
               ELSE dbo.STORER.Storerkey /* NULL */ END
		  , dbo.STORER.Company
		  , dbo.STORER.Address1
		  , dbo.STORER.Address2
		  , dbo.STORER.Address3
		  , dbo.STORER.Address4
		  , dbo.STORER.State
		  , dbo.STORER.City
		  , CL.LONG
		  , CL.UDF01
		  , CL.UDF02
		  , CL.UDF03
		  , ISNULL(CL.SHORT,'N')
     ORDER BY dbo.PackDetail.CartonNo
  END

END

GO