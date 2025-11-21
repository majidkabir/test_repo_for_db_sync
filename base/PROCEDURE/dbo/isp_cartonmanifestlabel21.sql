SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_CartonManifestLabel21                          */
/* Creation Date: 09-JUNE-2017                                          */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-1954 -Charming Charlie Carton Labels                   */
/*                                                                      */
/* Input Parameters: PickSlipNo, CartonNoStart, CartonNoEnd             */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_Carton_manifest_label_21                            */
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

CREATE PROC [dbo].[isp_CartonManifestLabel21] (
         @c_PickSlipNo     NVARCHAR(20)
      ,  @c_StartCartonNo  NVARCHAR(20)
      ,  @c_EndCartonNo    NVARCHAR(20)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF      

  CREATE TABLE #TMP_CTNMNLBL21 (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          consigneekey    NVARCHAR(20) NULL,
          CTNID           NVARCHAR(20) NULL ,
          LenghtINCH      FLOAT,
          WIDTHINCH       FLOAT,
          HEIGHTINCH      FLOAT,
          LenghtCM        FLOAT,
          WIDTHCM         FLOAT,
          HEIGHTCM        FLOAT,
          WGTKG           FLOAT,
          WGTLBS          FLOAT

			 )                    

			

   INSERT INTO #TMP_CTNMNLBL21(Pickslipno,consigneekey,CTNID,LenghtINCH,WIDTHINCH,HEIGHTINCH,
                                 LenghtCM,WIDTHCM,HEIGHTCM,WGTKG,WGTLBS )  
    SELECT DISTINCT PACKHEADER.Pickslipno,  
			ORDERS.consigneekey,
			(ISNULL(ORDERS.ConsigneeKey,'')+ISNULL(PACKDETAIL.LabelNo,'')) AS CTNID,
			ROUND((CTN.CartonLength*0.393701),2) AS LenghtINCH,
			ROUND((CTN.CartonWidth*0.393701),2) AS WIDTHINCH,
			ROUND((ctn.CartonHeight*0.393701),2) AS HEIGHTINCH,
			ROUND((CTN.CartonLength),2) AS LenghtCM,
			ROUND((CTN.CartonWidth),2) AS WIDTHCM,
			ROUND((ctn.CartonHeight),2) AS HEIGHTCM,
			ROUND(PCIF.Weight,2) AS WGTKG,ROUND((PCIF.Weight*2.20462),2) AS WGTLBS
	FROM ORDERS ORDERS (NOLOCK) 
	JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
	JOIN PACKHEADER (NOLOCK) ON (ORDERS.LoadKey = PACKHEADER.LoadKey)
	JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND PACKDETAIL.SKU = ORDERDETAIL.SKU) 
	LEFT JOIN PACKINFO PCIF WITH (NOLOCK) ON PCIF.PickSlipNo =PACKHEADER.PickSlipNo AND PCIF.CartonNo = PACKDETAIL.CartonNo
	JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.ORDERKEY = ORDERS.ORDERKEY AND PICKDETAIL.DROPID = PACKDETAIL.DROPID)
	JOIN STORER WITH(NOLOCK) ON STORER.StorerKey = ORDERS.StorerKey
	LEFT JOIN  CARTONIZATION CTN (NOLOCK) ON CTN.cartontype=PCIF.cartontype AND CTN.cartonizationgroup = STORER.CartonGroup
   WHERE PACKDETAIL.Pickslipno = @c_PickSlipNo
   --AND   PACKDETAIL.Storerkey = @c_StorerKey
   AND PACKDETAIL.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
  
 
 

	SELECT Pickslipno,consigneekey,CTNID,LenghtINCH,WIDTHINCH,HEIGHTINCH,
                                 LenghtCM,WIDTHCM,HEIGHTCM,WGTKG,WGTLBS
	FROM #TMP_CTNMNLBL21
	
END


GO