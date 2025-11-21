SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_Print_UCC_CartonLabel_tbl_03                    */
/* Creation Date: 08/03/2022                                            */
/* Copyright: IDS                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose:  WMS-19096 SG - SG - TBLSG - Carton Label [CR]              */
/*                                                                      */
/* Input Parameters: @cStorerKey - StorerKey,                           */
/*                   @cPickSlipNo - Pickslipno,                         */
/*                   @cFromCartonNo - From CartonNo,                    */
/*                   @cToCartonNo - To CartonNo,                        */
/*                   @cFilePath - File path that store the barcode      */
/*                                                                      */
/* Usage: Call by dw = r_dw_ucc_carton_label_tbl_03                     */
/*                copy from r_hk_ucc_carton_label_14                    */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*08-MAR-2022   CSCHONG       Devops Scripts Combine                    */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_UCC_CartonLabel_tbl_03] (
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
      @cUCC_LabelNo          NVARCHAR( 20),
      @cUCC_FilePath_Barcode NVARCHAR( 200)   -- using file path + bmp to display barcode

   DECLARE @n_Address1Mapping INT
         , @n_C_CityMapping   INT
         , @n_ShowAddr2And3      INT
         , @c_FromLFName         NVARCHAR(60)
         , @c_ShowDeliveryDate   INT
         , @c_showohnotes        INT

   SET @b_debug = 0

   SET @nFromCartonNo = CAST( @cFromCartonNo AS int)
   SET @nToCartonNo = CAST( @cToCartonNo AS int)

   SET @cUCC_LabelNo = ''
   SET @cUCC_FilePath_Barcode = ''

   SELECT @cUCC_LabelNo = LabelNo
   FROM PACKDETAIL (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   AND StorerKey = @cStorerKey
   AND CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo
   GROUP BY LabelNo


   SET @n_Address1Mapping = 0
   SET @n_C_CityMapping   = 0

   SELECT @n_Address1Mapping = MAX(CASE WHEN Code = 'C_ADDRESS1' THEN 1 ELSE 0 END)
        , @n_C_CityMapping   = MAX(CASE WHEN Code = 'C_CITY'     THEN 1 ELSE 0 END)
   FROM CODELKUP IWHT (NOLOCK)
   WHERE ListName = 'UCCLBLTBL'
   AND StorerKey  = @cStorerKey

   SET @n_ShowAddr2And3 = 0
   SET @c_FromLFName  = ''
   SET @c_ShowDeliveryDate = 0
   SELECT @n_ShowAddr2And3 = ISNULL(MAX(CASE WHEN Code = 'ShowAddr2And3' THEN 1 ELSE 0 END),0)
        , @c_FromLFName  = ISNULL(MAX(CASE WHEN Code = 'FromLFName'  THEN UDF01 ELSE '' END),'')
        , @c_ShowDeliveryDate = ISNULL(MAX(CASE WHEN Code = 'ShowDeliveryDate' THEN 1 ELSE 0 END),0)
        , @c_showohnotes = ISNULL(MAX(CASE WHEN Code = 'SHOWOHNOTES' THEN 1 ELSE 0 END),0)
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Listname = 'REPORTCFG'
   AND CL.Storerkey = @cStorerKey
   AND CL.Long = 'r_dw_ucc_carton_label_tbl_03'
   AND ISNULL(CL.Short,'') <> 'N'

SELECT DISTINCT
       PACKHEADER.PickSlipNo
     , ORDERS.Route
     , PACKDETAIL.CartonNo
     , PACKDETAIL.LabelNo
     , Type           = ISNULL(RTRIM(ORDERS.Type),'')
     , ExternOrderKey = ISNULL(RTRIM(ORDERS.ExternOrderKey),'')
     , DischargePlace = ISNULL(RTRIM(ORDERS.DischargePlace),'')
     , ConsigneeKey   = ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
     , C_Company      = ISNULL(RTRIM(ORDERS.C_Company),'')
     , C_Address1     = ISNULL(RTRIM(ORDERS.C_Address1),'')
     , C_Address2     = ISNULL(RTRIM(ORDERS.C_Address2),'')
     , C_Address3     = ISNULL(RTRIM(ORDERS.C_Address3),'')
     , C_Address4     = ISNULL(RTRIM(ORDERS.C_Address4),'')
     , C_City         = ISNULL(RTRIM(ORDERS.C_City),'')
     , C_Zip          = ISNULL(RTRIM(ORDERS.C_Zip),'')
     , FromCompany    = ISNULL(RTRIM(IDS.Company),'')
     , FromAddress1   = ISNULL(RTRIM(IDS.Address1),'')
     , FromAddress2   = ISNULL(RTRIM(IDS.Address2),'')
     , FromAddress3   = ISNULL(RTRIM(IDS.Address3),'')
     , CartonType     = ISNULL(RTRIM(CL.Short),'')
     , STO_HUB        = (  SELECT TOP 1 ISNULL(RTRIM(UserDefine06),'')
                           FROM ORDERDETAIL WITH (NOLOCK)
                           WHERE Orderkey = ORDERS.OrderKey
                           ORDER BY OrderLineNumber )
     , STO_SATELLITE  = (  SELECT TOP 1 ISNULL(RTRIM(UserDefine09),'')
                           FROM ORDERDETAIL WITH (NOLOCK)
                           WHERE Orderkey = ORDERS.OrderKey
                           ORDER BY OrderLineNumber )
     , PrintedDate    = GetDate()
     , Refno          = CASE WHEN ISNULL(PACKDETAIL.refno,'') <> '' THEN 'Inbound UCC#:  ' + ISNULL(PACKDETAIL.refno,'')  ELSE '' END
     , DeliveryDate   = ORDERS.DeliveryDate
     , (SELECT ISNULL(MAX(P2.CartonNo), '')
        FROM PACKDETAIL P2 (NOLOCK)
        WHERE P2.PickSlipNo = PACKHEADER.PickSlipNo) AS CartonMax    
     , ORDERS.OrderKey
     , SUM(PACKDETAIL.Qty) AS Qty
  FROM ORDERS WITH (NOLOCK)
  JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
  JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
  JOIN STORER     WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
  LEFT JOIN STORER   IDS WITH (NOLOCK) ON (IDS.Storerkey = '11301')
  LEFT JOIN CODELKUP CL  WITH (NOLOCK) ON (CL.Listname = 'ORDERTYPE') AND (CL.Code = ORDERS.Type)
 WHERE PACKHEADER.PickSlipNo = @cPickSlipNo
        AND PACKDETAIL.CartonNo BETWEEN @nFromCartonNo AND @cToCartonNo
 GROUP BY PACKHEADER.PickSlipNo
     , ORDERS.Route
     , PACKDETAIL.CartonNo
     , PACKDETAIL.LabelNo
     , ISNULL(RTRIM(ORDERS.Type),'')
     , ISNULL(RTRIM(ORDERS.ExternOrderKey),'')
     , ISNULL(RTRIM(ORDERS.DischargePlace),'')
     , ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
     , ISNULL(RTRIM(ORDERS.C_Company),'')
     , ISNULL(RTRIM(ORDERS.C_Address1),'')
     , ISNULL(RTRIM(ORDERS.C_Address2),'')
     , ISNULL(RTRIM(ORDERS.C_Address3),'')
     , ISNULL(RTRIM(ORDERS.C_Address4),'')
     , ISNULL(RTRIM(ORDERS.C_City),'')
     , ISNULL(RTRIM(ORDERS.C_Zip),'')
     , ISNULL(RTRIM(IDS.Company),'')
     , ISNULL(RTRIM(IDS.Address1),'')
     , ISNULL(RTRIM(IDS.Address2),'')
     , ISNULL(RTRIM(IDS.Address3),'')
     , ISNULL(RTRIM(CL.Short),'')
     , ISNULL(PACKDETAIL.refno,'')
     , ORDERS.DeliveryDate
     , ORDERS.OrderKey
ORDER  BY PACKHEADER.PickSlipNo,PACKDETAIL.CartonNo


END

GO