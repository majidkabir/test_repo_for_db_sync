SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet41    					         */
/* Creation Date: 28/10/2014                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#323879                                                  */
/*                                                                      */
/* Called By: r_receipt_tallysheet41                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 28/10/2014   CSCHONG 1.0   Change Request of Adidas Tally Sheet      */
/* 08/12/2022   MINGLE  1.1   WMS-21245 add new parm username(ML01)     */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet41] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_storerkeystart NVARCHAR(15),
   @c_storerkeyend NVARCHAR(15),
	@c_username NVARCHAR(30)	--ML01 
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
            @cSQL NVARCHAR(MAX),
            @c_FromWhere NVARCHAR(2000),              
            @c_InsertSelect NVARCHAR(2000)
    
                          
    CREATE TABLE #TEMP_SKU (Storerkey NVARCHAR(15) NULL, SKU NVARCHAR(20) NULL, DESCR NVARCHAR(60) NULL, 
                            Packkey NVARCHAR(10) NULL, SUSR3 NVARCHAR(18) NULL, IVAS NVARCHAR(30) NULL, COMBINESKU NVARCHAR(100) NULL,
							SKUGROUP NVARCHAR(10) NULL, BUSR6 NVARCHAR(30) NULL) 
    
    
    DECLARE CUR_RECSTORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT RECEIPT.Storerkey
       FROM RECEIPT (NOLOCK)
       WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) 
	     AND ( RECEIPT.ReceiptKey <= @c_receiptkeyend ) 
	     AND ( RECEIPT.Storerkey >= @c_storerkeystart ) 
	     AND ( RECEIPT.Storerkey <= @c_storerkeyend ) 
   
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
          SET @c_InsertSelect = ' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Susr3, SKU.IVAS ,SKU.SKUGROUP , SKU.BUSR6'  
          SET @c_FromWhere = ' FROM SKU (NOLOCK) '
                           + ' JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku '
                           + ' JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey '
                           + ' WHERE R.Receiptkey >= ''' + RTRIM(@c_receiptkeystart) + ''' '
                           + ' AND R.Receiptkey <= ''' + RTRIM(@c_receiptkeyend) + ''' '
                           + ' AND R.Storerkey = ''' + RTRIM(@c_storerkey) + ''' '
       
          --UDF01
          SET @c_ColName = @c_udf01
          SET @c_TableName = 'SKU'
          IF CHARINDEX('.', @c_udf01) > 0
          BEGIN
             SET @c_TableName = LEFT(@c_udf01, CHARINDEX('.', @c_udf01) - 1)
             SET @c_ColName   = SUBSTRING(@c_udf01, CHARINDEX('.', @c_udf01) + 1, LEN(@c_udf01) - CHARINDEX('.', @c_udf01))
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
          IF CHARINDEX('.', @c_udf02) > 0
          BEGIN
             SET @c_TableName = LEFT(@c_udf02, CHARINDEX('.', @c_udf02) - 1)
             SET @c_ColName   = SUBSTRING(@c_udf02, CHARINDEX('.', @c_udf02) + 1, LEN(@c_udf02) - CHARINDEX('.', @c_udf02))
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
          IF CHARINDEX('.', @c_udf03) > 0
          BEGIN
             SET @c_TableName = LEFT(@c_udf03, CHARINDEX('.', @c_udf03) - 1)
             SET @c_ColName   = SUBSTRING(@c_udf03, CHARINDEX('.', @c_udf03) + 1, LEN(@c_udf03) - CHARINDEX('.', @c_udf03))
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
          EXEC sp_executesql @cSQL   	      
       END
       
       IF @c_ISCombineSKU = 'N'
       BEGIN
          INSERT INTO #TEMP_SKU
          SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Susr3, SKU.IVAS, SKU.Sku, SKU.SKUGROUP , SKU.BUSR6  
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

	 
    
    SELECT DISTINCT Storerkey, SKU, DESCR, Packkey, SUSR3, IVAS, COMBINESKU, SKUGROUP , BUSR6
    INTO #TEMP_SKU2
    FROM #TEMP_SKU

	  
                
   SELECT RECEIPT.ReceiptKey,   
         RECEIPTDETAIL.POKey,   
         CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END,    
         SKU.DESCR,   
         RECEIPTDETAIL.UOM,   
         RECEIPTDETAIL.Lottable01,   
         RECEIPTDETAIL.Lottable02,   
         RECEIPTDETAIL.Lottable03,   
         RECEIPTDETAIL.Lottable04,   
         RECEIPTDETAIL.Lottable05, 
         STORER.Company,   
         RECEIPT.ReceiptDate,   
         RECEIPTDETAIL.PackKey,   
         SKU.SUSR3,   
         RECEIPTDETAIL.QtyExpected , 
			RECEIPTDETAIL.BeforeReceivedQty,			
			--(user_name()) username,
			CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND ISNULL(@c_username,'') <> '' THEN @c_username ELSE (SUSER_SNAME()) END AS Username,	--ML01
			PACK.Packuom1,
			PACK.Casecnt,
			PACK.Packuom4,
			PACK.Pallet,
			PACK.Packuom2,
			PACK.InnerPack,
         RECEIPT.Signatory,
			SKU.IVAS, 
			ReceiptDetail.ToLoc ToLoc,
			RECEIPT.Warehousereference,  
			ReceiptDetail.Toid,			 
		   SKU.SKUGROUP,
		   SKU.BUSR6,
			ISNULL(CL.SHORT,'') AS ShowMYUsername	--ML01

    FROM RECEIPT WITH (NOLOCK) 
	 JOIN RECEIPTDETAIL WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey ) 
    JOIN #TEMP_SKU2 SKU WITH (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey 
         					  AND SKU.Sku = RECEIPTDETAIL.Sku )
    JOIN STORER WITH (NOLOCK) ON ( RECEIPT.Storerkey = STORER.Storerkey ) 
	 JOIN PACK WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey ) 
	 LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'REPORTCFG' AND CL.Long = 'r_receipt_tallysheet41'
                                      AND CL.Code = 'ShowMYUsername' AND CL.Storerkey = RECEIPT.Storerkey	--ML01 
   WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) 
	  AND ( RECEIPT.ReceiptKey <= @c_receiptkeyend ) 
	  AND ( RECEIPT.Storerkey >= @c_storerkeystart ) 
	  AND ( RECEIPT.Storerkey <= @c_storerkeyend ) 
   
 END        


GO