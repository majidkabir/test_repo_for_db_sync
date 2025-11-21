SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_87                            */
/* Creation Date:17-JUN-2019                                            */
/* Copyright: IDS                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose:  WMS-9435 - [CN] Super Hub Project _                        */ 
/*                      Lfkids_Carton Label Change                      */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_87                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 27/08/2019   WLChooi  1.1  WMS-9435 - Add new barcode (WL01)         */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_87] (
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

   DECLARE  @n_Continue     INT = 1
          , @c_NewLabelNo   NVARCHAR(50) = ''

   CREATE TABLE #TEMP_UCC87(
        ExternOrderkey      NVARCHAR(50)
      , ConsigneeKey        NVARCHAR(15)
      , C_Company           NVARCHAR(45)
      , C_Address1          NVARCHAR(45)
      , C_Address2          NVARCHAR(45)
      , C_Address3          NVARCHAR(45)
      , C_Address4          NVARCHAR(45)
      , C_State             NVARCHAR(45)
      , C_City              NVARCHAR(45)
      , ChildExternOrderkey NVARCHAR(50)
      , BillToKey           NVARCHAR(15)
      , MarkForKey          NVARCHAR(15)
      , PickSlipNo          NVARCHAR(10)
      , CartonNo            INT
      , LabelNo             NVARCHAR(20)
      , Qty                 INT
      , Storerkey           NVARCHAR(15)
      , STCompany           NVARCHAR(45)
      , STAddress1          NVARCHAR(45)
      , STAddress2          NVARCHAR(45)
      , STAddress3          NVARCHAR(45)
      , STAddress4          NVARCHAR(45)
      , STState             NVARCHAR(45)
      , STCity              NVARCHAR(45)
      , OrdKey              NVARCHAR(10)
      , OHBuyerPO           NVARCHAR(20)
      , NewLabelNo          NVARCHAR(100)

   )

   IF (@n_Continue = 1 OR @n_Continue = 2 )
   BEGIN
      INSERT INTO #TEMP_UCC87
      SELECT ORDERS.ExternOrderkey
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.ConsigneeKey
                  ELSE CHILDORD.Consigneekey END AS Consigneekey
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Company
                  ELSE CHILDORD.C_Company END AS C_Company
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address1
                  ELSE CHILDORD.C_Address1 END AS C_Address1
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address2
                  ELSE CHILDORD.C_Address2 END AS C_Address2
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address3
                  ELSE CHILDORD.C_Address3 END AS C_Address3
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address4
                  ELSE CHILDORD.C_Address4 END AS C_Address4
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_State
                  ELSE CHILDORD.C_State END AS C_State
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_City
                  ELSE CHILDORD.C_City END AS C_City
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') <> '' THEN 
                    CHILDORD.ExternOrderkey
                  ELSE '' END AS ChildExternOrderkey
	  	     , ORDERS.BillToKey
	  	     , ORDERS.MarkForKey
           , PackDetail.PickSlipNo
           , PackDetail.CartonNo
           , PackDetail.LabelNo
           /*, Qty = SUM(PackDetail.Qty)*/
           , Qty = (SELECT SUM(PD.QTY) FROM PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = PackDetail.Pickslipno
                    AND PD.cartonno = PackDetail.Cartonno)
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    STORER.Storerkey
                  ELSE NULL END AS Storerkey
	  	     , STORER.Company
	  	     , STORER.Address1
	  	     , STORER.Address2
	  	     , STORER.Address3
	  	     , STORER.Address4
	  	     , STORER.State
	  	     , STORER.City
           , OrdKey = ORDERS.Orderkey 
           , OHBuyerPO = ORDERS.BuyerPO
           , NewLabelNo = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN      --WL01  
                          CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LabelNo,CAST(CL.UDF02 AS INT),CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)
                          ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))
                          WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN              
                          CL.UDF01 + PACKDETAIL.LabelNo                                              
                          ELSE '' END
        FROM PackHeader WITH (NOLOCK) 
        JOIN ORDERS WITH (NOLOCK)   
	       ON (PackHeader.Orderkey = ORDERS.Orderkey) 
        JOIN PackDetail WITH (NOLOCK) 
	       ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo) 
        JOIN STORER SR WITH (NOLOCK)
          ON (ORDERS.Storerkey = SR.Storerkey)
        LEFT JOIN STORER WITH (NOLOCK) 
	       ON (STORER.Storerkey =  RTRIM(ORDERS.BillToKey)+RTRIM(ORDERS.ConsigneeKey))
        LEFT JOIN CODELKUP WITH (NOLOCK)
          ON (ORDERS.BillToKey = CODELKUP.Code AND CODELKUP.Listname = 'LFA2LFK')     
        LEFT JOIN ORDERS CHILDORD WITH (NOLOCK)
          ON (SR.Susr2 = CHILDORD.Storerkey AND ORDERS.BuyerPO = CHILDORD.ExternOrderkey
              AND ISNULL(CODELKUP.Code,'') <> '')
        OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                     CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = PackHeader.STORERKEY AND CL.CODE = 'SUPERHUB' AND
                    (CL.CODE2 = ORDERS.FACILITY OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL
       WHERE (PackHeader.PickSlipNo= @c_PickSlipNo)
	      AND (PackHeader.Storerkey = @c_StorerKey)
	      AND (PackDetail.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)
       GROUP BY ORDERS.ExternOrderkey
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.ConsigneeKey
                  ELSE CHILDORD.Consigneekey END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Company
                  ELSE CHILDORD.C_Company END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address1
                  ELSE CHILDORD.C_Address1 END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address2
                  ELSE CHILDORD.C_Address2 END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address3
                  ELSE CHILDORD.C_Address3 END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_Address4
                  ELSE CHILDORD.C_Address4 END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_State
                  ELSE CHILDORD.C_State END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    ORDERS.C_City
                  ELSE CHILDORD.C_City END
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') <> '' THEN 
                    CHILDORD.ExternOrderkey
                  ELSE '' END 
		     , ORDERS.BillToKey
		     , ORDERS.MarkForKey
		     , PackDetail.PickSlipNo
		     , PackDetail.CartonNo
		     , PackDetail.LabelNo
		     , CASE WHEN ISNULL(CHILDORD.Storerkey,'') = '' THEN 
                    STORER.Storerkey
                  ELSE NULL END
		     , STORER.Company
		     , STORER.Address1
		     , STORER.Address2
		     , STORER.Address3
		     , STORER.Address4
		     , STORER.State
		     , STORER.City
           , ORDERS.Orderkey
           , ORDERS.BuyerPO
           , ISNULL(CL.SHORT,'N')
           , CL.LONG       
           , CL.UDF01      
           , CL.UDF02      
           , CL.UDF03
       ORDER BY PackDetail.CartonNo
   END

   --Insert newly generate labelno into Packinfo table
   --IF (@n_Continue = 1 OR @n_Continue = 2 )
   --BEGIN
   --   SELECT TOP 1 @c_NewLabelNo = LabelNo
   --   FROM #TEMP_UCC87 
   --END

   SELECT * FROM #TEMP_UCC87


END

GO