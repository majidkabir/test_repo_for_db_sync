SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet76                            */
/* Creation Date: 2021-01-20                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16092 - MYS-MANDOM-Display both EA & CTN qty in         */
/*          Receiving Tally Sheet                                       */
/*          Copy from isp_ReceiptTallySheet07                           */
/*                                                                      */
/* Called By: r_receipt_tallysheet76                                    */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet76] (
   @c_receiptkeystart NVARCHAR(10),
   @c_receiptkeyend NVARCHAR(10),
   @c_storerkeystart NVARCHAR(15),
   @c_storerkeyend NVARCHAR(15)
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
                           Packkey NVARCHAR(10) NULL, SUSR3 NVARCHAR(18) NULL, IVAS NVARCHAR(30) NULL, COMBINESKU NVARCHAR(100) NULL)
    
    
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
         SET @c_InsertSelect = ' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Susr3, SKU.IVAS '
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
         
         EXEC sp_executesql @cSQL, 
              N'@c_storerkey nvarchar(15), @c_receiptkeystart nvarchar(10), @c_receiptkeyend nvarchar(10) ', 
              @c_storerkey, @c_receiptkeystart, @c_receiptkeyend
          
      END
       
      IF @c_ISCombineSKU = 'N'
      BEGIN
         INSERT INTO #TEMP_SKU
         SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Susr3, SKU.IVAS, SKU.Sku
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
    
   SELECT DISTINCT Storerkey, SKU, DESCR, Packkey, SUSR3, IVAS, COMBINESKU 
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
          RECEIPTDETAIL.QtyExpected,
          CASE WHEN ISNULL(PACK.Casecnt,0) > 0 THEN CEILING(RECEIPTDETAIL.QtyExpected / PACK.Casecnt) ELSE RECEIPTDETAIL.QtyExpected END AS QtyExpectedInCtn,
          RECEIPTDETAIL.QtyReceived,
          CASE WHEN ISNULL(PACK.Casecnt,0) > 0 THEN CEILING(RECEIPTDETAIL.QtyReceived / PACK.Casecnt) ELSE RECEIPTDETAIL.QtyReceived END AS QtyReceivedInCtn,       
          (user_name()) username,
          PACK.Packuom1,
          PACK.Casecnt AS Casecnt, 
          PACK.Packuom4,
          PACK.Pallet,
          PACK.Packuom2,
          PACK.InnerPack,
          RECEIPT.Signatory,
          SKU.IVAS, 
          ReceiptDetail.ToLoc ToLoc,
          RECEIPT.Warehousereference,
          ReceiptDetail.Toid,         
          ISNULL(RECEIPT.ExternReceiptKey,''),   
          ISNULL(RECEIPT.ReceiptGroup,''),       
          ISNULL(RECEIPT.POKey,''),              
          ISNULL(RECEIPT.RecType,''),            
          ISNULL(CL1.Short,'N') AS ShowExtraCol,
          CASE WHEN  ISNULL(PACK.Casecnt,0) > 0 THEN CEILING(PACK.PALLET / PACK.Casecnt) ELSE 0 END AS CtnPerPlt  
   FROM RECEIPT WITH (NOLOCK) 
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey ) 
   JOIN #TEMP_SKU2 SKU WITH (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey 
                          AND SKU.Sku = RECEIPTDETAIL.Sku )
   JOIN STORER WITH (NOLOCK) ON ( RECEIPT.Storerkey = STORER.Storerkey ) 
   JOIN PACK WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey ) 
   /*LEFT JOIN CODELKUP CL WITH (NOLOCK) ON ( CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'SHOWCTN/PLT'                    
                                         AND CL.StorerKey = RECEIPT.Storerkey AND CL.LONG = 'r_receipt_tallysheet76')*/ 
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON ( CL1.Listname = 'REPORTCFG' AND CL1.Code = 'ShowExtraCol'                    
                                         AND CL1.StorerKey = RECEIPT.Storerkey AND CL1.Long = 'r_receipt_tallysheet76') 
   WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart ) 
     AND ( RECEIPT.ReceiptKey <= @c_receiptkeyend ) 
     AND ( RECEIPT.Storerkey >= @c_storerkeystart ) 
     AND ( RECEIPT.Storerkey <= @c_storerkeyend ) 

   IF OBJECT_ID('tempdb..#TEMP_SKU') IS NOT NULL
      DROP TABLE #TEMP_SKU
   IF OBJECT_ID('tempdb..#TEMP_SKU2') IS NOT NULL
      DROP TABLE #TEMP_SKU2

END        

GO