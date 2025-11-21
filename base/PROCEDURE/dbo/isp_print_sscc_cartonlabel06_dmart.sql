SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Print_SSCC_CartonLabel06_dmart                  */  
/* Creation Date: 18-OCT-2013                                            */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: SOS#241579: IDSCN QS Carton label                            */  
/*          SOS#292372: Change to dynamic sql and server link method to  */
/*          datamart                                                     */  
/* Called By: r_dw_sscc_cartonlabel06_dmart                              */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel06_dmart]
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


    SET @sql = '	SELECT DISTINCT  ' + char(10)
             + '			 PH.Storerkey ' + char(10)
             + '		 ,  PH.PickSlipNo ' + char(10)
             + '		 ,  CartonNo = CONVERT(VARCHAR(10), PD.CartonNo) ' + char(10)
             + '		 ,  UserDefine10 = ISNULL(RTRIM(ORDERS.UserDefine10),'''') ' + char(10)
             + '	FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKHEADER PH WITH (NOLOCK) ' + char(10)
             + '	JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS WITH (NOLOCK) ON (PH.Orderkey=ORDERS.Orderkey)   ' + char(10)
             + '	JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo) ' + char(10)
             + '	WHERE PH.Storerkey= @c_Storerkey   ' + char(10)
             + '	AND PH.PickSlipNo = @c_PickSlipNo   ' + char(10)
             + '	AND PD.CartonNo  >= @c_StartCartonNo  ' + char(10)
             + '	AND PD.CartonNo  <= @c_EndCartonNo'

   EXEC sp_executesql @sql,                                 
        N'@c_Storerkey NVARCHAR(15), @c_PickSlipNo NVARCHAR(10), @c_StartCartonNo NVARCHAR(10), @c_EndCartonNo NVARCHAR(10)', 
        @c_Storerkey,
        @c_PickSlipNo ,
        @c_StartCartonNo,
        @c_EndCartonNo
END

GO