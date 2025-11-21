SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Stored Procedure: isp_ReceiptTallySheet07                            */    
/* Creation Date: 26/11/2013                                            */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: SOS#295590                                                  */    
/*                                                                      */    
/* Called By: r_receipt_tallysheet07                                    */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */    
/* 2017-07-25   TLTING  1.1   review DynamicSQL                         */    
/* 2020-02-19   WLChooi 1.2   WMS-12059 - Use ReportCFG to show CTN/PLT */    
/*                            (WL01)                                    */    
/* 2020-02-20   WLChooi 1.3   ReportCFG allow filter by Facility (WL02) */    
/* 2020-09-22   WLChooi 1.4   WMS-15153 Show Extra Columns by ReportCFG */     
/*                            (WL03)                                    */    
/* 2021-01-19   WLChooi 1.4   WMS-16047 Show SKUGroup by ReportCFG(WL04)*/   
/* 2023-01-31   Nicholas1.5   WMS-21685 add in actual casecnt (NL01)    */   
/************************************************************************/    
    
CREATE   PROC [dbo].[isp_ReceiptTallySheet07] (    
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
         RECEIPTDETAIL.QtyExpected ,     
         RECEIPTDETAIL.BeforeReceivedQty,       
         (user_name()) username,    
         PACK.Packuom1,    
         CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND ISNULL(PACK.Casecnt,0) > 0 THEN (PACK.PALLET / PACK.Casecnt) ELSE PACK.Casecnt END AS Casecnt,  --WL01    
         PACK.Packuom4,    
         PACK.Pallet,    
         PACK.Packuom2,    
         PACK.InnerPack,    
         RECEIPT.Signatory,    
         SKU.IVAS,     
         ReceiptDetail.ToLoc ToLoc,    
         RECEIPT.Warehousereference, /*SOS117892*/     
         ReceiptDetail.Toid,    /*SOS117892*/     
         ISNULL(CL.SHORT,'N') AS 'SHOWCTN/PLT',   --WL01    
         ISNULL(RECEIPT.ExternReceiptKey,''),     --WL03    
         ISNULL(RECEIPT.ReceiptGroup,''),         --WL03    
         ISNULL(RECEIPT.POKey,''),                --WL03    
         ISNULL(RECEIPT.RecType,''),              --WL03    
         ISNULL(CL1.Short,'N') AS ShowExtraCol,   --WL03    
         ISNULL(CL2.Short,'N') AS ShowSKUGroup,   --WL04    
         (SELECT MAX(SKUGroup) FROM SKU (NOLOCK) WHERE StorerKey = RECEIPT.StorerKey AND SKU = RECEIPTDETAIL.SKU) AS SKUGroup,      --WL04    
         PACK.Casecnt as oricasecnt --NL01  
    FROM RECEIPT WITH (NOLOCK)     
    JOIN RECEIPTDETAIL WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )     
    JOIN #TEMP_SKU2 SKU WITH (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey     
                AND SKU.Sku = RECEIPTDETAIL.Sku )    
    JOIN STORER WITH (NOLOCK) ON ( RECEIPT.Storerkey = STORER.Storerkey )     
    JOIN PACK WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey )     
    OUTER APPLY (SELECT TOP 1 CL.SHORT                                       --WL02      
                 FROM CODELKUP CL WITH (NOLOCK)                              --WL02    
                 WHERE (CL.LISTNAME = 'REPORTCFG'                            --WL02    
                 AND CL.STORERKEY = RECEIPT.STORERKEY                        --WL02    
                 AND CL.CODE = 'SHOWCTN/PLT'                                 --WL02    
                 AND (CL.Code2 = RECEIPT.Facility OR CL.Code2 = '') )        --WL02    
                 ORDER BY CASE WHEN CL.Code2 = '' THEN 2 ELSE 1 END ) AS CL  --WL02    
    /*LEFT JOIN CODELKUP CL WITH (NOLOCK) ON ( CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'SHOWCTN/PLT'                     --WL01    
                                         AND CL.StorerKey = RECEIPT.Storerkey AND CL.LONG = 'r_receipt_tallysheet07')*/  --WL01    
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON ( CL1.Listname = 'REPORTCFG' AND CL1.Code = 'ShowExtraCol'                    --WL03    
                                         AND CL1.StorerKey = RECEIPT.Storerkey AND CL1.Long = 'r_receipt_tallysheet07')  --WL03    
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON ( CL2.Listname = 'REPORTCFG' AND CL2.Code = 'ShowSKUGroup'     --WL04    
                                         AND CL2.StorerKey = RECEIPT.Storerkey AND CL2.Long = 'r_receipt_tallysheet07')  --WL04    
   WHERE ( RECEIPT.ReceiptKey >= @c_receiptkeystart )     
   AND ( RECEIPT.ReceiptKey <= @c_receiptkeyend )     
   AND ( RECEIPT.Storerkey >= @c_storerkeystart )     
   AND ( RECEIPT.Storerkey <= @c_storerkeyend )     
       
 END 

GO