SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_03_dmart               */
/* Creation Date: 30-APR-2012                                            */
/* Copyright: IDS                                                        */
/* Written by: YTWan                                                     */
/*                                                                       */
/* Purpose: SOS#241579: IDSCN QS Carton label                            */
/*                                                                       */
/* Called By: r_dw_sscc_cartonlabel06_03_dmart                           */
/*                                                                       */
/* PVCS Version: 1.3                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 28-Feb-2013  NJOW01   1.0  270640-extract data from datamart          */
/* 30-May-2013  Leong    1.1  SOS# 279572 - Change to unicode compatible.*/
/* 18-Oct-2013  NJOW02   1.2  292372-change to dynamic sql and server    */
/*                            link method to datamart                    */
/* 18-Nov-2013  YTWan    1.3  SOS#291999 - QS Label (Upgrade to SAP).    */
/*                            (wan01)                                    */ 
/*************************************************************************/

CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_03_dmart]
     @c_Storerkey      NVARCHAR(15)
   , @c_PickSlipNo     NVARCHAR(10)
   , @c_StartCartonNo  NVARCHAR(10)
   , @c_EndCartonNo    NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON

   DECLARE @c_CustSku          NVARCHAR(40)
          ,@sql                NVARCHAR(4000)
          ,@c_DataMartServerDB NVARCHAR(120)

   SET @c_CustSku = ''
   
   SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'') 
   FROM NSQLCONFIG (NOLOCK)    
   WHERE ConfigKey='DataMartServerDBName'   
   
   IF ISNULL(@c_DataMartServerDB,'') = ''
      SET @c_DataMartServerDB = 'DATAMART'
   
   IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.' 
      SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'
   
   SET @sql = '   SELECT TOP 1 ' + char(10)
            + '          @c_CustSku = ISNULL(RTRIM(OD.UserDefine01),'''') + ISNULL(RTRIM(OD.UserDefine02),'''') ' + char(10)
            + '   FROM ' + RTRIM(@c_DataMartServerDB) + 'ODS.PACKHEADER PH WITH (NOLOCK) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ODS.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ODS.ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = PH.Orderkey) ' + char(10)
            + '                                    AND(OD.Storerkey= PD.Storerkey) ' + char(10)
            + '                                    AND(OD.Sku      = PD.Sku) ' + char(10)
            + '   WHERE PH.Storerkey = @c_Storerkey ' + char(10)
            + '     AND PH.PickSlipNo = @c_PickSlipNo ' + char(10)
            + '     AND PD.CartonNo >= @c_StartCartonNo ' + char(10)
            + '     AND PD.CartonNo <= @c_EndCartonNo'
   
   EXEC sp_executesql @sql,                                 
        N'@c_CustSku NVARCHAR(40) OUTPUT, @c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
        @c_CustSku OUTPUT, 
        @c_Storerkey,
        @c_PickSlipNo ,
        @c_StartCartonNo,
        @c_EndCartonNo

   SET @sql = 'SELECT ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '      ,  BuyerPO_EAN128 = ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '      ,  ORDERS.DeliveryPlace ' + char(10)
            + '      ,  ORDERS.M_Company ' + char(10)
            + '      ,  ORDERS.M_Address1 ' + char(10)
            + '      ,  ORDERS.M_Address2 ' + char(10)
            + '      ,  ORDERS.M_Address3 ' + char(10)
            + '      ,  ORDERS.M_Address4 ' + char(10)
            + '      ,  ORDERS.M_State ' + char(10)
            + '      ,  ORDERS.M_Zip ' + char(10)
            + '      ,  ORDERS.M_Country ' + char(10)
            + '      ,  STORER.Company ' + char(10)
            + '      ,  STORER.Address1 ' + char(10)
            + '      ,  STORER.Address2 ' + char(10)
            + '      ,  STORER.Address3 ' + char(10)
            + '      ,  STORER.Address4 ' + char(10)
            + '      ,  STORER.State ' + char(10)
            + '      ,  STORER.Zip ' + char(10)
            + '      ,  PD.CartonNo ' + char(10)
            + '      ,  LabelNo_EAN128 = ''~202'' + ISNULL(RTRIM(PD.LabelNo),'''')  ' + char(10)
            + '      ,  QTY = SUM(PD.QTY) ' + char(10)
            + '      ,  CustSku = @c_CustSku + CASE WHEN COUNT(DISTINCT ISNULL(RTRIM(OD.UserDefine01),'''') + ISNULL(RTRIM(OD.UserDefine02),'''')) > 1 ' + char(10)
            + '                                     THEN ''*'' ' + char(10)
            + '                                     ELSE '''' ' + char(10)
            + '                                     END ' + char(10)
            + '      , CustSku_EAN128 =  ''~202'' + RTRIM(@c_CustSku) ' + char(10)
            + '      , LabelNo = ISNULL(RTRIM(PD.LabelNo),'''')  ' + char(10)
            + '      , ISNULL(RTRIM(STORER.Phone1),'') ' + char(10)                    --(Wan01)
            + '   FROM ' + RTRIM(@c_DataMartServerDB) + 'ODS.PACKHEADER PH WITH (NOLOCK) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ODS.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ODS.STORER STORER WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ODS.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ODS.ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = ORDERS.Orderkey) ' + char(10)
            + '                                  AND(OD.Storerkey= PD.Storerkey) ' + char(10)
            + '                                  AND(OD.Sku      = PD.Sku) ' + char(10)
            + '   WHERE PH.Storerkey = @c_Storerkey ' + char(10)
            + '   AND PH.PickSlipNo = @c_PickSlipNo ' + char(10)
            + '   AND PD.CartonNo >= @c_StartCartonNo ' + char(10)
            + '   AND PD.CartonNo <= @c_EndCartonNo ' + char(10)
            + '   GROUP BY PH.PickSlipNo, ' + char(10)
            + '         ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '      ,  ORDERS.Consigneekey ' + char(10)
            + '      ,  ORDERS.M_Company ' + char(10)
            + '      ,  ORDERS.M_Address1 ' + char(10)
            + '      ,  ORDERS.M_Address2 ' + char(10)
            + '      ,  ORDERS.M_Address3 ' + char(10)
            + '      ,  ORDERS.M_Address4 ' + char(10)
            + '      ,  ORDERS.M_State ' + char(10)
            + '      ,  ORDERS.M_Zip ' + char(10)
            + '      ,  ORDERS.M_Country ' + char(10)
            + '      ,  STORER.Company ' + char(10)
            + '      ,  STORER.Address1 ' + char(10)
            + '      ,  STORER.Address2 ' + char(10)
            + '      ,  STORER.Address3 ' + char(10)
            + '      ,  STORER.Address4 ' + char(10)
            + '      ,  STORER.State ' + char(10)
            + '      ,  STORER.Zip ' + char(10)
            + '      ,  PD.CartonNo ' + char(10)
            + '      ,  ISNULL(RTRIM(PD.LabelNo),'''') ' + char(10)
            + '      , ISNULL(RTRIM(STORER.Phone1),'') ' + char(10)                    --(Wan01)
            + ''
   
   EXEC sp_executesql @sql,                                 
     N'@c_CustSku NVARCHAR(40), @c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
     @c_CustSku, 
     @c_Storerkey,
     @c_PickSlipNo ,
     @c_StartCartonNo,
     @c_EndCartonNo
END

GO