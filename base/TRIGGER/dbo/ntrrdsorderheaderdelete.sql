SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


-- =============================================
-- Author:		Shong
-- Create date: 31-Mar-2008x
-- Description: Delete Details if Header was deleted
/*  9-Jun-2011  KHLim01    1.1   Insert Delete log                      */
/* 14-Jul-2011  KHLim02    1.2   GetRight for Delete log                */
-- =============================================
CREATE TRIGGER [dbo].[ntrRDSOrderHeaderDelete]
   ON  [dbo].[rdsORDERS]
   AFTER DELETE
AS 
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
	SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt int, 
           @n_Continue  int, 
           @b_success   int,
           @n_Err       int, 
           @c_ErrMsg    NVARCHAR(215) 
         , @n_cnt       int      -- KHLim01
         , @c_authority NVARCHAR(1)  -- KHLim02

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.

   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1  

   IF EXISTS(SELECT 1 FROM ORDERS (NOLOCK) 
             JOIN DELETED ON DELETED.OrderKey = ORDERS.OrderKey 
             LEFT OUTER JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey 
             WHERE ( ORDERS.Status BETWEEN '1' AND '9' OR LOADPLANDETAIL.OrderKey IS NOT NULL ) )
   BEGIN
      SET @n_Continue = 3
      SET @b_success = -1
      SET @c_ErrMsg = 'No Delete is allow, Pick Ticket Work in Progress'
      GOTO QUIT
   END 
   ELSE
   BEGIN
      UPDATE ORDERS 
         SET Status = 'CANC', TrafficCop = NULL
      FROM ORDERS  
      JOIN DELETED ON DELETED.OrderKey = ORDERS.OrderKey 
      SET @n_Err = @@ERROR
      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'Update ORDERS Failed'
         GOTO QUIT
      END      
      
   END 

   IF EXISTS(SELECT 1 FROM rdsOrderDetail WITH (NOLOCK) 
             JOIN DELETED ON DELETED.rdsOrderNo = rdsOrderDetail.rdsOrderNo)
   BEGIN
      DELETE rdsOrderDetailSize 
      FROM   rdsOrderDetailSize 
      JOIN DELETED ON DELETED.rdsOrderNo = rdsOrderDetailSize.rdsOrderNo
      SET @n_Err = @@ERROR
      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'Delete rdsOrderDetailSize Failed!'
         GOTO QUIT
      END      

      DELETE rdsOrderDetail 
      FROM rdsOrderDetail 
      JOIN DELETED ON DELETED.rdsOrderNo = rdsOrderDetail.rdsOrderNo
      SET @n_Err = @@ERROR
      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'Delete rdsOrderDetailSize Failed!'
         GOTO QUIT
      END         
   END 

   IF (SELECT count(*) FROM DELETED) =
      (SELECT count(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')  --KH01
   BEGIN
      SELECT @n_continue = 4
   END
      
   -- Start (KHLim01)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrRDSOrderHeaderDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.RDSOrders_DELLOG ( rdsOrderNo )
         SELECT rdsOrderNo  FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrRDSOrderHeaderDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01)

QUIT:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddMove'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   

END

GO