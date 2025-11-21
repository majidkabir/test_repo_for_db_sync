SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_02_dmart               */  
/* Creation Date: 18-OCT-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#241579: IDSCN QS Carton label                            */  
/*          SOS#292372: Change to dynamic sql and server link method to  */
/*          datamart                                                     */  
/* Called By: r_dw_sscc_cartonlabel06_02_dmart                           */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver  Purposes                                    */  
/* 18-Nov-2013  YTWan   1.1  SOS#291999 - QS Label (Upgrade to SAP).     */
/*                            (wan01)                                    */
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_02_dmart]
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

   DECLARE @sql                NVARCHAR(4000)
          ,@c_DataMartServerDB NVARCHAR(120)
   
   SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'') 
   FROM NSQLCONFIG (NOLOCK)    
   WHERE ConfigKey='DataMartServerDBName'   
   
   IF ISNULL(@c_DataMartServerDB,'') = ''
      SET @c_DataMartServerDB = 'DATAMART'
   
   IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.' 
      SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'

   SET @sql = '	SELECT BuyerPO        = ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '			,  ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'''') ' + char(10)
            --+ '			,  MarkForKey     = ISNULL(RTRIM(SUBSTRING(ORDERS.MarkForKey,3,13)),'''') ' + char(10) --(Wan01)
            + '			,  MarkForKey     = ISNULL(RTRIM(ORDERS.MarkForKey),'''') ' + char(10)                 --(Wan01)
            + '			,  M_Company      = ISNULL(RTRIM(ORDERS.M_Company),'''') ' + char(10)
            + '			,  UserDefine03   = ISNULL(RTRIM(ORDERS.UserDefine03),'''') ' + char(10)
            + '			,  SalesMan       = ISNULL(RTRIM(ORDERS.SalesMan),'''') ' + char(10)
            + '			,  CartonNo       = ISNULL(PD.CartonNo,0) ' + char(10)
            + '			,	 Qty = SUM(PD.Qty) ' + char(10)
            + '			,  StdGrossWgt = SUM(SKU.StdGrossWgt * PD.Qty) ' + char(10)
            + '	 FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKHEADER PH WITH (NOLOCK)   ' + char(10)
            + '	 JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey)  ' + char(10)
            + '	 JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
            + '	 JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.SKU SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey) ' + char(10)
            + '										 AND(PD.Sku = SKU.Sku) ' + char(10)
            + '	WHERE PH.Storerkey  = @c_Storerkey ' + char(10)
            + '	  AND PH.PickSlipNo = @c_PickSlipNo ' + char(10)
            + '	  AND PD.CartonNo  >= @c_StartCartonNo  ' + char(10)
            + '	  AND PD.CartonNo  <= @c_EndCartonNo ' + char(10)
            + '	GROUP BY ISNULL(RTRIM(ORDERS.BuyerPO),'''') ' + char(10)
            + '		,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'''') ' + char(10)
            --+ '		,  ISNULL(RTRIM(SUBSTRING(ORDERS.MarkForKey,3,13)),'''') ' + char(10)                     --(Wan01)
            + '      , ISNULL(RTRIM(ORDERS.MarkForKey),'''')  ' + char(10)                                     --(Wan01)
            + '		,  ISNULL(RTRIM(ORDERS.M_Company),'''')  ' + char(10)
            + '		,  ISNULL(RTRIM(ORDERS.UserDefine03),'''') ' + char(10)
            + '		,  ISNULL(RTRIM(ORDERS.SalesMan),'''') ' + char(10)
            + '		,  ISNULL(PD.CartonNo,0) ' + char(10)
            + ''
            
   EXEC sp_executesql @sql,                                 
        N'@c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
        @c_Storerkey,
        @c_PickSlipNo ,
        @c_StartCartonNo,
        @c_EndCartonNo
END

GO