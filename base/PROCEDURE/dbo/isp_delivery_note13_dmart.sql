SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Delivery_Note13_dmart    	      		          */
/* Creation Date: 01/04/2015                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#336595                                                  */
/*                                                                      */
/* Called By: r_dw_delivery_note13_dmart                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note13_dmart] (@c_mbolkey NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    SET ANSI_NULLS ON
    SET ANSI_WARNINGS ON

    DECLARE @sql                NVARCHAR(MAX)
           ,@c_DataMartServerDB NVARCHAR(120)
           
    --SET @sql = 'SET ANSI_NULLS ON ' + CHAR(13) + 'SET ANSI_WARNINGS ON ' + CHAR(13)
    SET @sql = ''
    
    SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'') 
    FROM NSQLCONFIG (NOLOCK)     
    WHERE ConfigKey='DataMartServerDBName'   
    
    IF ISNULL(@c_DataMartServerDB,'') = ''
       SET @c_DataMartServerDB = 'DATAMART'
    
    IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.' 
       SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'

    SET @sql = @sql + N'SELECT ORDERS.Storerkey, ' 
             + '       SUBSTRING(ORDERS.ExternOrderKey,5,26) AS ExternOrderkey, ' 
             + '       ORDERS.Route, ' 
             + '       ORDERS.Facility,  ' 
             + '       ORDERS.ConsigneeKey,    ' 
             + '       ORDERS.C_Company,    ' 
             + '       ORDERS.C_Address1,    ' 
             + '       ORDERS.C_Address2,  ' 
             + '       ORDERS.C_Address3, ' 
             + '       ORDERS.C_Address4,    ' 
             + '	     ORDERS.C_City, ' 
             + '       ORDERS.C_Zip, ' 
             + '       ORDERS.C_Contact1, ' 
             + '       ORDERS.C_Contact2, ' 
             + '       ORDERS.C_Phone1, ' 
             + '       ORDERS.C_Phone2, ' 
             + '       ORDERS.BillToKey, ' 
             + '       ORDERS.B_Company,    ' 
             + '       ORDERS.B_Address1,    ' 
             + '       ORDERS.B_Address2,  ' 
             + '       ORDERS.B_Address3, ' 
             + '       ORDERS.B_Address4,   ' 
             + '	     ORDERS.B_City, ' 
             + '       ORDERS.B_Zip, ' 
             + '       ORDERS.B_Contact1, ' 
             + '       ORDERS.B_Contact2, ' 
             + '       ORDERS.B_Phone1, ' 
             + '       ORDERS.B_Phone2, ' 
             + '       ORDERS.OrderKey, ' 
             + '       ORDERS.Adddate, ' 
             + '       ORDERS.DeliveryDate, ' 
             + '       ORDERS.Salesman, ' 
             + '       ORDERS.BuyerPO,   ' 
             + '       ORDERDETAIL.SKU, ' 
             + '	     SKU.DESCR, ' 
             + '       ORDERDETAIL.UOM,   ' 
             + '	     LOTATTRIBUTE.Lottable02, ' 
             + '	     LOTATTRIBUTE.Lottable04, ' 
             + '       STORER.Notes1, ' 
             + '       STORER.Notes2, ' 
             + '       SUM(PICKDETAIL.Qty) AS Qty,  ' 
             + '       SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),1,87) AS NOTES1_1,   ' 
             + '       SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),88,87) AS NOTES1_2,   ' 
             + '       SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),175,76) AS NOTES1_3, ' 
             + '       ISNULL(CODELKUP.Description,'''') AS CopyDesc, ' 
             + '       CASE WHEN ISNULL(CODELKUP.Notes,'''') = '''' AND ORDERS.Type <> ''AXTO''  THEN ''DELIVERY NOTE''  ' 
             + '            WHEN ORDERS.Type = ''AXTO'' AND ORDERS.Storerkey <> ''61280'' THEN ''DELIVERY NOTE''  ' 
             + '            WHEN ORDERS.Type = ''AXTO'' AND ORDERS.Storerkey = ''61280'' THEN ''WAREHOUSE STOCK TRANSFER''  ' 
             + '            ELSE CODELKUP.Notes END AS ReportTitle, ' 
             + '       ISNULL(CODELKUP.Code,'''') AS Copy  ' 
             + 'FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS (NOLOCK)      ' 
             + '     JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERDETAIL ORDERDETAIL (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )  ' 
             + '     JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PICKDETAIL PICKDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND     ' 
             + '                                           ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )   ' 
             + '     JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.SKU SKU (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) AND     ' 
             + '                                           (SKU.Sku = ORDERDETAIL.Sku )      ' 
             + '     JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE LOTATTRIBUTE (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot)      ' 
             + '     JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOL MBOL (NOLOCK) ON ( ORDERS.Mbolkey = MBOL.Mbolkey )     ' 
             + '     LEFT JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.CODELKUP CODELKUP (NOLOCK) ON (ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname=''REPORTCOPY''  ' 
             + '                                            AND CODELKUP.Long = ''r_dw_delivery_note13'')   ' 
             + '     JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.STORER STORER (NOLOCK) ON (STORER.STORERKEY = ORDERS.Storerkey) ' 
             + 'WHERE ( ORDERS.Status = ''9'' ) AND      ' 
             + '      ( MBOL.Mbolkey = @c_mbolkey )      ' 
             + 'GROUP BY ORDERS.Storerkey,  ' 
             + '       SUBSTRING(ORDERS.ExternOrderKey,5,26), ' 
             + '       ORDERS.Route, ' 
             + '       ORDERS.Facility,  ' 
             + '       ORDERS.ConsigneeKey,    ' 
             + '       ORDERS.C_Company,    ' 
             + '       ORDERS.C_Address1,    ' 
             + '       ORDERS.C_Address2,  ' 
             + '       ORDERS.C_Address3, ' 
             + '       ORDERS.C_Address4,    ' 
             + '	     ORDERS.C_City, ' 
             + '       ORDERS.C_Zip, ' 
             + '       ORDERS.C_Contact1, ' 
             + '       ORDERS.C_Contact2, ' 
             + '       ORDERS.C_Phone1, ' 
             + '       ORDERS.C_Phone2, ' 
             + '       ORDERS.BillToKey, ' 
             + '       ORDERS.B_Company,    ' 
             + '       ORDERS.B_Address1,    ' 
             + '       ORDERS.B_Address2,  ' 
             + '       ORDERS.B_Address3, ' 
             + '       ORDERS.B_Address4,   ' 
             + '	     ORDERS.B_City, ' 
             + '       ORDERS.B_Zip, ' 
             + '       ORDERS.B_Contact1, ' 
             + '       ORDERS.B_Contact2, ' 
             + '       ORDERS.B_Phone1, ' 
             + '       ORDERS.B_Phone2, ' 
             + '       ORDERS.OrderKey, ' 
             + '       ORDERS.Adddate, ' 
             + '       ORDERS.DeliveryDate,  ' 
             + '       ORDERS.Salesman, ' 
             + '       ORDERS.BuyerPO,  ' 
             + '       ORDERDETAIL.SKU, ' 
             + '	     SKU.DESCR, ' 
             + '       ORDERDETAIL.UOM,   ' 
             + '	     LOTATTRIBUTE.Lottable02, ' 
             + '	     LOTATTRIBUTE.Lottable04, ' 
             + '       STORER.Notes1, ' 
             + '       STORER.Notes2, ' 
             + '       SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),1,87),   ' 
             + '       SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),88,87),   ' 
             + '       SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),175,76), ' 
             + '       ISNULL(CODELKUP.Description,''''), ' 
             + '       CASE WHEN ISNULL(CODELKUP.Notes,'''') = '''' AND ORDERS.Type <> ''AXTO''  THEN ''DELIVERY NOTE''  ' 
             + '            WHEN ORDERS.Type = ''AXTO'' AND ORDERS.Storerkey <> ''61280'' THEN ''DELIVERY NOTE''  ' 
             + '            WHEN ORDERS.Type = ''AXTO'' AND ORDERS.Storerkey = ''61280'' THEN ''WAREHOUSE STOCK TRANSFER''  ' 
             + '            ELSE CODELKUP.Notes END, ' 
             + '       ISNULL(CODELKUP.Code,'''')  ' 
                    
   EXEC sp_executesql @sql,                                 
        N'@c_Mbolkey NVARCHAR(10)', 
        @c_mbolkey
END       

GO