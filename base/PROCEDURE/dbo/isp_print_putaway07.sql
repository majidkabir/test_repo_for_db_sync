SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Print_Putaway07    						            */
/* Creation Date: 03/12/2013                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#296761                                                  */
/*                                                                      */
/* Called By: d_dw_print_putaway07                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 22-MAR-2017  JayLim   1.1  SQL2012 compatibility modification (Jay01)*/
/* 25-Jul-2017  TLTING   1.2  review DynamicSQL                         */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_Putaway07] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_userid NVARCHAR(18)
   )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @c_storerkey NVARCHAR(15),
            @c_udf01 NVARCHAR(60),
            @c_udf02 NVARCHAR(60),
            @c_udf03 NVARCHAR(60),
            @c_TableName NVARCHAR(100),
            @c_ColName NVARCHAR(100),
            @c_ColType NVARCHAR(100),
            @c_ISCombineSKU NCHAR(1),
            @cSQL NVARCHAR(Max),
            @c_FromWhere NVARCHAR(2000),              
            @c_InsertSelect NVARCHAR(2000)                        
                          
    CREATE TABLE #TEMP_SKU (Storerkey NVARCHAR(15) NULL, SKU NVARCHAR(20) NULL, DESCR NVARCHAR(60) NULL, 
                            Packkey NVARCHAR(10) NULL, BUSR6 NVARCHAR(18) NULL, IVAS NVARCHAR(30) NULL,                             
                            RetailSku NVARCHAR(20) NULL, ManufacturerSku NVARCHAR(20) NULL, ShelfLife INT NULL, 
                            COMBINESKU NVARCHAR(100) NULL)
        
    DECLARE CUR_RECSTORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT RECEIPT.Storerkey
       FROM RECEIPT (NOLOCK)
       WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) 
	     AND ( RECEIPT.ReceiptKey <= @c_receiptkeyend ) 
   
    OPEN CUR_RECSTORER

    FETCH NEXT FROM CUR_RECSTORER INTO @c_Storerkey
    
    WHILE @@FETCH_STATUS <> -1
    BEGIN
    	 SELECT @c_udf01 = '', @c_udf02 = '', @c_udf03 = '', @c_ISCombineSKU = 'N', @c_InsertSelect = '', @c_FromWhere = ''

       SELECT @c_udf01 = ISNULL(CL.UDF01,''),
              @c_udf02 = ISNULL(CL.UDF02,''),
              @c_udf03 = ISNULL(CL.UDF03,'')
       FROM CODELKUP CL (NOLOCK)
       WHERE Listname = 'COMBINESKU'
       AND Code = 'CONCATENATESKU'
       AND Storerkey = @c_Storerkey
       
       IF @@ROWCOUNT > 0
       BEGIN
       	  SET @c_ISCombineSKU = 'Y'
          SET @c_InsertSelect = ' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Busr6, SKU.IVAS, SKU.RetailSku, SKU.ManufacturerSku, SKU.ShelfLife '
          SET @c_FromWhere = ' FROM SKU (NOLOCK) '
                           + ' JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku '
                           + ' JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey '
                           + ' WHERE R.Receiptkey >= RTRIM(@c_receiptkeystart) '
                           + ' AND R.Receiptkey <= RTRIM(@c_receiptkeyend) '
                           + ' AND R.Storerkey = RTRIM(@c_storerkey) '
       
          --UDF01
          SET @c_ColName = @c_udf01
          SET @c_TableName = 'SKU'
          IF CharIndex('.', @c_udf01) > 0
          BEGIN
             SET @c_TableName = LEFT(@c_udf01, CharIndex('.', @c_udf01) - 1)
             SET @c_ColName   = SUBSTRING(@c_udf01, CharIndex('.', @c_udf01) + 1, LEN(@c_udf01) - CharIndex('.', @c_udf01))
          END
          
          SET @c_ColType = ''
          SELECT @c_ColType = DATA_TYPE 
          FROM   INFORMATION_SCHEMA.COLUMNS 
          WHERE  TABLE_NAME = @c_TableName
          AND    COLUMN_NAME = @c_ColName
          
          IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
   	         SELECT @c_InsertSelect = @c_InsertSelect + ',LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf01) + ',''''))) '       	                      	     
          ELSE
	           SELECT @c_InsertSelect = @c_InsertSelect + ',''' + LTRIM(RTRIM(@c_udf01)) + ''' '   	                      	     
       
          --UDF02
          SET @c_ColName = @c_udf02
          SET @c_TableName = 'SKU'
          IF CharIndex('.', @c_udf02) > 0
          BEGIN
             SET @c_TableName = LEFT(@c_udf02, CharIndex('.', @c_udf02) - 1)
             SET @c_ColName   = SUBSTRING(@c_udf02, CharIndex('.', @c_udf02) + 1, LEN(@c_udf02) - CharIndex('.', @c_udf02))
          END
          
          SET @c_ColType = ''
          SELECT @c_ColType = DATA_TYPE 
          FROM   INFORMATION_SCHEMA.COLUMNS 
          WHERE  TABLE_NAME = @c_TableName
          AND    COLUMN_NAME = @c_ColName
          
          IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
   	         SELECT @c_InsertSelect = @c_InsertSelect + ' + LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf02) + ',''''))) '       	                      	     
          ELSE
   	         SELECT @c_InsertSelect = @c_InsertSelect + ' + ''' + LTRIM(RTRIM(@c_udf02)) + ''' '   	                      	     
       
          --UDF03
          SET @c_ColName = @c_udf03
          SET @c_TableName = 'SKU'
          IF CharIndex('.', @c_udf03) > 0
          BEGIN
             SET @c_TableName = LEFT(@c_udf03, CharIndex('.', @c_udf03) - 1)
             SET @c_ColName   = SUBSTRING(@c_udf03, CharIndex('.', @c_udf03) + 1, LEN(@c_udf03) - CharIndex('.', @c_udf03))
          END
          
          SET @c_ColType = ''
          SELECT @c_ColType = DATA_TYPE 
          FROM   INFORMATION_SCHEMA.COLUMNS 
          WHERE  TABLE_NAME = @c_TableName
          AND    COLUMN_NAME = @c_ColName
          
          IF @c_ColType IN ('char', 'nvarchar', 'varchar') AND @c_TableName = 'SKU'
   	         SELECT @c_InsertSelect = @c_InsertSelect + ' + LTRIM(RTRIM(ISNULL('+ RTRIM(@c_udf03) + ',''''))) '       	                      	     
          ELSE
   	         SELECT @c_InsertSelect = @c_InsertSelect + ' + ''' + LTRIM(RTRIM(@c_udf03)) + ''' '   	                      	                   
       
          SET @cSQL = @c_InsertSelect + @c_FromWhere
          EXEC sp_executesql @cSQL, N'@c_storerkey nvarchar(15), @c_receiptkeystart nvarchar(10), @c_receiptkeyend nvarchar(10) ', 
               @c_storerkey, @c_receiptkeystart, @c_receiptkeyend
       END
       
       IF @c_ISCombineSKU = 'N'
       BEGIN
          INSERT INTO #TEMP_SKU
          SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Busr6, SKU.IVAS, SKU.RetailSku, SKU.ManufacturerSku, SKU.ShelfLife, SKU.Sku
          FROM SKU (NOLOCK)
          JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku
          JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey
          WHERE R.Receiptkey >= @c_receiptkeystart
          AND R.Receiptkey <= @c_receiptkeyend
          AND R.Storerkey = @c_storerkey
       END     
   
       FETCH NEXT FROM CUR_RECSTORER INTO @c_Storerkey
    END
    CLOSE CUR_RECSTORER
    DEALLOCATE CUR_RECSTORER 
    
    SELECT DISTINCT Storerkey, SKU, DESCR, Packkey, Busr6, IVAS, RetailSku, ManufacturerSku, ShelfLife, COMBINESKU 
    INTO #TEMP_SKU2
    FROM #TEMP_SKU
                
    SELECT RECEIPT.ReceiptKey,   
			     RECEIPT.ExternReceiptKey, 
           RECEIPTDETAIL.ReceiptLineNumber,   
           SKU.CombineSku, 
			     RECEIPTDETAIL.Storerkey, 
           SKU.DESCR,   
           RECEIPTDETAIL.ToId,   
           RECEIPTDETAIL.ToLoc,   
           RECEIPTDETAIL.QtyReceived,   
           RECEIPTDETAIL.UOM,   
           RECEIPTDETAIL.Lottable02,
           RECEIPTDETAIL.Lottable04,   
           RECEIPTDETAIL.POKey,   
           RECEIPTDETAIL.PutawayLoc,
           RECEIPTDETAIL.BeforeReceivedQty,
			     RECEIPT.ReceiptDate,
			     STORER.Company, 
			     (suser_sname()) user_name, 
			     receipt.warehousereference,  
			     PACK.CaseCnt,
			     PACK.InnerPack,
			     PACK.Qty,
			     PACK.Pallet,
			     PACK.[Cube],
			     PACK.GrossWgt,
			     PACK.NetWgt,
			     PACK.OtherUnit1,
			     PACK.OtherUnit2,
			     PACK.PackUom1,
			     PACK.PackUom2,
			     PACK.PackUom3,
			     PACK.PackUom4,
			     PACK.PackUom5,
			     PACK.PackUom6,
			     PACK.PackUom7,
			     PACK.PackUom8,
			     PACK.PackUom9,
			     RECEIPT.Facility,
			     Facility.Descr,
           RECEIPT.Signatory,
			     SKU.RetailSku,			/* SOS28611 */
			     SKU.MANUFACTURERSKU,				/* SOS28611 */
			     SKU.BUSR6,
			     SKU.IVAS, 
			     Sku.ShelfLife,
			     CASE PACK.Casecnt WHEN 0 THEN 0
				      ELSE CAST(RECEIPTDETAIL.BeforeReceivedQty / PACK.Casecnt as int)       
		     	 END ReceivedCase,
			     CASE PACK.InnerPack when 0 THEN 0
			     ELSE 
			     		CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.BeforeReceivedQty as int) / cast(PACK.InnerPack as int)) 
			     								ELSE ((cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int) ) / cast(PACK.InnerPack as int)) END
			     END ReceivedPack,
			     CASE PACK.InnerPack when 0 THEN 
			     		CASE PACK.Casecnt WHEN 0 THEN cast(RECEIPTDETAIL.BeforeReceivedQty as int)
			     								ELSE (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int)) END
			     ELSE 
			     		CASE PACK.Casecnt WHEN 0 THEN (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.InnerPack as int)) 
			     								ELSE (cast(RECEIPTDETAIL.BeforeReceivedQty as int) % cast(PACK.Casecnt as int)) END /*SOS290189 - change innerpack to casecnt*/
			     END ReceivedEA 
    FROM RECEIPT (NOLOCK) 
    JOIN RECEIPTDETAIL (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )
    JOIN #TEMP_SKU2 SKU (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey ) AND  ( SKU.Sku = RECEIPTDETAIL.Sku ) 
	  JOIN STORER (NOLOCK) ON ( RECEIPT.Storerkey = STORER.Storerkey ) 
	  JOIN PACK (NOLOCK) ON ( pack.packkey = sku.packkey ) 
	  JOIN FACILITY (NOLOCK) ON ( RECEIPT.Facility = FACILITY.Facility ) 
    WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) AND  
          ( RECEIPT.ReceiptKey <= @c_receiptkeyend )
   
 END

GO