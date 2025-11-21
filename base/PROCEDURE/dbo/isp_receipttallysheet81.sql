SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet81                            */
/* Creation Date: 2021-07-21                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17523 - IDSMED Tally Sheet                              */
/*          Copy and modify from isp_ReceiptTallySheet07                */
/*                                                                      */
/* Called By: r_receipt_tallysheet81                                    */
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

CREATE PROC [dbo].[isp_ReceiptTallySheet81] (
   @c_ReceiptkeyStart NVARCHAR(10),
   @c_ReceiptkeyEnd   NVARCHAR(10),
   @c_StorerkeyStart  NVARCHAR(15),
   @c_StorerkeyEnd    NVARCHAR(15)
   )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_storerkey    NVARCHAR(15),
            @c_udf01        NVARCHAR(60),
            @c_udf02        NVARCHAR(60),
            @c_udf03        NVARCHAR(60),
            @c_TableName    NVARCHAR(100),
            @c_ColName      NVARCHAR(100),
            @c_ColType      NVARCHAR(100),
            @c_ISCombineSKU NVARCHAR(1),
            @cSQL           NVARCHAR(Max),
            @c_FromWhere    NVARCHAR(2000),              
            @c_InsertSelect NVARCHAR(2000)                        
                          
   CREATE TABLE #TEMP_SKU (Storerkey NVARCHAR(15) NULL, SKU NVARCHAR(20) NULL, DESCR NVARCHAR(60) NULL, 
                           Packkey NVARCHAR(10) NULL, SUSR3 NVARCHAR(18) NULL, IVAS NVARCHAR(30) NULL, COMBINESKU NVARCHAR(100) NULL)
    
    
   DECLARE CUR_RECSTORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RECEIPT.Storerkey
      FROM RECEIPT (NOLOCK)
      WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptkeyStart ) 
       AND ( RECEIPT.ReceiptKey <= @c_ReceiptkeyEnd ) 
       AND ( RECEIPT.Storerkey >= @c_StorerkeyStart ) 
       AND ( RECEIPT.Storerkey <= @c_StorerkeyEnd ) 
   
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
                          + ' WHERE R.Receiptkey >= RTRIM(@c_ReceiptkeyStart) '
                          + ' AND R.Receiptkey <= RTRIM(@c_ReceiptkeyEnd) '
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
              N'@c_storerkey nvarchar(15), @c_ReceiptkeyStart nvarchar(10), @c_ReceiptkeyEnd nvarchar(10) ', 
              @c_storerkey, @c_ReceiptkeyStart, @c_ReceiptkeyEnd
          
      END
       
      IF @c_ISCombineSKU = 'N'
      BEGIN
         INSERT INTO #TEMP_SKU
         SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.Susr3, SKU.IVAS, SKU.Sku
         FROM SKU (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku
         JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey
         WHERE R.Receiptkey >= @c_ReceiptkeyStart
         AND R.Receiptkey <= @c_ReceiptkeyEnd
         AND R.Storerkey = @c_storerkey
      END     
   
      FETCH NEXT FROM CUR_RECSTORER INTO @c_Storerkey
   END
   CLOSE CUR_RECSTORER
   DEALLOCATE CUR_RECSTORER 
    
   SELECT DISTINCT Storerkey, SKU, DESCR, Packkey, SUSR3, IVAS, COMBINESKU 
   INTO #TEMP_SKU2
   FROM #TEMP_SKU
         
   SELECT RH.Facility
        , RH.StorerKey
        , ST.Company
        , RH.POKey
        , RH.CarrierKey
        , RH.CarrierReference
        , RH.EditWho
        , RH.Notes
        , RH.ReceiptKey
        , RH.ExternReceiptKey
        , RH.UserDefine01
        , RH.ReceiptDate
        , RH.ContainerKey
        , RH.ContainerType
        , CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END
        , SKU.DESCR
        , RD.ExternLineNo
        , RD.UOM
        , PACK.CaseCnt
        , SUM(RD.QtyExpected) AS QtyExpected
        , SUM(RD.QtyReceived) AS QtyReceived
        , RD.Lottable04
        , RD.Lottable08
        , RD.Lottable10
        , RD.Lottable12
        , RD.POKey
        , RD.ToLoc
        , SKU.IVAS
   FROM RECEIPT RH WITH (NOLOCK) 
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON ( RH.ReceiptKey = RD.ReceiptKey ) 
   JOIN #TEMP_SKU2 SKU WITH (NOLOCK) ON ( SKU.StorerKey = RD.StorerKey 
        					                 AND SKU.Sku = RD.Sku )
   JOIN STORER ST WITH (NOLOCK) ON ( RH.Storerkey = ST.Storerkey ) 
   JOIN PACK WITH (NOLOCK) ON ( SKU.Packkey = PACK.Packkey ) 
   WHERE ( RH.ReceiptKey >= @c_ReceiptkeyStart ) 
     AND ( RH.ReceiptKey <= @c_ReceiptkeyEnd ) 
     AND ( RH.Storerkey >= @c_StorerkeyStart ) 
     AND ( RH.Storerkey <= @c_StorerkeyEnd ) 
   GROUP BY RH.Facility
        , RH.StorerKey
        , ST.Company
        , RH.POKey
        , RH.CarrierKey
        , RH.CarrierReference
        , RH.EditWho
        , RH.Notes
        , RH.ReceiptKey
        , RH.ExternReceiptKey
        , RH.UserDefine01
        , RH.ReceiptDate
        , RH.ContainerKey
        , RH.ContainerType
        , CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END
        , SKU.DESCR
        , RD.ExternLineNo
        , RD.UOM
        , PACK.CaseCnt
        , RD.Lottable04
        , RD.Lottable08
        , RD.Lottable10
        , RD.Lottable12
        , RD.POKey
        , RD.ToLoc
        , SKU.IVAS
   
END        

GO