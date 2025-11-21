SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspDailyInventoryChannel                           */
/* CreatiON Date: 20-09-2019                                            */
/* Copyright: IDS                                                       */
/* Written by: TING                                                     */
/*                                                                      */
/* Purpose: Snap shoot for Inventory Channel                            */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS VersiON: 1.1                                                    */
/*                                                                      */
/* VersiON: 5.4                                                         */
/*                                                                      */
/* Data ModificatiONs:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  ver    Purposes                                 */
/* 10-08-2009   tlting  1.1    Initial                                  */
/************************************************************************/
CREATE PROCEDURE [dbo].[nspDailyInventoryChannel] (  
   @c_storerkey NVARCHAR(15) = '%'
 , @b_debug NVARCHAR(1) = 0
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @d_inventorydate datetime
			  ,@b_success     NVARCHAR(1)
			  ,@c_authority NVARCHAR(1)
			  ,@n_err			int
			  ,@c_errmsg	 NVARCHAR(60)
			 
   SET @d_inventorydate = CONVERT(smalldatetime, CONVERT(char(8), GETDATE() - 1, 112), 112)
	-- SET @b_debug = 0
   
   IF RTRIM(@c_storerkey) IS NULL       
      SET @c_storerkey = '%' 
   
   IF @c_storerkey = '%'
   BEGIN

      /* Just in case this sp have been run twice, so have to delete first before insert */
	   IF @b_debug = 1
	   BEGIN	
	      PRINT 'Delete FROM DailyInventoryChannel'
	   END
      DELETE FROM DailyInventoryChannel WHERE datediff (day, getdate() - 1, inventorydate) = 0

	   /* Get Storerkey & Check DailyInventory Storer CONfigkey Setting */
	   DECLARE Storer_cur CURSOR FAST_FORWARD READ_ONLY FOR
		   SELECT Storerkey
		   FROM   STORER (NOLOCK)
		   WHERE  Type = '1'
         AND EXISTS ( SELECT 1 FROM ChannelInv (NOLOCK) WHERE  ChannelInv.Storerkey = STORER.Storerkey )
		   Order by Storerkey
    END
    ELSE
    BEGIN
      /* Just in case this sp have been run twice, so have to delete first before insert */
	   IF @b_debug = 1
	   BEGIN	
	      PRINT 'Delete FROM DailyInventoryChannel WHERE Storerkey = ''' + @c_storerkey + ''''
	   END
      DELETE FROM DailyInventoryChannel WHERE datediff (day, getdate() - 1, inventorydate) = 0 AND Storerkey = @c_storerkey

	   /* Get Storerkey & Check DailyInventory Storer CONfigkey Setting */
	   DECLARE Storer_cur CURSOR FAST_FORWARD READ_ONLY FOR
		   SELECT Storerkey
		   FROM   STORER (NOLOCK)
		   WHERE  Type = '1'
         AND Storerkey = @c_storerkey
		   Order by Storerkey
    END
	
	OPEN Storer_cur
	FETCH NEXT FROM Storer_cur INTO @c_Storerkey

	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
  
			/******************************************************
					***		Snapshot FROM ChannelInv ***
		    ******************************************************/
			IF @b_debug = 2
			BEGIN	
			   PRINT 'Insert into  DailyInventoryChannel - Use ChannelInv !'
			END
          
		   INSERT INTO DailyInventoryChannel (Channel_ID, InventoryDate, StorerKey, SKU, 
                  Facility, Channel, C_Attribute01, C_Attribute02, C_Attribute03, 
                  C_Attribute04, C_Attribute05, Qty, QtyAllocated, QtyOnHold 
							)			
		   SELECT Channel_ID, @d_inventorydate, StorerKey, SKU, 
                  Facility, Channel, C_Attribute01, C_Attribute02, C_Attribute03, 
                  C_Attribute04, C_Attribute05, Qty, QtyAllocated, QtyOnHold  
		   FROM   ChannelInv CI (NOLOCK) 
			WHERE   CI.Storerkey   = @c_Storerkey			
         AND qty > 0

 

		FETCH NEXT FROM Storer_cur INTO @c_Storerkey
	END -- While

	CLOSE Storer_cur
	DEALLOCATE Storer_cur
END

GO