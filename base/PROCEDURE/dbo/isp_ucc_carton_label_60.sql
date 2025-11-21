SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_60                            */
/* Creation Date: 09-JUNE-2017                                          */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-1954 -Charming Charlie Carton Labels                   */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_60                                 */
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

CREATE PROC [dbo].[isp_UCC_Carton_Label_60] (
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

  CREATE TABLE #TMP_UCCCTNLBL60 (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          consigneekey    NVARCHAR(20) NULL,
          SHIPAdd1        NVARCHAR(45) NULL,
          SHIPCITY        NVARCHAR(45) NULL,
          SHIPSTATE       NVARCHAR(45) NULL,
          SHIPZIP         NVARCHAR(18) NULL,
          FROMAdd1        NVARCHAR(45) NULL,
          FROMCITY        NVARCHAR(45) NULL,
          FROMSTATE       NVARCHAR(45) NULL,
          FROMZIP         NVARCHAR(45) NULL,
          LabelNo         NVARCHAR(20) NULL,
          CTNID           NVARCHAR(20) NULL ,
          LFCTNID         NVARCHAR(20) NULL, 
			 )                    

			

   INSERT INTO #TMP_UCCCTNLBL60(Pickslipno,consigneekey,SHIPAdd1,SHIPCITY,SHIPSTATE,SHIPZIP,
                                 FROMAdd1,FROMCITY,FROMSTATE,FROMZIP,LabelNo,CTNID,
                                 LFCTNID )  
  SELECT  DISTINCT PACKHEADER.Pickslipno, 
			 ISNULL(ORDERS.ConsigneeKey,'') AS Consigneekey,      
			 ISNULL(ORDERS.C_Address1,'') AS SHIPAdd1, 
			 ISNULL(ORDERS.C_City,'') AS SHIPCITY,
			 ISNULL(ORDERS.C_State,'') AS SHIPSTATE,
			 ISNULL(ORDERS.C_Zip,'') AS SHIPZIP,
			 ISNULL(F.Address1,'') FROMAdd1, 
			 ISNULL(F.Address2,'') FROMSTATE,
			 ISNULL(F.Address3,'') FROMCITY,
			 ISNULL(F.Address4,'') FROMZIP,
			 ISNULL(PACKDETAIL.LabelNo,'') AS labelno,
			 (ISNULL(ORDERS.ConsigneeKey,'')+ISNULL(PACKDETAIL.LabelNo,'')) AS CTNID,
			 RIGHT('00000000000000000000' + (ISNULL(ORDERS.ConsigneeKey,'')+ISNULL(PACKDETAIL.LabelNo,'')),20) AS LFCTNID
  FROM ORDERS ORDERS (NOLOCK) 
  JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
  JOIN PACKHEADER (NOLOCK) ON (ORDERS.LoadKey = PACKHEADER.LoadKey)
  JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo) AND PACKDETAIL.SKU = ORDERDETAIL.SKU
  JOIN PICKDETAIL (NOLOCK) ON (PICKDETAIL.ORDERKEY = ORDERS.ORDERKEY AND PICKDETAIL.DROPID = PACKDETAIL.DROPID)
  JOIN STORER ST WITH(NOLOCK) ON ST.storerkey = ORDERS.ConsigneeKey
  JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORDERS.Facility
   WHERE PACKDETAIL.Pickslipno = @c_PickSlipNo
   --AND   PACKDETAIL.Storerkey = @c_StorerKey
   AND PACKDETAIL.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
  
 
 

	SELECT Pickslipno,consigneekey,SHIPAdd1,SHIPCITY,SHIPSTATE,SHIPZIP,
                                 FROMAdd1,FROMCITY,FROMSTATE,FROMZIP,LabelNo,CTNID,
                                 LFCTNID
	FROM #TMP_UCCCTNLBL60
	
END

GO