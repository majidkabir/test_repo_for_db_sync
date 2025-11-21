SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_03                     */
/* Creation Date: 18-Nov-2013                                           */
/* Copyright: IDS                                                        */
/* Written by: YTWan                                                     */
/*                                                                       */
/* Purpose: SOS#291999 - QS Label (Upgrade to SAP).                      */
/*          Sync with datamart datawindow to call SP                     */
/*          datamart                                                     */ 
/* Called By: r_dw_sscc_cartonlabel06_03                                 */
/*                                                                       */
/* PVCS Version: 1.2                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 28-Feb-2013  NJOW01   1.0  270640-extract data from datamart          */
/* 30-May-2013  Leong    1.1  SOS# 279572 - Change to unicode compatible.*/
/* 18-Nov-2013  YTWan    1.2  SOS#291999 - QS Label (Upgrade to SAP).    */
/*                            (wan01)                                    */ 
/*************************************************************************/

CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_03]
     @c_Storerkey      NVARCHAR(15)
   , @c_PickSlipNo     NVARCHAR(10)
   , @c_StartCartonNo  NVARCHAR(10)
   , @c_EndCartonNo    NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_CustSku          NVARCHAR(40)
          ,@sql                NVARCHAR(4000)
          ,@c_DataMartServerDB NVARCHAR(120)

   SET @c_CustSku = ''
   
   SELECT TOP 1
         @c_CustSku = ISNULL(RTRIM(OD.UserDefine01),'') + ISNULL(RTRIM(OD.UserDefine02),'')
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   JOIN ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = PH.Orderkey)
                                AND(OD.Storerkey= PD.Storerkey)
                                AND(OD.Sku      = PD.Sku)
   WHERE PH.Storerkey = @c_Storerkey
   AND PH.PickSlipNo = @c_PickSlipNo
   AND PD.CartonNo >= @c_StartCartonNo
   AND PD.CartonNo <= @c_EndCartonNo
   
  SELECT BuyerPO = ISNULL(RTRIM(ORDERS.BuyerPO),'')
     ,   BuyerPO_EAN128 = ISNULL(RTRIM(ORDERS.BuyerPO),'')
     ,   DeliveryPlace  = ISNULL(RTRIM(ORDERS.DeliveryPlace),'')
     ,   M_Company      = ISNULL(RTRIM(ORDERS.M_Company),'')
     ,   M_Address1     = ISNULL(RTRIM(ORDERS.M_Address1),'')
     ,   M_Address2     = ISNULL(RTRIM(ORDERS.M_Address2),'')
     ,   M_Address3     = ISNULL(RTRIM(ORDERS.M_Address3),'')
     ,   M_Address4     = ISNULL(RTRIM(ORDERS.M_Address4),'')
     ,   M_State        = ISNULL(RTRIM(ORDERS.M_State),'')
     ,   M_Zip          = ISNULL(RTRIM(ORDERS.M_Zip),'')
     ,   M_Country      = ISNULL(RTRIM(ORDERS.M_Country),'')
     ,   Company        = ISNULL(RTRIM(STORER.Company),'')
     ,   Address1       = ISNULL(RTRIM(STORER.Address1),'')
     ,   Address2       = ISNULL(RTRIM(STORER.Address2),'')
     ,   Address3       = ISNULL(RTRIM(STORER.Address3),'')
     ,   Address4       = ISNULL(RTRIM(STORER.Address4),'')
     ,   State          = ISNULL(RTRIM(STORER.State),'')
     ,   Zip            = ISNULL(RTRIM(STORER.Zip),'')
     ,   PD.CartonNo
     ,   LabelNo_EAN128  = '~202' + ISNULL(RTRIM(PD.LabelNo),'') 
     ,  QTY = SUM(PD.QTY)
     ,  CustSku = @c_CustSku + CASE WHEN COUNT(DISTINCT ISNULL(RTRIM(OD.UserDefine01),'') + ISNULL(RTRIM(OD.UserDefine02),'')) > 1
                                    THEN '*'
                                    ELSE ''
                                    END
     ,  CustSku_EAN128 =  '~202' + RTRIM(@c_CustSku)
     ,  LabelNo        = ISNULL(RTRIM(PD.LabelNo),'') 
     ,  Phone1         = ISNULL(RTRIM(STORER.Phone1),'')                   
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey)
   JOIN STORER STORER WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   JOIN ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = ORDERS.Orderkey)
                                    AND(OD.Storerkey= PD.Storerkey)
                                    AND(OD.Sku      = PD.Sku)
   WHERE PH.Storerkey = @c_Storerkey
   AND PH.PickSlipNo = @c_PickSlipNo
   AND PD.CartonNo >= @c_StartCartonNo
   AND PD.CartonNo <= @c_EndCartonNo
   GROUP BY PH.PickSlipNo,
        ISNULL(RTRIM(ORDERS.BuyerPO),'')
     ,  ISNULL(RTRIM(ORDERS.DeliveryPlace),'')
     ,  ISNULL(RTRIM(ORDERS.M_Company),'')
     ,  ISNULL(RTRIM(ORDERS.M_Address1),'')
     ,  ISNULL(RTRIM(ORDERS.M_Address2),'')
     ,  ISNULL(RTRIM(ORDERS.M_Address3),'')
     ,  ISNULL(RTRIM(ORDERS.M_Address4),'')
     ,  ISNULL(RTRIM(ORDERS.M_State),'')
     ,  ISNULL(RTRIM(ORDERS.M_Zip),'')
     ,  ISNULL(RTRIM(ORDERS.M_Country),'')
     ,  ISNULL(RTRIM(STORER.Company),'')
     ,  ISNULL(RTRIM(STORER.Address1),'')
     ,  ISNULL(RTRIM(STORER.Address2),'')
     ,  ISNULL(RTRIM(STORER.Address3),'')
     ,  ISNULL(RTRIM(STORER.Address4),'')
     ,  ISNULL(RTRIM(STORER.State),'')
     ,  ISNULL(RTRIM(STORER.Zip),'')
     ,  PD.CartonNo
     ,  ISNULL(RTRIM(PD.LabelNo),'')
     ,  ISNULL(RTRIM(STORER.Phone1),'')                     
 
END

GO