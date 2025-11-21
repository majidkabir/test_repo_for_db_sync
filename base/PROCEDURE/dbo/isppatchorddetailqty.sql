SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 21-May-2012 KHLim01     1.2   Update EditDate                        */

CREATE PROCEDURE [dbo].[ispPatchOrdDetailQty]
   @c_orderkey NVARCHAR(10),
   @c_orderline NVARCHAR(5)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_QtyPicked int,
   		  @n_QtyAllocated int

 	SELECT @n_QtyPicked = SUM(Qty) 	
	FROM  PICKDETAIL (NOLOCK)
	WHERE orderkey = @c_orderkey 
   and   orderlinenumber = @c_orderline
   and   status Between '5' AND '8'       -- tlting 2009/4/8 
	--and   status in ('5','6','7','8')

	SELECT @n_QtyAllocated = SUM(Qty) 	
	FROM  PICKDETAIL (NOLOCK)
	WHERE orderkey = @c_orderkey 
   and   orderlinenumber = @c_orderline
   and   status Between '0' AND '4'    -- tlting 2009/4/8 
	--and   status in ('0','1','2','3','4')

	IF @n_QtyPicked IS NULL 
		SELECT @n_QtyPicked = 0

	IF @n_QtyAllocated IS NULL 
		SELECT @n_QtyAllocated = 0

   IF EXISTS(SELECT 1 FROM OrderDetail (NOLOCK) WHERE orderkey = @c_orderkey 
             and   orderlinenumber = @c_orderline
          	 and   ( QtyAllocated <> @n_QtyAllocated OR QtyPicked <> @n_QtyPicked ))
   BEGIN
      BEGIN TRAN 

   	UPDATE OrderDetail with (ROWLOCK)        -- tlting 2009/4/8 
   		SET QtyPicked = @n_QtyPicked, QtyAllocated = @n_QtyAllocated, TrafficCop=NULL
            ,EditDate  = GETDATE()   -- KHLim01
   	WHERE orderkey = @c_orderkey 
      and   orderlinenumber = @c_orderline
   	and   ( QtyAllocated <> @n_QtyAllocated OR QtyPicked <> @n_QtyPicked )

      IF @@ERROR = 0 
      BEGIN
         COMMIT TRAN 
      END 
   END

END

GO