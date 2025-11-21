SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_04_dmart               */  
/* Creation Date: 30-APR-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#241579: IDSCN QS Carton label                            */  
/*                                                                       */  
/* Called By: r_dw_sscc_cartonlabel06_04_dmart                           */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 28-Feb-2013  NJOW01   1.0  270640-Add division field and extract data */
/*                            from datamart                              */
/* 18-Oct-2013  NJOW02   1.1  292372-change to dynamic sql and server    */
/*                            link method to datamart                    */
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_04_dmart]
      @c_Storerkey      NVARCHAR(15)
   ,  @c_PickSlipNo     NVARCHAR(10)
   ,  @c_StartCartonNo  NVARCHAR(10)
   ,  @c_EndCartonNo    NVARCHAR(10)
AS  
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON

   DECLARE @c_CustSku   NVARCHAR(18)
          ,@c_CustSize  NVARCHAR(18)
          ,@sql                NVARCHAR(4000)
          ,@c_DataMartServerDB NVARCHAR(120)

   SET @c_CustSku = ''
   SET @c_CustSize= ''
   
   SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'') 
   FROM NSQLCONFIG (NOLOCK)    
   WHERE ConfigKey='DataMartServerDBName'   
   
   IF ISNULL(@c_DataMartServerDB,'') = ''
      SET @c_DataMartServerDB = 'DATAMART'
   
   IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.' 
      SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'

   SET @sql = '   SELECT TOP 1  ' + char(10)
            + '          @c_CustSku = ISNULL(RTRIM(OD.UserDefine01),'''')  ' + char(10)
            + '         ,@c_CustSize= ISNULL(RTRIM(OD.UserDefine02),'''') ' + char(10)
            + '   FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKHEADER PH WITH (NOLOCK)   ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = PH.Orderkey) ' + char(10)
            + '                                    AND(OD.Storerkey= PD.Storerkey) ' + char(10)
            + '                                    AND(OD.Sku      = PD.Sku) ' + char(10)
            + '   WHERE PH.Storerkey = @c_Storerkey    ' + char(10)
            + '   AND PH.PickSlipNo = @c_PickSlipNo    ' + char(10)
            + '   AND PD.CartonNo >= @c_StartCartonNo  ' + char(10)
            + '   AND PD.CartonNo <= @c_EndCartonNo ' + char(10)
            + '   GROUP BY ISNULL(RTRIM(OD.UserDefine01),'''')  ' + char(10)
            + '         ,  ISNULL(RTRIM(OD.UserDefine02),'''')'

   EXEC sp_executesql @sql,                                 
        N'@c_CustSku NVARCHAR(18) OUTPUT, @c_CustSize NVARCHAR(18) OUTPUT, @c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
        @c_CustSku OUTPUT, 
        @c_CustSize OUTPUT, 
        @c_Storerkey,
        @c_PickSlipNo ,
        @c_StartCartonNo,
        @c_EndCartonNo
        
   SET @sql = '   SELECT BuyerPO   = ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '       ,  CartonNo  = ISNULL(PD.CartonNo,0) ' + char(10)
            + '       ,  PackedQty = SUM(PD.Qty) ' + char(10)
            + '       ,  CustSku  =  @c_CustSku ' + char(10)
            + '       ,  CustSize = @c_CustSize + CASE WHEN COUNT(ISNULL(RTRIM(OD.UserDefine02),'''')) > 1 ' + char(10)
            + '                                        THEN ''*''  ' + char(10)
            + '                                        ELSE '''' ' + char(10)
            + '                                        END ' + char(10)
            + '       ,  Division = CASE WHEN ISNULL(ORDERS.Stop,'''') IN ('''',''99'') THEN   ' + char(10)
            + '                          ''24'' ' + char(10)
            + '                     ELSE ORDERS.Stop END ' + char(10)
            + '   FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKHEADER PH WITH (NOLOCK)   ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey)  ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
            + '   JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERDETAIL OD WITH (NOLOCK)ON (OD.Orderkey = ORDERS.Orderkey) ' + char(10)
            + '                                  AND(OD.Storerkey= PD.Storerkey) ' + char(10)
            + '                                  AND(OD.Sku      = PD.Sku) ' + char(10)
            + '   WHERE PH.Storerkey = @c_Storerkey    ' + char(10)
            + '   AND PH.PickSlipNo = @c_PickSlipNo   ' + char(10)
            + '   AND PD.CartonNo >= @c_StartCartonNo  ' + char(10)
            + '   AND PD.CartonNo <= @c_EndCartonNo ' + char(10)
            + '   GROUP BY ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '         ,  ISNULL(PD.CartonNo,0) ' + char(10)
            + '         ,  CASE WHEN ISNULL(ORDERS.Stop,'''') IN ('''',''99'') THEN  ' + char(10)
            + '                 ''24'' ' + char(10)
            + '            ELSE ORDERS.Stop END'

   EXEC sp_executesql @sql,                                 
        N'@c_CustSku NVARCHAR(18), @c_CustSize NVARCHAR(18), @c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
        @c_CustSku, 
        @c_CustSize, 
        @c_Storerkey,
        @c_PickSlipNo ,
        @c_StartCartonNo,
        @c_EndCartonNo
END


GO