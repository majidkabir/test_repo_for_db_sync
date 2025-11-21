SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_Print_UCC_CartonLabel_44                        */
/* Creation Date: 15-Jun-2016                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  [TW] Add Carton Label For Le Creuset (SOS371947)           */
/*                                                                      */
/* Input Parameters: @cStorerKey - StorerKey,                           */
/*                   @cPickSlipNo - Pickslipno,                         */
/*                   @cFromCartonNo - From CartonNo,                    */
/*                   @cToCartonNo - To CartonNo,                        */
/*                                                                      */
/*                                                                      */
/* Usage: Call by dw = r_dw_ucc_carton_label_44                         */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_UCC_CartonLabel_44] ( 
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10), 
   @cFromCartonNo NVARCHAR( 10),
   @cToCartonNo   NVARCHAR( 10) )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_debug int

   DECLARE 
      @nFromCartonNo         int,
      @nToCartonNo           int,
      @cUCC_LabelNo          NVARCHAR( 20)
     


   DECLARE @n_Address1Mapping INT
         , @n_C_CityMapping   INT
   
   SET @b_debug = 0

   SET @nFromCartonNo = CAST( @cFromCartonNo AS int)
   SET @nToCartonNo = CAST( @cToCartonNo AS int)


   SELECT Row_Number() OVER (PARTITION BY PACKHEADER.PickSlipNo, PACKDETAIL.CartonNo ORDER BY PACKDETAIL.SKU Asc) AS RowID,
          PACKHEADER.PickSlipNo AS Pickslipno, 
          ORDERS.ExternOrderKey AS ExternOrderKey,
          CONVERT(NVARCHAR(10),LPD.DeliveryDate,111) AS DeliveryDate, 
          ORDERS.C_Company AS C_Company, 
         ISNULL(RTRIM(ORDERS.C_Address1),'') AS C_Address1,
          PACKDETAIL.SKU AS SKU,
          SKU.Descr AS SDescr,
		    PACKDETAIL.Qty AS qty,
          (RTRIM(FAC.address1) + '/' + FAC.Phone1) AS STO_Address,
         PACKDETAIL.CartonNo AS CartonNo,
         IDS.Company AS Company
  FROM ORDERS ORDERS (NOLOCK) 
  JOIN PACKHEADER PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
  JOIN PACKDETAIL PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
  JOIN LoadplanDetail LPD (NOLOCK) ON LPD.loadkey = PACKHEADER.loadkey AND  LPD.Orderkey=PACKHEADER.Orderkey
  JOIN SKU SKU (NOLOCK) ON (PACKDETAIL.Sku = SKU.Sku AND PACKDETAIL.StorerKey = SKU.StorerKey)
  JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
  LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = 'LCTOFFICE')
  LEFT JOIN Facility FAC (NOLOCK) ON FAC.Facility = ORDERS.Facility
  WHERE ORDERS.StorerKey = @cStorerKey 
   AND PACKHEADER.PickSlipNo = @cPickSlipNo 
   AND PACKDETAIL.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo  
 

END

GO