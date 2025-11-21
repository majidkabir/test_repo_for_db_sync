SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_SOExplodeItem_Wrapper                          */  
/* Creation Date: 14-Mar-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Shipment Order Explode Item                                 */  
/*                                                                      */  
/* Called By: Shipment Order                                            */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/   

CREATE PROCEDURE [WM].[lsp_SOExplodeItem_Wrapper]
     @c_Orderkey NVARCHAR(10) 
   ,@c_OrderLineNumber NVARCHAR(5)=''  
   ,@b_Success INT=1 OUTPUT 
   ,@n_Err INT=0 OUTPUT
   ,@c_ErrMsg NVARCHAR(250)='' OUTPUT
   ,@c_UserName NVARCHAR(128)=''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
    
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
   BEGIN    
       EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
       IF @n_Err <> 0 
       BEGIN
         GOTO EXIT_SP
       END
    
       EXECUTE AS LOGIN = @c_UserName
   END                                   --(Wan01) - END
    
   BEGIN TRY -- SWT01 - Begin Outer Begin Try
              --     
      DECLARE @n_Continue              INT
         ,@n_starttcnt             INT
         ,@c_StorerKey             NVARCHAR(15) 
         ,@c_Sku                   NVARCHAR(20)         
         ,@c_ComponentSku          NVARCHAR(15)
         ,@n_ComponentQty          INT
         ,@c_ComponentPackkey      NVARCHAR(10)
         ,@c_ComponentPACKUOM3     NVARCHAR(10)
         ,@c_NewOrderLineNumber    NVARCHAR(5)
         ,@n_MaxLineNo             INT
         ,@c_RemoveLine            NCHAR(1)
         ,@n_OpenQty               INT
         ,@n_explodecount          INT
               
      SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1, @n_explodecount = 0
         
      --Standard  
      IF @n_continue IN(1,2)
      BEGIN
      SELECT @n_MaxLineNo = CAST(MAX(OrderLineNumber) AS INT)
      FROM ORDERDETAIL (NOLOCK)
      WHERE Orderkey = @c_Orderkey

         DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT OD.Orderkey
                  ,OD.OrderLineNumber
                  ,OD.StorerKey
                  ,OD.Sku
            FROM   ORDERDETAIL OD WITH (NOLOCK) 
            JOIN   ORDERS AS OH WITH(NOLOCK) ON OH.Orderkey = OD.Orderkey 
            WHERE  OD.OrderKey = @c_OrderKey
            AND    OD.OrderLineNumber = CASE WHEN ISNULL(@c_OrderLineNumber,'') <> '' THEN @c_OrderLineNumber ELSE OD.OrderLineNumber END

         OPEN CUR_ORDER_LINES
       
         FETCH FROM CUR_ORDER_LINES INTO @c_OrderKey, @c_OrderLineNumber, @c_StorerKey, @c_Sku
       
         WHILE @@FETCH_STATUS=0 AND @n_continue IN(1,2)
         BEGIN
            SET @c_RemoveLine = 'N'
           
            DECLARE CUR_BILLOFMATERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT BillOfMaterial.componentsku,   
                     BillOfMaterial.qty,   
                     SKU.PACKKey,   
                     PACK.PackUOM3                  
               FROM BillOfMaterial (NOLOCK) 
               JOIN SKU (NOLOCK) ON BillOfMaterial.storerkey = SKU.StorerKey AND BillOfMaterial.componentsku = SKU.Sku 
               JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey  
               WHERE BillOfMaterial.Storerkey = @c_Storerkey  
               AND BillOfMaterial.sku = @c_Sku
 
            OPEN CUR_BILLOFMATERIAL
          
            FETCH FROM CUR_BILLOFMATERIAL INTO @c_ComponentSku, @n_ComponentQty, @c_ComponentPackkey, @c_ComponentPACKUOM3
          
            IF @@FETCH_STATUS = 0
               SELECT @n_explodecount = @n_explodecount + 1          
          
            WHILE @@FETCH_STATUS=0 AND @n_continue IN(1,2)
            BEGIN             
               SELECT @n_MaxLineNo = @n_MaxLineNo + 1
               SELECT @c_NewOrderLineNumber = RIGHT('00000' + LTRIM(RTRIM(CAST(@n_MaxLineNo AS NVARCHAR))),5)
             
               INSERT INTO ORDERDETAIL
                     (
                     OrderKey,
                     OrderLineNumber,
                     ExternOrderKey,
                     ExternLineNo,
                     Sku,
                     StorerKey,
                     ManufacturerSku,
                     RetailSku,
                     AltSku,
                     OriginalQty,
                     OpenQty,
                     ShippedQty,
                     AdjustedQty,
                     QtyPreAllocated,
                     QtyAllocated,
                     QtyPicked,
                     UOM,
                     PackKey,
                     PickCode,
                     CartonGroup,
                     Lot,
                     ID,
                     Facility,
                     [Status],
                     UnitPrice,
                     Tax01,
                     Tax02,
                     ExtendedPrice,
                     UpdateSource,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable04,
                     Lottable05,
                     EffectiveDate,
                     TariffKey,
                     FreeGoodQty,
                     GrossWeight,
                     Capacity,
                     LoadKey,
                     MBOLKey,
                     QtyToProcess,
                     MinShelfLife,
                     UserDefine01,
                     UserDefine02,
                     UserDefine03,
                     UserDefine04,
                     UserDefine05,
                     UserDefine06,
                     UserDefine07,
                     UserDefine08,
                     UserDefine09,
                     POkey,
                     ExternPOKey,
                     UserDefine10,
                     EnteredQTY,
                     ConsoOrderKey,
                     ExternConsoOrderKey,
                     ConsoOrderLineNo,
                     Notes,
                     Notes2,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12,
                     Lottable13,
                     Lottable14,
                     Lottable15
                     )             
               SELECT OrderKey,
                     @c_NewOrderLineNumber,
                     ExternOrderKey,
                     ExternLineNo,
                     @c_ComponentSku,
                     StorerKey,
                     '', --ManufacturerSku
                     '', --RetailSku
                     Sku, --AltSku
                     OriginalQty * @n_ComponentQty,
                     OpenQty * @n_ComponentQty,
                     ShippedQty * @n_ComponentQty,
                     AdjustedQty * @n_ComponentQty,
                     0, --QtyPreAllocated,
                     0, --QtyAllocated,
                     0, --QtyPicked,
                     @c_ComponentPACKUOM3,
                     @c_ComponentPackKey,
                     PickCode,
                     CartonGroup,
                     Lot,
                     ID,
                     Facility,
                     [Status],
                     UnitPrice,
                     Tax01,
                     Tax02,
                     ExtendedPrice,
                     UpdateSource,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable04,
                     Lottable05,
                     EffectiveDate,
                     TariffKey,
                     FreeGoodQty,
                     GrossWeight,
                     Capacity,
                     LoadKey,
                     MBOLKey,
                     OpenQty, --QtyToProcess
                     MinShelfLife,
                     UserDefine01,
                     UserDefine02,
                     UserDefine03,
                     UserDefine04,
                     UserDefine05,
                     UserDefine06,
                     UserDefine07,
                     UserDefine08,
                     UserDefine09,
                     POkey,
                     ExternPOKey,
                     UserDefine10,
                     EnteredQTY,
                     ConsoOrderKey,
                     ExternConsoOrderKey,
                     ConsoOrderLineNo,
                     Notes,
                     Notes2,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12,
                     Lottable13,
                     Lottable14,
                     Lottable15
               FROM ORDERDETAIL (NOLOCK)
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNUmber = @c_OrderLineNumber
    
               IF @@ERROR <> 0 
               BEGIN         
                  SELECT @n_continue = 3  
                  SELECT @n_Err = 551451
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                        ': Insert RECEIPTDETAIL Failed. (lsp_SOExplodeItem_Wrapper)'
                  SELECT @c_RemoveLine = 'N'
               END         
               ELSE
                  SELECT @c_RemoveLine = 'Y'            
                  
               FETCH FROM CUR_BILLOFMATERIAL INTO @c_ComponentSku, @n_ComponentQty, @c_ComponentPackkey, @c_ComponentPACKUOM3                                                   
            END          
            CLOSE CUR_BILLOFMATERIAL
            DEALLOCATE CUR_BILLOFMATERIAL     
                    
            IF @c_RemoveLine = 'Y'
            BEGIN
               DELETE FROM ORDERDETAIL 
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber

               IF @@ERROR <> 0 
               BEGIN         
                  SELECT @n_continue = 3  
                  SELECT @n_Err = 551452
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                        ': Delete RECEIPTDETAIL Failed. (lsp_SOExplodeItem_Wrapper)'
               END         
            END          
           
            FETCH FROM CUR_ORDER_LINES INTO @c_OrderKey, @c_OrderLineNumber, @c_StorerKey, @c_Sku
         END
         CLOSE CUR_ORDER_LINES
         DEALLOCATE CUR_ORDER_LINES
      END                     
    
    --Multipack SOS#198615
      IF @n_continue IN(1,2)
      BEGIN
         SELECT @n_MaxLineNo = CAST(MAX(OrderLineNumber) AS INT)
         FROM ORDERDETAIL (NOLOCK)
         WHERE Orderkey = @c_Orderkey

            DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT OD.Orderkey
                     ,OD.OrderLineNumber
                     ,OD.StorerKey
                     ,OD.Sku
                     ,OD.OpenQty
               FROM   ORDERDETAIL OD WITH (NOLOCK) 
               JOIN   ORDERS AS OH WITH(NOLOCK) ON OH.Orderkey = OD.Orderkey 
               WHERE  OD.OrderKey = @c_OrderKey
               AND    OD.OrderLineNumber = CASE WHEN ISNULL(@c_OrderLineNumber,'') <> '' THEN @c_OrderLineNumber ELSE OD.OrderLineNumber END

         OPEN CUR_ORDER_LINES
       
         FETCH FROM CUR_ORDER_LINES INTO @c_OrderKey, @c_OrderLineNumber, @c_StorerKey, @c_Sku, @n_OpenQty
       
         WHILE @@FETCH_STATUS=0 AND @n_continue IN(1,2)
         BEGIN
            SET @c_RemoveLine = 'N'
           
            DECLARE CUR_BILLOFMATERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT BOM.ComponentSku, BOM.ComponentSku_Packkey, BOM.ComponentSku_Packuom3, 
                     SUM(CASE WHEN ORD.casecnt = BOM.uomqty THEN ORD.fullpackctn * BOM.componentqty ELSE BOM.componentqty END) AS Componentqty 
               FROM (SELECT SKU.Storerkey, SKU.Sku,  
                           CASE WHEN PACK.Casecnt > 0 THEN FLOOR(@n_OpenQty / PACK.Casecnt) ELSE 0 END AS fullpackctn, 
                           @n_OpenQty % CAST(PACK.Casecnt AS INT) AS loosepackqty, PACK.casecnt  
                     FROM SKU (NOLOCK) 
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
                     WHERE SKU.Storerkey = @c_Storerkey
                     AND SKU.Sku = @c_Sku) AS ORD  
               JOIN  
                  (SELECT SKU.Storerkey, SKU.Sku,  
                           CASE WHEN PACK.Packuom3 = UPC.uom THEN PACK.qty 
                                 WHEN PACK.Packuom1 = UPC.uom THEN PACK.casecnt 
                                 WHEN PACK.Packuom2 = UPC.uom THEN PACK.innerpack 
                                 WHEN PACK.Packuom4 = UPC.uom THEN PACK.pallet 
                                 WHEN PACK.Packuom5 = UPC.uom THEN PACK.cube 
                                 WHEN PACK.Packuom6 = UPC.uom THEN PACK.grosswgt END AS uomqty, 
                           BM.Sequence, BM.Componentsku, BM.QTY AS ComponentQty,  
                           SKU.Packkey, UPC.Upc, UPC.UOM, SKUCOMP.Descr AS Componentsku_descr,
                           SKUCOMP.Packkey AS Componentsku_packkey, PACKCOMP.Packuom3 AS Componentsku_packuom3 
                     FROM SKU (NOLOCK)  
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey 
                     JOIN UPC (NOLOCK) ON ((PACK.packuom3 = UPC.UOM   
                                          OR PACK.packuom1 = UPC.UOM 
                                          OR PACK.packuom2 = UPC.UOM 
                                          OR PACK.packuom4 = UPC.UOM 
                                          OR PACK.packuom5 = UPC.UOM 
                                          OR PACK.packuom6 = UPC.UOM)  
                                          AND SKU.Storerkey = UPC.Storerkey 
                                          AND SKU.Sku = UPC.Sku 
                                          AND SKU.Packkey = UPC.Packkey) 
                     JOIN BILLOFMATERIAL BM (NOLOCK) ON UPC.Storerkey = BM.Storerkey  
                                                         AND UPC.Upc = BM.Sku  
                     JOIN SKU SKUCOMP (NOLOCK) ON BM.Storerkey = SKUCOMP.Storerkey 
                                             AND BM.ComponentSku = SKUCOMP.Sku 
                     JOIN PACK PACKCOMP (NOLOCK) ON SKUCOMP.Packkey = PACKCOMP.Packkey 
                     WHERE SKU.Storerkey = @c_Storerkey 
                     AND SKU.Sku = @c_Sku) AS BOM 
               ON (ORD.Storerkey = BOM.Storerkey AND ORD.Sku = BOM.Sku  
                  AND (CASE WHEN ORD.fullpackctn > 0 THEN ORD.Casecnt ELSE 0 END = BOM.uomqty  
                     OR ORD.loosepackqty = BOM.uomqty))  
               GROUP BY ORD.Storerkey, ORD.Sku, BOM.ComponentSku, BOM.ComponentSku_Packkey,  
                        BOM.ComponentSku_Packuom3, BOM.ComponentSku_descr 
 
            OPEN CUR_BILLOFMATERIAL
          
            FETCH FROM CUR_BILLOFMATERIAL INTO @c_ComponentSku, @c_ComponentPackkey, @c_ComponentPACKUOM3, @n_ComponentQty
          
            IF @@FETCH_STATUS = 0
               SELECT @n_explodecount = @n_explodecount + 1          
          
            WHILE @@FETCH_STATUS=0 AND @n_continue IN(1,2)
            BEGIN             
               SELECT @n_MaxLineNo = @n_MaxLineNo + 1
               SELECT @c_NewOrderLineNumber = RIGHT('00000' + LTRIM(RTRIM(CAST(@n_MaxLineNo AS NVARCHAR))),5)
             
               INSERT INTO ORDERDETAIL
                     (
                     OrderKey,
                     OrderLineNumber,
                     ExternOrderKey,
                     ExternLineNo,
                     Sku,
                     StorerKey,
                     ManufacturerSku,
                     RetailSku,
                     AltSku,
                     OriginalQty,
                     OpenQty,
                     ShippedQty,
                     AdjustedQty,
                     QtyPreAllocated,
                     QtyAllocated,
                     QtyPicked,
                     UOM,
                     PackKey,
                     PickCode,
                     CartonGroup,
                     Lot,
                     ID,
                     Facility,
                     [Status],
                     UnitPrice,
                     Tax01,
                     Tax02,
                     ExtendedPrice,
                     UpdateSource,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable04,
                     Lottable05,
                     EffectiveDate,
                     TariffKey,
                     FreeGoodQty,
                     GrossWeight,
                     Capacity,
                     LoadKey,
                     MBOLKey,
                     QtyToProcess,
                     MinShelfLife,
                     UserDefine01,
                     UserDefine02,
                     UserDefine03,
                     UserDefine04,
                     UserDefine05,
                     UserDefine06,
                     UserDefine07,
                     UserDefine08,
                     UserDefine09,
                     POkey,
                     ExternPOKey,
                     UserDefine10,
                     EnteredQTY,
                     ConsoOrderKey,
                     ExternConsoOrderKey,
                     ConsoOrderLineNo,
                     Notes,
                     Notes2,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12,
                     Lottable13,
                     Lottable14,
                     Lottable15
                     )             
               SELECT OrderKey,
                     @c_NewOrderLineNumber,
                     ExternOrderKey,
                     ExternLineNo,
                     @c_ComponentSku,
                     StorerKey,
                     '', --ManufacturerSku
                     '', --RetailSku
                     Sku, --AltSku
                     @n_ComponentQty, --OriginalQty
                     @n_ComponentQty, --OpenQty
                     0, --ShippedQty
                     0, --AdjustedQty
                     0, --QtyPreAllocated,
                     0, --QtyAllocated,
                     0, --QtyPicked,
                     @c_ComponentPACKUOM3,
                     @c_ComponentPackKey,
                     PickCode,
                     CartonGroup,
                     Lot,
                     ID,
                     Facility,
                     [Status],
                     UnitPrice,
                     Tax01,
                     Tax02,
                     ExtendedPrice,
                     UpdateSource,
                     Lottable01,
                     Lottable02,
                     Lottable03,
                     Lottable04,
                     Lottable05,
                     EffectiveDate,
                     TariffKey,
                     FreeGoodQty,
                     GrossWeight,
                     Capacity,
                     LoadKey,
                     MBOLKey,
                     OpenQty, --QtyToProcess
                     MinShelfLife,
                     UserDefine01,
                     UserDefine02,
                     UserDefine03,
                     UserDefine04,
                     UserDefine05,
                     UserDefine06,
                     UserDefine07,
                     UserDefine08,
                     UserDefine09,
                     POkey,
                     ExternPOKey,
                     UserDefine10,
                     EnteredQTY,
                     ConsoOrderKey,
                     ExternConsoOrderKey,
                     ConsoOrderLineNo,
                     Notes,
                     Notes2,
                     Lottable06,
                     Lottable07,
                     Lottable08,
                     Lottable09,
                     Lottable10,
                     Lottable11,
                     Lottable12,
                     Lottable13,
                     Lottable14,
                     Lottable15
               FROM ORDERDETAIL (NOLOCK)
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNUmber = @c_OrderLineNumber
    
               IF @@ERROR <> 0 
               BEGIN         
                  SELECT @n_continue = 3  
                  SELECT @n_Err = 551453
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                        ': Insert RECEIPTDETAIL Failed. (lsp_SOExplodeItem_Wrapper)'
                  SELECT @c_RemoveLine = 'N'
               END         
               ELSE
                  SELECT @c_RemoveLine = 'Y'            
                  
               FETCH FROM CUR_BILLOFMATERIAL INTO @c_ComponentSku, @c_ComponentPackkey, @c_ComponentPACKUOM3, @n_ComponentQty                                                   
            END          
            CLOSE CUR_BILLOFMATERIAL
            DEALLOCATE CUR_BILLOFMATERIAL     
          
            IF @c_RemoveLine = 'Y'
            BEGIN
               DELETE FROM ORDERDETAIL 
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber

               IF @@ERROR <> 0 
               BEGIN         
                  SELECT @n_continue = 3  
                  SELECT @n_Err = 551454
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                        ': Delete RECEIPTDETAIL Failed. (lsp_SOExplodeItem_Wrapper)'
               END         
            END          
           
            FETCH FROM CUR_ORDER_LINES INTO @c_OrderKey, @c_OrderLineNumber, @c_StorerKey, @c_Sku, @n_OpenQty
         END
         CLOSE CUR_ORDER_LINES
         DEALLOCATE CUR_ORDER_LINES
      END                     
    
      IF @n_explodecount = 0 
      BEGIN         
         SELECT @n_continue = 3  
         SELECT @n_Err = 551455
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': No item found for explode. BOM not setup. (lsp_SOExplodeItem_Wrapper)'
      END         

   END TRY  
    
   BEGIN CATCH 
      SET @n_Continue = 3                 --(Wan01)
      SET @c_Errmsg = ERROR_MESSAGE()     --(Wan01)     
      GOTO EXIT_SP  
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch  
            --                  
   EXIT_SP: 
    
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
   ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_SOExplodeItem_Wrapper'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      --RETURN    --(Wan01)
   END  
   ELSE  
      BEGIN  
         SELECT @b_success = 1  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
         --RETURN --(Wan01)  
      END 
   --(Wan01) Move Down      
   REVERT               
END

GO