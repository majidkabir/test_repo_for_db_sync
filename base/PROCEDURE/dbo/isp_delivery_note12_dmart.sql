SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Delivery_Note12_dmart    	      		         */
/* Creation Date: 11/04/2014                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#307827                                                  */
/*                                                                      */
/* Called By: r_dw_delivery_note12_dmart                                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 06-Apr-2015  NJOW01  1.0   337773 Fonterra Delivery Notes calculate  */
/*                            delivery date                             */
/* 07-Aug-2015  SPChin  1.1   SOS349518 - Bug Fixed                     */
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note12_dmart] (@c_mbolkey NVARCHAR(10))
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
             + 'ORDERS.ExternOrderKey, '
             + 'ORDERS.ConsigneeKey, '
             + 'ORDERS.C_Company, '
             + 'ORDERS.C_Address1, '
             + 'ORDERS.C_Address2, '
             + 'ORDERS.C_Address3, '
             + 'ORDERS.C_City, '
             + 'ORDERS.C_Phone1, '
             + 'ORDERS.OrderKey, '
             + 'ORDERS.Orderdate, '
             + 'MBOL.Vessel, '
             + 'MBOL.Editdate, '
             + 'ORDERDETAIL.SKU, '
             + 'SKU.DESCR, '
             + 'LOTATTRIBUTE.Lottable02, '
             + 'LOTATTRIBUTE.Lottable04, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM = ''CT'' THEN FLOOR(PICKDETAIL.Qty / '
             + '     CASE ORDERDETAIL.UOM '
             + '       WHEN PACK.PACKUOM1 THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 THEN 1 '
             + '       WHEN PACK.PACKUOM4 THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 '
             + '     END) ELSE 0 END) AS CT, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM = ''BG'' THEN FLOOR(PICKDETAIL.Qty / '
             + '     CASE ORDERDETAIL.UOM '
             + '       WHEN PACK.PACKUOM1 THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 THEN 1 '
             + '       WHEN PACK.PACKUOM4 THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 '
             + '     END) ELSE 0 END) AS BG, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM = ''RL'' THEN FLOOR(PICKDETAIL.Qty / '
             + '     CASE ORDERDETAIL.UOM '
             + '       WHEN PACK.PACKUOM1 THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 THEN 1 '
             + '       WHEN PACK.PACKUOM4 THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 '
             + '     END) ELSE 0 END) AS RL, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM = ''EA'' THEN FLOOR(PICKDETAIL.Qty / '
             + '     CASE ORDERDETAIL.UOM '
             + '       WHEN PACK.PACKUOM1 THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 THEN 1 '
             + '       WHEN PACK.PACKUOM4 THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 '
             + '     END) ELSE 0 END) AS EA, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM IN (''GM'', ''KG'') THEN (PICKDETAIL.Qty / '
             + '     CASE '
             + '       WHEN PACK.PACKUOM1 = ''KG'' THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 = ''KG'' THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 = ''KG'' THEN 1 '
             + '       WHEN PACK.PACKUOM4 = ''KG'' THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 = ''KG'' THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 = ''KG'' THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 = ''KG'' THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 = ''KG'' THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 = ''KG'' THEN PACK.OtherUnit2 '
             + '     END) ELSE 0 END) AS KG, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM = ''DR'' THEN FLOOR(PICKDETAIL.Qty / '
             + '     CASE ORDERDETAIL.UOM '
             + '       WHEN PACK.PACKUOM1 THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 THEN 1 '
             + '       WHEN PACK.PACKUOM4 THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 '
             + '     END) ELSE 0 END) AS JC, '
             + 'SUM(CASE WHEN ORDERDETAIL.UOM NOT IN (''GM'', ''KG'') THEN PICKDETAIL.Qty % '
             + '     CAST(CASE ORDERDETAIL.UOM '
             + '       WHEN PACK.PACKUOM1 THEN PACK.CaseCnt '
             + '       WHEN PACK.PACKUOM2 THEN PACK.InnerPack '
             + '       WHEN PACK.PACKUOM3 THEN 1 '
             + '       WHEN PACK.PACKUOM4 THEN PACK.Pallet '
             + '       WHEN PACK.PACKUOM5 THEN PACK.Cube '
             + '       WHEN PACK.PACKUOM6 THEN PACK.GrossWgt '
             + '       WHEN PACK.PACKUOM7 THEN PACK.NetWgt '
             + '       WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1 '
             + '       WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2 '
             + '     END AS INT) ELSE 0 END) AS LOOSE, '
             + 'STORER.Company, '
             + 'STORER.Address1, '
             + 'STORER.Address2, '
             + 'STORER.Address3, '
             + 'STORER.City, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),1,87) AS NOTES1_1, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),88,87) AS NOTES1_2, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),175,76) AS NOTES1_3, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes2),1,97) AS NOTES2_1, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes2),98,97) AS NOTES2_2, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes2),195,56) AS NOTES2_3, '
             + 'dbo.fnc_GetNextWorkDay(ORDERS.DeliveryDate + CASE WHEN ISNULL(ORDERS.PODArrive,'''') = '''' AND MBOL.Transmethod IN(''L'',''S4'') AND ISNUMERIC(CONS.Susr1)=1 THEN '
             + '       CAST(CONS.Susr1 AS INT) '
             + '     WHEN ISNULL(ORDERS.PODArrive,'''') = '''' AND MBOL.Transmethod IN(''S3'') AND ISNUMERIC(CONS.Susr2) = 1 THEN '
             + '       CAST(CONS.Susr2 AS INT) '
             + '     ELSE ''0'' '
             + 'END,''N'',''Y'') AS DeliveryDate '
             + 'FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS (NOLOCK) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERDETAIL ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PICKDETAIL PICKDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey) AND (ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.STORER STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.Storerkey) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.SKU SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.Storerkey) AND (SKU.Sku = ORDERDETAIL.Sku) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACK PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot) '
             + 'JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOL MBOL (NOLOCK) ON (ORDERS.Mbolkey = MBOL.Mbolkey) '
             + 'LEFT JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.STORER CONS (NOLOCK) ON ORDERS.Consigneekey = CONS.Storerkey '	--SOS349518
             + 'WHERE (ORDERS.Status = ''9'') AND '
             + '(MBOL.Mbolkey = @c_mbolkey) '
             + 'GROUP BY ORDERS.Storerkey, '
             + 'ORDERS.ExternOrderKey, '
             + 'ORDERS.ConsigneeKey, '
             + 'ORDERS.C_Company, '
             + 'ORDERS.C_Address1, '
             + 'ORDERS.C_Address2, '
             + 'ORDERS.C_Address3, '
             + 'ORDERS.C_City, '
             + 'ORDERS.C_Phone1, '
             + 'ORDERS.OrderKey, '
             + 'ORDERS.Orderdate, '
             + 'MBOL.Vessel, '
             + 'MBOL.Editdate, '
             + 'ORDERDETAIL.SKU, '
             + 'SKU.DESCR, '
             + 'LOTATTRIBUTE.Lottable02, '
             + 'LOTATTRIBUTE.Lottable04, '
             + 'STORER.Company, '
             + 'STORER.Address1, '
             + 'STORER.Address2, '
             + 'STORER.Address3, '
             + 'STORER.City, '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),1,87), '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),88,87), '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes),175,76), '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes2),1,97), '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes2),98,97), '
             + 'SUBSTRING(CONVERT(NVARCHAR(250),ORDERS.Notes2),195,56), '
             + 'dbo.fnc_GetNextWorkDay(ORDERS.DeliveryDate + CASE WHEN ISNULL(ORDERS.PODArrive,'''') = '''' AND MBOL.Transmethod IN(''L'',''S4'') AND ISNUMERIC(CONS.Susr1)=1 THEN '
             + '       CAST(CONS.Susr1 AS INT) '
             + '     WHEN ISNULL(ORDERS.PODArrive,'''') = '''' AND MBOL.Transmethod IN(''S3'') AND ISNUMERIC(CONS.Susr2) = 1 THEN '
             + '       CAST(CONS.Susr2 AS INT) '
             + '     ELSE ''0'' '
             + 'END,''N'',''Y'') '

   EXEC sp_executesql @sql,
        N'@c_Mbolkey NVARCHAR(10)',
        @c_mbolkey
END

GO