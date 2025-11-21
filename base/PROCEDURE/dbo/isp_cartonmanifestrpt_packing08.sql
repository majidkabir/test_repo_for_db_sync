SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_CartonManifestRpt_Packing08                    */  
/* Creation Date:26-SEP-2019                                            */  
/* Copyright: IDS                                                       */  
/* Written by:CSCHONG                                                   */  
/*                                                                      */  
/* Purpose: WMS-9020                                                    */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_CartonManifestRpt_Packing08]  
   @c_loadkey  NVARCHAR(20) ,  
   @c_Orderkey NVARCHAR(20),  
   @b_debug    NVARCHAR(1) = '0'   
AS  
BEGIN   
   SET NOCOUNT ON   
  
   DECLARE @c_Condition       NVARCHAR(4000),       
           @c_SQLStatement    NVARCHAR(MAX),   
           @c_OrderBy         NVARCHAR(2000),  
           @c_GroupBy         NVARCHAR(2000),  
           @c_Condition1      NVARCHAR(4000),  
           @c_OrderLineNumber NVARCHAR(5),  
           @c_ID              NVARCHAR(18),  
           @c_Consigneekey    NVARCHAR(15),  
           @c_Secondary       NVARCHAR(15),    
           @c_ExecStatements  NVARCHAR(MAX),  
           @c_ExecArguments   NVARCHAR(4000),  
           @c_PrintByLoad     NVARCHAR(1)     
      
  SET @c_Condition = ''  
  
  SET @c_PrintByLoad = 'N'  
  
  IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.loadkey = @c_loadkey)  
  BEGIN  
    SET @c_PrintByLoad = 'Y'  
  END  
  
   SET  @c_Condition1=' AND ORDERS.Orderkey = @c_Orderkey'  
  
   IF @c_PrintByLoad = 'Y'  
   BEGIN  
    SET @c_Condition = ' WHERE LOADPLAN.Loadkey = @c_loadkey '  
   END  
   ELSE  
   BEGIN  
     SET @c_Condition = ' WHERE PICKDETAIL.Dropid = @c_loadkey '  
   END  
  
    SELECT @c_OrderBy = 'ORDER BY ORDERS.EXTERNORDERKEY, PICKDETAIL.Dropid,PICKDETAIL.SKU '  
  
 SELECT @c_GroupBy = 'GROUP BY ORDERS.ConsigneeKey,ORDERS.C_Company,ORDERS.C_ADDRESS1,  ' +   
                     'ORDERS.C_ADDRESS2,ORDERS.C_Address3,ORDERS.ROUTE,ORDERS.ORDERKEY, ' +  
                     'ORDERS.EXTERNORDERKEY,LOADPLAN.LOADKEY,ORDERS.ORDERDATE,ORDERS.DELIVERYDATE,  ' +  
                     'LOADPLAN.CARRIERKEY,PICKDETAIL.SKU,SKU.Altsku,SKU.DESCR,SKU.PACKKEY, ' +  
                     'ORDERS.BuyerPO,ORDERS.ExternPOKey,ORDERS.InvoiceNo,CONVERT(NVARCHAR(60), ORDERS.Notes), ' +   
                     'ORDERS.B_contact1,ORDERS.B_Company,ORDERS.B_Address1,ORDERS.B_Address2,ORDERS.B_Address3, '+   
                     'ORDERS.B_Address4,ORDERS.B_City,ORDERS.B_State,ORDERS.B_Zip,ORDERS.B_Country,ORDERS.DOOR, '+  
                     'PICKDETAIL.Dropid,SKU.CLASS,SKU.BUSR6,SKU.BUSR7,SKU.Style,SKU.Color,SKU.Size '  
     
  
   SELECT @c_SQLStatement =  ' SELECT ORDERS.ConsigneeKey as Consigneekey,ORDERS.C_Company as c_Company,ORDERS.C_ADDRESS1 as c_address1'+  
                             ' ,ORDERS.C_ADDRESS2 as c_address2 ,ORDERS.C_Address3 as c_address3,ORDERS.ROUTE as route,ORDERS.ORDERKEY as Orderkey,  ' +  
                             ' ORDERS.EXTERNORDERKEY as EXTERNORDERKEY ,LOADPLAN.LOADKEY as LOADKEY,ORDERS.ORDERDATE as ORDERDATE,' +   
                             ' ORDERS.DELIVERYDATE as DELIVERYDATE,LOADPLAN.CARRIERKEY CARRIER, PICKDETAIL.SKU as SKU ,SKU.Altsku as Altsku,SKU.DESCR as DESCR, ' +  
                             ' UOM = (SELECT PACKUOM3 FROM PACK (NOLOCK) WHERE PACKKEY = SKU.PACKKEY), ' +  
                             ' SUM(PICKDETAIL.QTY) AS QTY, ' +  
                             ' BuyerPO = CASE WHEN ORDERS.BuyerPO IS NULL THEN ORDERS.ExternPOKey ' +  
                             '   ELSE ORDERS.BuyerPO END,                                  ' +  
                             ' ORDERS.InvoiceNo as InvoiceNo,CONVERT(NVARCHAR(60), ORDERS.Notes) Notes, '+  
                             ' ORDERS.B_contact1 as B_contact1, ORDERS.B_Company as B_Company,ORDERS.B_Address1 as B_Address1,ORDERS.B_Address2 as B_Address2,' +   
                             ' ORDERS.B_Address3 as B_Address3,ORDERS.B_Address4 as B_Address4,ORDERS.B_City as B_City,ORDERS.B_State as B_State,'+  
                             ' ORDERS.B_Zip as B_Zip,ORDERS.B_Country as B_Country,ORDERS.DOOR as DOOR,PICKDETAIL.Dropid as Dropid,SKU.CLASS as CLASS, '+  
                             ' SKU.BUSR6 as BUSR6,SKU.BUSR7 as BUSR7,SKU.Style as Style,SKU.Color as Color, SKU.Size as Size ' +  CHAR(13) +   
                             ' FROM LOADPLAN WITH (NOLOCK)  ' + CHAR(13) +   
                             ' JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey) ' + CHAR(13) +   
                             ' JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = Orders.Orderkey)   ' + CHAR(13) +   
                             ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) ' + CHAR(13) +   
                             ' JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey AND ORDERDETAIL.Sku = PICKDETAIL.Sku ' + CHAR(13) +   
                             '         AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)  ' + CHAR(13) +   
                             ' JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku) '  
  
  
  
    SELECT @c_ExecStatements = @c_SQLStatement + CHAR(13) + @c_Condition  + CHAR(13) + @c_Condition1  + CHAR(13) + @c_GroupBy + CHAR(13) + @c_OrderBy  
  
    SET @c_ExecArguments = N'@c_loadkey   NVARCHAR(20)'      
                        + ', @c_Orderkey  NVARCHAR(20) '      
                                        
   EXEC sp_ExecuteSql     @c_ExecStatements       
                        , @c_ExecArguments      
                        , @c_loadkey      
                        , @c_Orderkey      
  
  IF @b_debug ='1'  
  BEGIN  
    SELECT @c_ExecStatements  
  END  
     
END 

GO