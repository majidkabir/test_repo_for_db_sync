SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_01_dmart               */  
/* Creation Date: 18-OCT-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#241579: IDSCN QS Carton label                            */  
/*          SOS#292372: Change to dynamic sql and server link method to  */
/*          datamart                                                     */  
/* Called By: r_dw_sscc_cartonlabel06_01_dmart                           */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */  
/* 18-Nov-2013  YTWan   1.2   SOS#291999 - QS Label (Upgrade to SAP).    */
/*                            (wan01)                                    */
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_01_dmart]
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

   SET @sql = 'SELECT DISTINCT ' + char(10)
            + '		   ORDERS.OrderGroup ' + char(10)
            + '		,  ORDERS.BuyerPO ' + char(10)
            + '		,  Consigneekey = SUBSTRING(ORDERS.Consigneekey,3,13) ' + char(10)
            + '		,  ORDERS.C_Company ' + char(10)                                   
            + '		,  ORDERS.C_Zip ' + char(10)
            --+ '		,  MarkForKey   = SUBSTRING(ORDERS.MarkForKey,3,13) ' + char(10)  --(Wan01)
            + '		,  MarkForKey ' + char(10)                                        --(Wan01)
            + '		,  ORDERS.M_Company ' + char(10)
            + '		,  ORDERS.M_Address1 ' + char(10)
            + '		,  ORDERS.M_Address2 ' + char(10)
            + '		,  ORDERS.M_Address3 ' + char(10)
            + '		,  ORDERS.M_Address4 ' + char(10)
            + '		,  ORDERS.M_State ' + char(10)
            + '		,  ORDERS.M_Zip ' + char(10)
            + '		,  ORDERS.M_Country ' + char(10)
            + '		,  PostCode = ''421036'' + CASE WHEN ISNULL(ORDERS.M_Zip,'''')='''' THEN ' + char(10)
            + '                                                        ISNULL(ORDERS.B_Zip,'''') ' + char(10)
            + '                                                       ELSE ORDERS.M_Zip END ' + char(10)
            + '		,  PostCode_EAN128 = ''~202'' + ''421036'' + CASE WHEN ISNULL(ORDERS.M_Zip,'''')='''' THEN ' + char(10)
            + '                                                        ISNULL(ORDERS.B_Zip,'''') ' + char(10)
            + '                                                       ELSE ORDERS.M_Zip END ' + char(10)
            + '		,  ORDERS.Userdefine01 ' + char(10)
            + '		,  ORDERS.Userdefine02 ' + char(10)
            + '		,  ORDERS.Userdefine03 ' + char(10)
            + '		,  ORDERS.Userdefine04 ' + char(10)
            + '		,  STORER.Company ' + char(10)
            + '		,  STORER.Address1 ' + char(10)
            + '		,  STORER.Address2 ' + char(10)
            + '		,  STORER.Address3 ' + char(10)
            + '		,  STORER.Address4 ' + char(10)
            + '		,  STORER.State ' + char(10)
            + '		,  STORER.Zip ' + char(10)
            + '		,  STORER.Country ' + char(10)
            + '		,  Notes1 = CONVERT(NVARCHAR(4000), STORER.Notes1) ' + char(10)
            + '		,  LabelNo = PD.LabelNo ' + char(10)
            + '		,  LabelNo_EAN128 = ''~202'' + PD.LabelNo ' + char(10)
            + '	   ,  Market = CL.Code ' + char(10)
            --+ '      ,  ORDERS.C_Company ' + char(10)                                --(Wan01)
            + '		,  ORDERS.DeliveryPlace ' + char(10)                              --(Wan01)
            + '      ,  ORDERS.SalesMan ' + char(10)
            + '      ,  ORDERS.UserDefine10 ' + char(10)
            + '      ,  ORDERS.ExternOrderkey ' + char(10)
            + '	 FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKHEADER PH WITH (NOLOCK) ' + char(10)
            + '	 JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PH.Orderkey) ' + char(10)
            + '  JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.STORER STORER WITH (NOLOCK) ON (ORDERS.Facility = STORER.Storerkey) ' + char(10)
            + '	 JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
            + '  LEFT JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.CODELKUP CL WITH (NOLOCK) ON (CL.ListName = ''QSFAC'') AND (CL.Short = ORDERS.Facility) ' + char(10)
            + '	WHERE PH.Storerkey  = @c_Storerkey ' + char(10)
            + '	  AND PH.PickSlipNo = @c_PickSlipNo ' + char(10)
            + '	  AND PD.CartonNo >= @c_StartCartonNo ' + char(10)
            + '	  AND PD.CartonNo <= @c_EndCartonNo'

   EXEC sp_executesql @sql,                                 
        N'@c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
        @c_Storerkey,
        @c_PickSlipNo ,
        @c_StartCartonNo,
        @c_EndCartonNo
END

GO