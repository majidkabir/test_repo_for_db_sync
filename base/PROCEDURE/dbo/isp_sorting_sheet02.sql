SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Sorting_Sheet02                 					*/
/* Creation Date: 01/04/2009                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: ECCO Sorting sheet                                          */
/*                                                                      */
/* Called By: r_dw_Sorting_Sheet02                                      */
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
CREATE PROCEDURE [dbo].[isp_Sorting_Sheet02] 
	@c_receiptkey NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @c_arcdbname NVARCHAR(30),
          @sql nvarchar(4000)
 
SELECT RECEIPT.Receiptkey, 
		 RECEIPT.WarehouseReference,
		 ORDERDETAIL.Userdefine01,
		 ORDERDETAIL.Userdefine02,
		 ORDERS.ExternOrderkey,
		 ORDERS.Deliverydate,
	 	 ORDERS.C_Company,
		 SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) AS qty
INTO #TEMP_SORT
FROM RECEIPT (NOLOCK) 
INNER JOIN ORDERS (NOLOCK) ON (ORDERS.ExternPOkey = RECEIPT.ExternReceiptkey AND ORDERS.Storerkey = Receipt.Storerkey)
INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) 
WHERE RECEIPT.Receiptkey = @c_receiptkey 
AND ORDERS.Type = 'XDOCK' 
AND ISNULL(RTRIM(RECEIPT.ExternReceiptKey),'') <> ''        
GROUP BY RECEIPT.Receiptkey, 
		 RECEIPT.WarehouseReference,
		 ORDERDETAIL.Userdefine01,
		 ORDERDETAIL.Userdefine02,
		 ORDERS.ExternOrderkey,
		 ORDERS.Deliverydate,
	 	 ORDERS.C_Company 
HAVING SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) > 0

  IF @@ROWCOUNT = 0
  BEGIN
 	   SELECT @c_arcdbname = NSQLValue FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'
      
 --     IF (SELECT COUNT(*) FROM sys.master_files s_mf
--          WHERE s_mf.state = 0 and has_dbaccess(db_name(s_mf.database_id)) = 1
--          AND db_name(s_mf.database_id) = @c_arcdbname) > 0
      IF 1=1
      BEGIN
        SET @sql = 'INSERT INTO #TEMP_SORT '
                 + '     SELECT R.Receiptkey,  ' 
                 + '		 R.WarehouseReference, '
                 + '		 OD.Userdefine01, '
                 + '		 OD.Userdefine02, '
                 + '		 O.ExternOrderkey, '
                 + '		 O.Deliverydate, '
                 + '	 	 O.C_Company, '
                 + '		 SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS QTY '
                 + 'FROM '+RTRIM(@c_arcdbname)+'..RECEIPT R (NOLOCK)  '
                 + 'INNER JOIN ORDERS O (NOLOCK) ON (O.ExternPOkey = R.ExternReceiptkey AND O.Storerkey = R.Storerkey) '
                 + 'INNER JOIN ORDERDETAIL OD (NOLOCK) ON (O.Orderkey = OD.Orderkey)  '
                 + 'WHERE R.Receiptkey = N'''+ @c_receiptkey  + ''' '
                 + 'AND O.Type = ''XDOCK''  '
                 + 'AND ISNULL(RTRIM(R.ExternReceiptKey),'''') <> '''' '
                 + 'GROUP BY R.Receiptkey,  '
                 + '		 R.WarehouseReference, '
                 + '		 OD.Userdefine01, '
                 + '		 OD.Userdefine02, '
                 + '		 O.ExternOrderkey, '
                 + '		 O.Deliverydate, '
                 + '	 	 O.C_Company  ' 
                 + 'HAVING SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0'
        EXEC(@sql)
        
        IF @@ROWCOUNT = 0 --Get order from archive
        BEGIN
		        SET @sql = 'INSERT INTO #TEMP_SORT '
		                 + '     SELECT R.Receiptkey,  ' 
		                 + '		 R.WarehouseReference, '
		                 + '		 OD.Userdefine01, '
		                 + '		 OD.Userdefine02, '
		                 + '		 O.ExternOrderkey, '
		                 + '		 O.Deliverydate, '
		                 + '	 	 O.C_Company, '
		                 + '		 SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS QTY '
		                 + 'FROM '+RTRIM(@c_arcdbname)+'..RECEIPT R (NOLOCK)  '
		                 + 'INNER JOIN '+RTRIM(@c_arcdbname)+'..ORDERS O (NOLOCK) ON (O.ExternPOkey = R.ExternReceiptkey AND O.Storerkey = R.Storerkey) '
		                 + 'INNER JOIN '+RTRIM(@c_arcdbname)+'..ORDERDETAIL OD (NOLOCK) ON (O.Orderkey = OD.Orderkey)  '
		                 + 'WHERE R.Receiptkey = N'''+ @c_receiptkey  + ''' '
		                 + 'AND O.Type = ''XDOCK''  '
		                 + 'AND ISNULL(RTRIM(R.ExternReceiptKey),'''') <> '''' '
		                 + 'GROUP BY R.Receiptkey,  '
		                 + '		 R.WarehouseReference, '
		                 + '		 OD.Userdefine01, '
		                 + '		 OD.Userdefine02, '
		                 + '		 O.ExternOrderkey, '
		                 + '		 O.Deliverydate, '
		                 + '	 	 O.C_Company  ' 
		                 + 'HAVING SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) > 0'
		        EXEC(@sql)
      	END        
      END
   END
   
   SELECT * FROM #TEMP_SORT
END

GO