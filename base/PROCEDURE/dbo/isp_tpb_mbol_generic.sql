SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: isp_TPB_MBOL_Generic                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: TPB billing for Generic MBOL Transaction                    */      
/*                                                                      */      
/* Called By:  isp_TPBExtract                                           */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */   
/* 08-Jun-18    TLTING    1.1   pass in billdate                        */     
/************************************************************************/  



CREATE PROC [dbo].[isp_TPB_MBOL_Generic]
@n_WMS_BatchNo BIGINT,
@n_TPB_Key BIGINT,
@d_BillDate Date,
@n_RecCOUNT INT = 0 OUTPUT,
@n_debug INT = 0 
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF    
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF    
   SET NOCOUNT ON    
       
   Declare @d_Todate DATETIME
   Declare @d_Fromdate DATETIME
   Declare @c_COUNTRYISO nvarchar(5)
   
   DECLARE @c_SQLStatement       NVARCHAR(MAX),
              @c_SQLParm         NVARCHAR(4000),
              @c_SQLCondition    NVARCHAR(4000),
              @c_SQLGroup        NVARCHAR(4000)    
   
   -- format date filter yesterday full day
   SET @d_Fromdate = @d_BillDate -- CONVERT(CHAR(11), GETDATE() - 1 , 120)
   SELECT @d_Todate = CONVERT(CHAR(11), @d_Fromdate , 120) + '23:59:59:998'
   SET @n_RecCOUNT = 0
   
   --   3 char CountryISO code
   SELECT @c_COUNTRYISO = UPPER(ISNULL(RTRIM(NSQLValue), '')) FROM dbo.NSQLCONFIG (NOLOCK) WHERE ConfigKey = 'CountryISO'
   
   -- filtering condition 
   SELECT @c_SQLCondition = ISNULL(SQLCondition,'') FROM TPB_Config WITH (NOLOCK) WHERE TPB_Key = @n_TPB_Key   
   
   -- format the filtering condition   
   IF ISNULL(RTRIM(@c_SQLCondition) ,'') <> ''
   BEGIN
      SET @c_SQLCondition = ' AND ' + @c_SQLCondition 
   END
   
   -- Dynamic SQL

           SET @c_SQLGroup =
                  ' GROUP BY UPPER(RTRIM(ORDERS.Facility)) '  +
                  ',MBOL.AddDate ' +   
                  ',MBOL.AddWho ' +  
                  ',MBOL.EditDate ' + 
                  ',MBOL.EditWho ' +  
                  ',RTRIM(ORDERS.Status) ' +   
                  ',RTRIM(ORDERS.Type) ' +  
                  ',RTRIM(ORDERS.Orderkey) ' +  
                  ',RTRIM(MD.MbolLineNumber) ' +  
                  ',RTRIM(ORDERS.ExternOrderKey) ' +  
                  ',UPPER(RTRIM(ORDERS.StorerKey)) ' +  
                  ',RTRIM(ORDERS.Consigneekey) ' +  
                  ',RTRIM(ORDERS.C_Company) ' +  
                  ',RTRIM(ORDERS.C_Country) ' +  
                  ',RTRIM(MD.LoadKey) ' +  
                  ',RTRIM(MBOL.MBOLKey) ' +  
                  ',RTRIM(MBOL.BookingReference) ' +  
                  ',RTRIM(ORDERS.Priority) ' + 
                  ',MBOL.ShipDate ' + 
                  ',PACKDETAIL.Qty ' + 
                  ',RTRIM(MBOL.NoofContainer) ' +  
                  ',RTRIM(MBOL.Vessel) ' +  
                  ',RTRIM(MBOL.VoyageNumber) ' +  
                  ',RTRIM(ORDERS.ContainerType) ' +  
                  ',RTRIM(MBOL.containerNo) ' +
                  ',RTRIM(ORDERS.UserDefine01) ' +
                  ',RTRIM(ORDERS.UserDefine02) ' +
                  ',RTRIM(ORDERS.UserDefine03) ' +
                  ',RTRIM(ORDERS.UserDefine04) ' +
                  ',RTRIM(ORDERS.UserDefine05) ' +
                  ',RTRIM(ORDERS.UserDefine06) ' +
                  ',RTRIM(ORDERS.UserDefine07) ' +
                  ',RTRIM(ORDERS.UserDefine08) ' +
                  ',RTRIM(ORDERS.UserDefine09) ' +
                  ',RTRIM(ORDERS.UserDefine10) ' +
                  ',MBOL.ShipDate '


         SET @c_SQLStatement = N'SELECT @n_WMS_BatchNo '+
                  ',@n_TPB_Key '+
                  ',''A'' '+           -- A = ACTIVITIES
                  ',''MBOL'' '+
                  ',@c_COUNTRYISO '+
                  ',UPPER(RTRIM(Orders.Facility)) ' +
                  ',MBOL.AddDate ' +
                  ',MBOL.AddWho ' +  
                  ',MBOL.EditDate ' +  
                  ',MBOL.EditWho ' +  
                  ',''WMS'' ' +  
                  ',RTRIM(ORDERS.Status) ' +  
                  ',''M'' ' +  
                  ',RTRIM(ORDERS.Type) ' +  
                  ',RTRIM(ORDERS.Orderkey) ' +  
                  ',RTRIM(MD.MbolLineNumber) ' +  
                  ',RTRIM(ORDERS.ExternOrderKey) ' +  
                  ',UPPER(RTRIM(ORDERS.StorerKey)) ' +  
                  ',RTRIM(ORDERS.Consigneekey) ' +  
                  ',RTRIM(ORDERS.C_Company) ' +  
                  ',RTRIM(ORDERS.C_Country) ' +  
                  ',RTRIM(MD.LoadKey) ' +  
                  ',RTRIM(MBOL.MBOLKey) ' +  
                  ',RTRIM(MBOL.BookingReference) ' +  
                  ',RTRIM(ORDERS.Priority) ' +  
                  ',MBOL.ShipDate ' +     
                  ','''' ' +               -- ORDERDETAIL.UOM    
                  ',RTRIM(MBOL.NoofContainer) ' +  
                  ',RTRIM(MBOL.Vessel) ' +  
                  ',RTRIM(MBOL.VoyageNumber) ' +  
                  ',RTRIM(ORDERS.ContainerType) ' +  
                  ',RTRIM(MBOL.containerNo) ' +    -- ORDERS.ContainerKey
                  ','''' ' +                -- ORDERDETAIL.PalletKey
                  ',RTRIM(ORDERS.UserDefine01) ' +  
                  ',RTRIM(ORDERS.UserDefine02) ' +
                  ',RTRIM(ORDERS.UserDefine03) ' +
                  ',RTRIM(ORDERS.UserDefine04) ' +
                  ',RTRIM(ORDERS.UserDefine05) ' +
                  ',RTRIM(ORDERS.UserDefine06) ' +
                  ',RTRIM(ORDERS.UserDefine07) ' +
                  ',RTRIM(ORDERS.UserDefine08) ' +
                  ',RTRIM(ORDERS.UserDefine09) ' +
                  ',RTRIM(ORDERS.UserDefine10) ' 
 
          SET @c_SQLStatement = @c_SQLStatement +
                  N'FROM dbo.MBOL (NOLOCK) ' +  
                  'JOIN dbo.MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MBOL.MbolKey   ' +  
                  'JOIN dbo.Orders (NOLOCK) ON ORDERS.OrderKey = MD.OrderKey ' +  
                  'JOIN dbo.PackHeader (NOLOCK) ON PackHeader.OrderKey = ORDERS.OrderKey ' +  
                  'JOIN dbo.packdetail (NOLOCK) ON PackDetail.PickSlipNo = PackHeader.PickSlipNo ' +  
                  'JOIN dbo.LOADPLAN (NOLOCK) ON LOADPLAN.LoadKey = MD.LoadKey  ' +  
                  'WHERE orders.Status = ''9'' ' +  
                  'AND MBOL.ShipDate BETWEEN @d_Fromdate AND @d_Todate ' + 
                  @c_SQLCondition + @c_SQLGroup 

   
      SET @c_SQLParm = '@n_WMS_BatchNo BIGINT, @n_TPB_Key nvarchar(5), @c_COUNTRYISO Nvarchar(5), @d_Fromdate DATETIME, @d_Todate DATETIME'


      IF @n_debug = 1
      BEGIN
         PRINT 'COUNTRYISO - ' + @c_COUNTRYISO
         PRINT '@c_SQLCondition'
         PRINT @c_SQLCondition
         PRINT '@c_SQLStatement'
         PRINT @c_SQLStatement
         PRINT '@c_SQLParm'
         PRINT @c_SQLParm
      END
          
      -- INSERT Data
      INSERT INTO [DBO].[WMS_TPB_BASE](
        BatchNo 
        ,CONFIG_ID
        ,TRANSACTION_TYPE 
        ,CODE 
        ,COUNTRY 
        ,SITE_ID 
        ,ADD_DATE 
        ,ADD_WHO 
        ,EDIT_DATE 
        ,EDIT_WHO 
        ,DOC_SOURCE 
        ,DOC_STATUS 
        ,DOC_TYPE     
        ,DOC_SUB_TYPE 
        ,DOCUMENT_ID 
        ,DOCUMENT_LINE_NO 
        ,CLIENT_REF 
        ,CLIENT_ID 
        ,SHIP_TO_ID    
        ,SHIP_TO_COMPANY 
        ,SHIP_TO_COUNTRY 
        ,LOAD_PLAN_NO 
        ,MBOL_NO 
        ,OTHER_REFERENCE_1 
        ,[PRIORITY]       
        ,REFERENCE_DATE
        ,QTY_UOM
        ,BILLABLE_CONTAINER
        ,VESSEL_ID
        ,VOYAGE_ID
        ,CONTAINER_TYPE
        ,CONTAINER_ID
        ,PALLET_ID
        ,H_USD_01  
        ,H_USD_02  
        ,H_USD_03  
        ,H_USD_04  
        ,H_USD_05  
        ,H_USD_06  
        ,H_USD_07  
        ,H_USD_08  
        ,H_USD_09  
        ,H_USD_10  
        )    
    EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParm, @n_WMS_BatchNo, @n_TPB_Key, @c_COUNTRYISO, @d_Fromdate, @d_Todate
    SET @n_RecCOUNT = @@ROWCOUNT

      IF @n_debug = 1
      BEGIN
         PRINT 'Record Count - ' + CAST(@n_RecCOUNT AS NVARCHAR)
         PRINT ''
      END 
 END

GO