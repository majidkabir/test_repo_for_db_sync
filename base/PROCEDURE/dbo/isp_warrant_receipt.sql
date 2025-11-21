SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_warrant_receipt                                */  
/* Creation Date: 26/11/2013                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS#295591                                                  */  
/*                                                                      */  
/* Called By: r_dw_warrant_receipt                                      */  
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
/* 2019-06-04   CSCHONG 1.2   WMS-9318 - report config (CS01)           */  
/* 2019-08-01   CSCHONG 1.4   WMS-10012 - report config (CS02)          */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_warrant_receipt] (  
   @c_receiptkey NVARCHAR(10)  
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
            @c_ISCombineSKU NCHAR(1),  
            @cSQL           NVARCHAR(Max),  
            @c_FromWhere    NVARCHAR(2000),                
            @c_InsertSelect NVARCHAR(2000)                      
              
    SET @c_ISCombineSKU = 'N'  
                
    CREATE TABLE #TEMP_SKU (Storerkey NVARCHAR(15) NULL, SKU NVARCHAR(20) NULL, DESCR NVARCHAR(60) NULL,   
                            Packkey NVARCHAR(10) NULL, ALTSKU NVARCHAR(20) NULL, StdCube Float NULL, StdGrossWgt Float NULL  
                            , COMBINESKU NVARCHAR(100) NULL)  
      
    SELECT @c_Storerkey = RECEIPT.Storerkey  
    FROM RECEIPT (NOLOCK)  
    WHERE ( RECEIPT.ReceiptKey = @c_receiptkey )   
     
    SELECT @c_udf01 = ISNULL(CL.UDF01,''),  
           @c_udf02 = ISNULL(CL.UDF02,''),  
           @c_udf03 = ISNULL(CL.UDF03,'')  
    FROM CODELKUP CL (NOLOCK)      
    WHERE CL.Listname = 'COMBINESKU'  
    AND CL.Code = 'CONCATENATESKU'  
    AND CL.Storerkey = @c_Storerkey  
      
    IF @@ROWCOUNT > 0  
    BEGIN  
       SET @c_ISCombineSKU = 'Y'  
       SET @c_InsertSelect = ' INSERT INTO #TEMP_SKU SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.AltSku, SKU.StdCube, SKU.StdGrossWgt '  
       SET @c_FromWhere = ' FROM SKU (NOLOCK) '  
                        + ' JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku '  
                        + ' JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey '  
                        + ' WHERE R.Receiptkey = RTRIM(@c_Receiptkey) '  
  
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
       EXEC sp_executesql @cSQL, N'@c_Receiptkey nvarchar(10) ', @c_Receiptkey      
                          
    END  
      
    IF @c_ISCombineSKU = 'N'  
    BEGIN  
       INSERT INTO #TEMP_SKU  
       SELECT DISTINCT SKU.Storerkey, SKU.Sku, SKU.Descr, SKU.Packkey, SKU.AltSku, SKU.StdCube, SKU.StdGrossWgt, SKU.Sku  
       FROM SKU (NOLOCK)  
       JOIN RECEIPTDETAIL RD (NOLOCK) ON SKU.Storerkey = RD.Storerkey AND SKU.Sku = RD.Sku  
       JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey  
       WHERE R.Receiptkey = @c_Receiptkey  
    END  
                  
    SELECT RECEIPTDETAIL.StorerKey,   
        CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END,   
         RECEIPT.ReceiptKey,  
         RECEIPTDETAIL.ExternReceiptKey,  
         RECEIPT.ReceiptDate,   
         ISNULL(CODELKUP.Description , RECEIPT.ASNReason) ASNReason,     
         CAST(RECEIPT.Notes as varchar(215)) as Notes,   
         RECEIPT.RecType,   
         RECEIPT.CarrierKey,  
         RECEIPT.ExternReceiptKey,     /*SOS 121091*/   
         RECEIPT.CarrierReference,  
         RECEIPT.WarehouseReference,  
         RECEIPT.ContainerKey,   
         RECEIPT.VehicleNumber,   
         RECEIPT.PlaceOfDischarge,   
         SKU.DESCR,     
         SKU.AltSKU,   
         PACK.Pallet,   
         (PACK.Pallet / CASE WHEN Pack.CaseCnt = 0 THEN 1 ELSE Pack.CaseCnt END) AS FB,   
         COUNT(DISTINCT RECEIPTDETAIL.ToID) As Qty_Pallet,  
      SUM(RECEIPTDETAIL.QtyReceived)  As Qty_Each,    
      SUM(RECEIPTDETAIL.QtyReceived / CASE WHEN Pack.CaseCnt = 0 THEN 1 ELSE Pack.CaseCnt END)  As Qty_FB,    
         SUM(RECEIPTDETAIL.QtyReceived * SKU.StdCube) AS NoOfM3,   
         SUM(RECEIPTDETAIL.QtyReceived * SKU.STDGROSSWGT) AS NoOfMT,   
         RECEIPTDETAIL.Lottable01 As C_Lot,   
         RECEIPTDETAIL.Lottable02 As BatchNo,   
         RECEIPTDETAIL.Lottable03 AS Grade,   
         RECEIPTDETAIL.Lottable05 AS ProdDate,   
         RECEIPTDETAIL.Lottable04 AS UBD,   
         STORER.Company,   
         ISNULL(RECEIPT.Signatory, '') Signatory,  
         ISNULL(RECEIPT.UserDefine01 ,'') UserDefine01,   
         ISNULL(RECEIPT.POKEY ,RECEIPTDETAIL.POKEY) POKEY  
   , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS HideQty                  --CS01  
   , CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showdatereceived         --CS02  
   , MAX(receiptdetail.datereceived) as Recvdate                                            --CS02   
    FROM RECEIPTDETAIL WITH (NOLOCK)  
    JOIN RECEIPT WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )  
    JOIN STORER WITH (NOLOCK) ON ( RECEIPTDETAIL.StorerKey = STORER.StorerKey )  
    JOIN #TEMP_SKU SKU WITH (NOLOCK) ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey ) and    
                                      ( SKU.Sku = RECEIPTDETAIL.Sku )  
    JOIN PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey )  
    LEFT JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.CODE = RECEIPT.ASNREASON AND CODELKUP.ListName = 'ASNREASON')   
 --CS01 Start  
 LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (RECEIPT.Storerkey = CLR.Storerkey AND CLR.Code = 'HIDEQTY'  
                                              AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_warrant_receipt' AND ISNULL(CLR.Short,'') <> 'N')  
 --CS01 End  
 --CS02 Start  
 LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (RECEIPT.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWDATERECEIVED'  
                                              AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_warrant_receipt' AND ISNULL(CLR1.Short,'') <> 'N')  
 --CS02 End  
    WHERE ( RECEIPTDETAIL.Receiptkey = @c_receiptkey )   
     GROUP BY RECEIPTDETAIL.StorerKey,   
                RECEIPTDETAIL.Sku,   
                CASE WHEN ISNULL(SKU.CombineSku,'')='' THEN SKU.Sku ELSE SKU.CombineSku END,  
                RECEIPT.ReceiptKey,  
                RECEIPTDETAIL.ExternReceiptKey,   
                RECEIPT.ReceiptDate,   
                RECEIPT.ASNReason,     
                CODELKUP.Description,   
                CAST(RECEIPT.Notes as varchar(215)),   
                RECEIPT.RecType,   
                RECEIPT.CarrierKey,  
                RECEIPT.ExternReceiptKey,   
                RECEIPT.CarrierReference,  
                RECEIPT.WarehouseReference,  
                RECEIPT.ContainerKey,   
                RECEIPT.VehicleNumber,   
                RECEIPT.PlaceOfDischarge,   
                SKU.DESCR,     
                SKU.AltSKU,   
                PACK.Pallet,   
                (PACK.Pallet / CASE WHEN Pack.CaseCnt = 0 THEN 1 ELSE Pack.CaseCnt END),   
                RECEIPTDETAIL.Lottable01,  
                RECEIPTDETAIL.Lottable02,  
                RECEIPTDETAIL.Lottable03,  
                RECEIPTDETAIL.Lottable04,  
                RECEIPTDETAIL.Lottable05,  
                STORER.Company,   
                RECEIPT.Signatory,   
                RECEIPT.UserDefine01,   
                ISNULL(RECEIPT.POKEY ,RECEIPTDETAIL.POKEY)   
    , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END                  --CS01  
    , CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END                 --CS02    
     
 END          

GO