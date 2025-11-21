SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 21-May-2012 KHLim01     1.2   Update EditDate                        */

CREATE PROCEDURE [dbo].[ispPatchLOTQty]
   @c_LOT NVARCHAR(10)
AS 
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_QtyAllocated  int,
   		  @n_QtyPicked     int,
           @nTranCount      int 


	SELECT @n_QtyPicked = SUM(CASE WHEN Status between '5' and '8' Then Qty Else 0 End),
          @n_QtyAllocated = SUM(CASE WHEN Status < '5' Then Qty Else 0 End) 
	FROM  PICKDETAIL (NOLOCK)
	WHERE LOT = @c_Lot
	and   status < '9'

   select @n_QtyPicked '@n_QtyPicked', @n_QtyAllocated '@n_QtyAllocated'
   -- 	SELECT @n_QtyAllocated = SUM(Qty) 	
   -- 	FROM  PICKDETAIL (NOLOCK)
   -- 	WHERE LOT = @c_Lot
   -- 	and   status in ('0','1','2','3','4')

	IF @n_QtyPicked IS NULL 
		SELECT @n_QtyPicked = 0

	IF @n_QtyAllocated IS NULL 
		SELECT @n_QtyAllocated = 0

   IF EXISTS(SELECT 1 FROM LOT (NOLOCK) WHERE LOT = @c_Lot 
             AND ( QtyAllocated <> @n_QtyAllocated OR QtyPicked <> @n_QtyPicked ) )
   BEGIN
      SELECT @nTranCount = @@TRANCOUNT

      BEGIN TRAN 

   	UPDATE LOT with (RowLOCK)   -- tlting 2009/4/8  rowlock
   		SET QtyPicked = @n_QtyPicked, QtyAllocated = @n_QtyAllocated, TrafficCop=NULL
            ,EditDate  = GETDATE()   -- KHLim01
   	WHERE LOT = @c_Lot
   	and   ( QtyAllocated <> @n_QtyAllocated OR QtyPicked <> @n_QtyPicked )

      IF @@ERROR = 0 
      BEGIN
         WHILE @@TRANCOUNT > @nTranCount
         BEGIN
            COMMIT TRAN 
         END 
      END 
      ELSE
      BEGIN
         ROLLBACK TRAN 
      END 
   END
END

GO