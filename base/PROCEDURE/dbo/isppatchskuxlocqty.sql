SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPatchSKUxLOCQty                                 */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
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
/* Date        Author   ver  Purposes                                   */  
/* 21-May-2012 KHLim01  1.2  Update EditDate                            */
/* 13-Jul-2017 TLTING   1.3  Commit tran fix                            */
/* 03-Nov-2020 SHONG    1.4  Update QtyExpected for Pick Location       */
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispPatchSKUxLOCQty]
   @c_StorerKey NVARCHAR(15),
   @c_SKU  NVARCHAR(20),   
   @c_LOC  NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_QtyAllocated  int,
		     @n_QtyPicked     int,
           @c_LocationType   NVARCHAR(10),
           @c_SLLocationType NVARCHAR(10)

	SELECT @n_QtyAllocated = SUM(Qty) 	
	FROM  PICKDETAIL (NOLOCK)
	WHERE StorerKey = @c_StorerKey
	AND   SKU = @c_SKU
	AND   LOC = @c_LOC
	AND   status in ('0','1','2','3','4')

	SELECT @n_QtyPicked = SUM(Qty) 	
	FROM  PICKDETAIL (NOLOCK)
	WHERE StorerKey = @c_StorerKey
	AND   SKU = @c_SKU
	AND   LOC = @c_LOC
	AND   status in ('5','6','7','8')

	IF @n_QtyAllocated IS NULL 
		SELECT @n_QtyAllocated = 0

	IF @n_QtyPicked IS NULL 
		SELECT @n_QtyPicked = 0

	BEGIN TRAN
   
   IF EXISTS(SELECT 1 FROM SKUxLOC (NOLOCK) WHERE StorerKey = @c_StorerKey
            	and   SKU = @c_SKU
            	and   LOC = @c_LOC
            	and   ( QtyAllocated <> @n_QtyAllocated OR QtyPicked <> @n_QtyPicked ))
   BEGIN
      SET @c_SLLocationType = ''
      SET @c_LocationType = '' 
  
      SELECT @c_LocationType  = LocationType 
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @c_loc 

      SELECT @c_SLLocationType = LocationType 
      FROM SKUxLOC WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND   SKU = @c_SKU 
      AND   LOC = @c_LOC 

      BEGIN TRAN 

   	UPDATE SKUxLOC  WITH (RowLOCK) -- TLTING 2009/4/8  rowlock
   		SET QtyAllocated = @n_QtyAllocated
            ,QtyPicked = @n_QtyPicked
            ,TrafficCop=NULL
            ,QtyExpected  = CASE WHEN @c_SLLocationType NOT IN ('CASE','PICK') AND              
                                   @c_LocationType NOT IN ('DYNPICKP', 'DYNPICKR','DYNPPICK') THEN 0   
                             WHEN (@n_QtyAllocated +  @n_QtyPicked) > Qty
                                  THEN (@n_QtyAllocated +  @n_QtyPicked) - Qty
                             ELSE 0
                        END 
            ,EditDate  = GETDATE()   -- KHLim01
   	WHERE StorerKey = @c_StorerKey
   	and   SKU = @c_SKU
   	and   LOC = @c_LOC
   	and   ( QtyAllocated <> @n_QtyAllocated OR QtyPicked <> @n_QtyPicked )
   	IF @@ERROR = 0
      BEGIN
     		   COMMIT TRAN
      END 
   	ELSE
   		ROLLBACK TRAN
   END

   COMMIT TRAN

END

GO