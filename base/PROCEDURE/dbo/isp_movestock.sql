SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_MoveStock                                      */    
/* Creation Date:                                                       */    
/* Copyright: LF Logistics                                              */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver. Purposes                                 */ 
/* 28-Oct-1014  Shong     1.1  Add 10 Lottables                         */    
/************************************************************************/
CREATE PROC [dbo].[isp_MoveStock] (@b_success int OUTPUT)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE	@c_sku NVARCHAR(20),
		@c_FROMID	 NVARCHAR(18),
		@c_TOID		 NVARCHAR(18),
		@c_FromLoc	 NVARCHAR(10),
		@c_ToLoc		 NVARCHAR(10),
		@n_qty		 int,
		@d_today	    datetime,
		@c_packkey	 NVARCHAR(10),
		@c_UOM		 NVARCHAR(10),
		@c_Temploc	 NVARCHAR(10),
		@c_Tempsku	 NVARCHAR(20),
      @c_Storerkey NVARCHAR(15),
      @n_RowId     int,
      @n_continue  int,
      @c_LOT       NVARCHAR(10),
      @c_errmsg    NVARCHAR(255),
		@n_err		int                 

   SELECT @d_today = GetDate(), @n_continue = 1

   SELECT StorerKey, SKU, LOT, FromLOC, ToLOC, FromID, ToID, Qty, RowID 
   INTO  #MoveStock 
   FROM  idsMoveStock 
   
   DECLARE inv_cur CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT StorerKey, SKU, LOT, FromLOC, ToLOC, FromID, ToID, Qty, RowID 
   FROM #MoveStock
	ORDER BY RowId
    
   OPEN inv_cur
   FETCH NEXT FROM inv_cur INTO @c_StorerKey, @c_SKU, @c_LOT, @c_FromLOC, @c_ToLOC, @c_FromID, 
			@c_ToID, @n_Qty, @n_RowId
 
   WHILE (@@FETCH_STATUS <> -1)

   BEGIN
		SELECT @c_StorerKey, @c_SKU, @c_LOT, @c_FromLOC, @c_ToLOC, @c_FromID, 
			@c_ToID, @n_Qty, @n_RowId		

      SELECT @n_continue = 1	
      IF @c_FromID IS NULL SELECT @c_FromID = ''
      IF @c_TOID IS NULL SELECT @c_ToID = ''

      SELECT @c_packkey = '', @c_UOM = ''

      SELECT @c_packkey = SKU.packkey,
	     @c_UOM = packuom3
      FROM  SKU (NOLOCK), PACK (NOLOCK)
      WHERE SKU.Packkey = PACK.Packkey
      AND   SKU.STORERKEY = @C_STORERKEY
      AND   SKU.SKU       = @c_SKU

      IF @c_packkey = '' OR @c_packkey IS NULL
      BEGIN
         SELECT @n_continue = 3
      END 
	
      IF @n_continue = 1 
      BEGIN
			 SELECT @c_tempsku = ''

	       IF NOT EXISTS ( SELECT SKU FROM SKU (NOLOCK) WHERE SKU.STORERKEY = @C_STORERKEY AND SKU = @c_sku)
			 BEGIN
            SELECT @n_continue = 3
	 		 END
      END

      IF @n_continue = 1
      BEGIN	
         IF NOT EXISTS( SELECT LOC FROM LOC (NOLOCK) WHERE Loc = @c_FromLoc )
	 		BEGIN
         	SELECT @n_continue = 3
	 		END

         IF NOT EXISTS( SELECT LOC FROM LOC (NOLOCK) WHERE Loc = @c_ToLoc )
	 		BEGIN
            SELECT @n_continue = 3
	 		END
      END

      IF @n_Continue <> 3
      BEGIN     
         IF NOT EXISTS (SELECT Qty FROM LOTxLOCxID (NOLOCK) 
                        WHERE LOT = @c_LOT 
                        AND   LOC = @c_FromLOC
                        AND   ID  = @c_FromID 
                        AND   Qty - (QtyPicked + QtyAllocated) < @n_Qty )
         BEGIN       
            SELECT @c_StorerKey '@c_StorerKey', 
					   @c_Sku      '@c_Sku', 
					   @c_Lot      '@c_Lot', 
					   @c_FromLoc  '@c_FromLoc', 
					   @c_FromID   '@c_FromID', 
					   @c_ToLoc    '@c_ToLoc', 
					   @c_ToID     '@c_ToID' 
                   
            BEGIN TRAN

            SELECT @b_success = 1

            EXECUTE nspItrnAddMove 
                NULL
					 ,@c_StorerKey 
					 ,@c_Sku
					 ,@c_Lot 
					 ,@c_FromLoc 
					 ,@c_FromID 
					 ,@c_ToLoc 
					 ,@c_ToID 
                ,ULL
                ,''   -- @c_lottable01
                ,''   -- @c_lottable02
                ,''   -- @c_lottable03
                ,NULL -- @d_lottable04
                ,NULL -- @d_lottable05
					 ,''   -- @d_lottable06
                ,''   -- @d_lottable07
                ,''   -- @d_lottable08
					 ,''   -- @d_lottable09
                ,''   -- @d_lottable10
                ,''   -- @d_lottable11
					 ,''   -- @d_lottable12
					 ,NULL -- @d_lottable13
                ,NULL -- @d_lottable14
                ,NULL -- @d_lottable15
                ,0
                ,0
				    ,@n_qty 
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,''
					 ,'isp_MoveStock' 
					 ,@c_PackKey 
					 ,@c_UOM
					 ,1
                ,@d_today
                ,'' -- @c_itrnkey    
			       ,@b_Success OUTPUT 
                ,@n_err OUTPUT 
					 ,@c_errmsg OUTPUT 


            IF NOT @b_success = 1 
            BEGIN
               SELECT @n_continue = 3
               ROLLBACK TRAN
               BREAK
            END
            ELSE 
            BEGIN
               DELETE idsMoveStock WHERE RowID = @n_RowId

               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN
            END
	 	END
	 	ELSE
	 	BEGIN
			SELECT 'NOT ENOUGH STOCK TO Move'
    	END -- if overallocated
    END -- continue = 1
		-- BREAK
      FETCH NEXT FROM inv_cur INTO @c_StorerKey, @c_SKU, @c_LOT, @c_FromLOC, @c_ToLOC, @c_FromID, 
			@c_ToID, @n_Qty, @n_RowId  
   END
   CLOSE inv_cur	
   DEALLOCATE inv_cur

END 

GO