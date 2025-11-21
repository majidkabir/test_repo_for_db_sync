SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispForceConvertSKU]
    @c_Storer NVARCHAR(15),
    @c_OldSku    NVARCHAR(20),
    @c_NewSku    NVARCHAR(20)
 AS
 BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @ll_count int
    DECLARE @b_success bit
    DECLARE @i_status int
    SELECT * INTO #TempSku 
    FROM SKU
    WHERE SKU.StorerKey 	= @c_Storer
    AND   SKU.Sku 	= @c_OldSku
    IF @@ROWCOUNT = 0 OR @@ERROR <> 0
    BEGIN
       RETURN     
    END
     /* Create New Record For New Sku */
    Update #TempSku 
    Set #TempSku.OldSku  = @c_OldSku,
        #TempSku.Packkey = @c_NewSku,
        #TempSku.Sku     = @c_NewSku
    Where #TempSKU.Sku = @c_OldSku
    IF @@ERROR <> 0 
    BEGIN
       Drop Table #TempSku
       RETURN
    END
    BEGIN TRANSACTION
       INSERT INTO SKU
       SELECT * FROM #TempSku
       select "Selecting Sku ",@c_oldsku, " To Be Converted To ",@c_newsku
       select "Updating pack...."
       
       UPDATE PACK
       SET PackKey = @c_NewSku
       WHERE PackKey = @c_OldSku
       
       select "Updating Lotattribute ... "
       UPDATE LOTATTRIBUTE
       SET Sku = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating Lot ... "
       UPDATE LOT
       SET Sku = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating Lotxlocxid ... "
       UPDATE LOTxLOCxID
       SET Sku = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating Orderdetail ... "
       UPDATE  ORDERDETAIL
       SET Sku = @c_NewSku,
 	  Packkey = @c_NewSku
       WHERE StorerKey = @c_Storer
       AND   Sku = @c_OldSku
       select "Updating Pickdetail ... "
       UPDATE PICKDETAIL
       SET Sku = @c_NewSku,
 	  Packkey = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating Podetail ... "
       UPDATE PODETAIL
       SET Sku = @c_NewSku,
 	  Packkey = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating receiptdetail ... "
       UPDATE RECEIPTDETAIL
       SET Sku = @c_NewSku,
 	  Packkey = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating replenishment ... "
       UPDATE  REPLENISHMENT
       SET Sku = @c_NewSku,
 	  Packkey = @c_NewSku
       WHERE Sku = @c_OldSku            
       AND   StorerKey = @c_Storer
       select "Updating skuxloc ... "
       UPDATE SKUxLOC
       SET Sku = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       select "Updating transferdetail ... "
       UPDATE TRANSFERDETAIL 
       	 SET FromSku = @c_NewSku,
 	     FromPackkey = @c_NewSku
       WHERE  FromSku = @c_OldSku
       UPDATE TRANSFERDETAIL 
          SET ToSku = @c_NewSku,
 	     ToPackkey = @c_NewSku
       WHERE  ToSku = @c_OldSku
       select "Updating Adjustmentdetail ... "
       UPDATE ADJUSTMENTDETAIL
       SET Sku = @c_NewSku,
 	  Packkey = @c_NewSku
       WHERE Sku = @c_OldSku
       AND   StorerKey = @c_Storer
       DELETE FROM SKU WHERE SKU = @c_OldSku
       Drop Table #TempSku
 /*
       UPDATE exchangesku
       SET flag = "Y"
       WHERE oldsku = @c_OldSku  
 */
       IF @@ERROR <> 0
       BEGIN
          ROLLBACK TRANSACTION
 	 RETURN
       END
       COMMIT TRANSACTION
 END    /* End Of Procedure */
 RETURN


GO