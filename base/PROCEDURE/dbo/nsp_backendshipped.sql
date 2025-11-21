SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[nsp_BackEndShipped]
   @c_StorerKey NVARCHAR(15) -- For one storer, pass in the Storerkey; For All Storer, pass in '%'
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickDetailKey   char (10),
           @c_XmitLogKey     char (10),
           @c_PickOrderLine  char (5),
           @n_Continue       int ,
           @n_cnt            int,
           @n_err            int,
           @c_ErrMsg         char (255),
           @n_RowCnt         int,
           @b_success        int,
           @c_trmlogkey      NVARCHAR(10),
           @c_MBOLKey        NVARCHAR(10),
           @d_StartTime      datetime,
           @d_EndTime        datetime,
           @c_OrderKey       NVARCHAR(10)  
   
   SELECT @n_continue=1

   IF @n_continue = 1 or @n_continue=2
   BEGIN
		IF @c_storerkey = '%' 
		begin
	      SELECT @c_MBOLKey = MIN(ORDERDETAIL.MBOLKEY)
	      FROM  ORDERDETAIL WITH (NOLOCK)
	            JOIN PICKDETAIL WITH (INDEX(PICKDETAIL_OrderDetStatus), NOLOCK)  
						ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey 
						and PICKDETAIL.Orderlinenumber = ORDERDETAIL.Orderlinenumber)
	      WHERE PICKDETAIL.Status <> '9'
	      AND   PICKDETAIL.ShipFlag = 'Y'
	      AND   ORDERDETAIL.MBOLKey > ''
		end
		else
		begin 
	      SELECT @c_MBOLKey = MIN(ORDERDETAIL.MBOLKEY)
	      FROM  ORDERDETAIL WITH (NOLOCK)
	            JOIN PICKDETAIL WITH (INDEX(PICKDETAIL_OrderDetStatus), NOLOCK)  
						ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey 
						and PICKDETAIL.Orderlinenumber = ORDERDETAIL.Orderlinenumber)
	      WHERE ORDERDETAIL.StorerKey = @c_StorerKey  
	      AND   PICKDETAIL.Status <> '9'
	      AND   PICKDETAIL.ShipFlag = 'Y'
	      AND   ORDERDETAIL.MBOLKey > ''
		end	

      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_MBOLKey)) IS NOT NULL
      BEGIN
         SELECT @c_OrderKey = SPACE(10)
         WHILE 1=1
         BEGIN
				-- SOS 8995 wally 20.dec.2002
				-- take into consideration the parameter pass in selecting orders to ship
				IF @c_storerkey = '%'
				BEGIN
	            SELECT @c_OrderKey = MIN(OrderKey)
	            FROM   ORDERDETAIL (NOLOCK)
	            WHERE  ORDERDETAIL.MBOLKEY = @c_MBOLKEY
	            AND    ORDERDETAIL.ORDERKEY > @c_OrderKey
				END
				ELSE -- specific storer
				BEGIN
					SELECT @c_OrderKey = MIN(OrderKey)
	            FROM   ORDERDETAIL (NOLOCK)
	            WHERE  ORDERDETAIL.MBOLKEY = @c_MBOLKEY
	            AND    ORDERDETAIL.ORDERKEY > @c_OrderKey
					AND	 ORDERDETAIL.storerkey = @c_storerkey
				END

            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_OrderKey)) IS NULL
               BREAK
            
            SELECT @c_PickDetailKey = SPACE(10)
            WHILE 1=1
            BEGIN
               SELECT @c_PickDetailKey = MIN(PICKDETAIL.pickdetailkey)
               FROM PICKDETAIL WITH (INDEX(PICKDETAIL10), NOLOCK)
               JOIN ORDERDETAIL WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                                                  PICKDETAIL.ORDERLINENUMBER = ORDERDETAIL.ORDERLINENUMBER )
               WHERE PICKDETAIL.PICKDETAILKEY > @c_PickDetailKey
               AND   PICKDETAIL.Status <> '9'
               AND   PICKDETAIL.ShipFlag = 'Y'
               AND   ORDERDETAIL.OrderKey = @c_OrderKey 
					AND   ORDERDETAIL.MBOLKey = @c_MBOLKEY 
   
               IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_PickDetailKey)) IS NULL
                  BREAK
              
               SELECT @d_StartTime = GetDate()

               -- Modify by SHONG on 12-Jun-2003
               -- For Performance Tuning
               IF (SELECT Qty FROM PICKDETAIL (NOLOCK) WHERE pickdetailkey = @c_PickDetailKey) > 0 
               BEGIN
                  PRINT 'Updating MBOL ' + @c_MBOLKey + ' PickDetailKey ' + @c_PickDetailKey + ' Start at ' + CONVERT(char(10), @d_StartTime, 108) 
                  BEGIN TRAN

                  UPDATE PICKDETAIL WITH (ROWLOCK) 
                     SET Status = '9'
                  WHERE pickdetailkey = @c_PickDetailKey
						SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         				ROLLBACK TRAN
                     BREAK
                  END
                  ELSE
                  BEGIN
         				COMMIT TRAN
                     PRINT 'Updated MBOL ' + @c_MBOLKey + ' PickDetailKey ' + @c_PickDetailKey + ' Start at ' + CONVERT(char(10), @d_StartTime, 108) + ' End at ' + CONVERT(char(10), Getdate(), 108)            
                  END

               END
               ELSE
               BEGIN
                  BEGIN TRAN 

                  UPDATE PICKDETAIL WITH (ROWLOCK) 
                     SET ArchiveCop = '9'
                  WHERE pickdetailkey = @c_PickDetailKey
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PICKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         				ROLLBACK TRAN
                     BREAK
                  END
                  ELSE
                  BEGIN
         				COMMIT TRAN

                     BEGIN TRAN 

                     DELETE PICKDETAIL 
                     WHERE pickdetailkey = @c_PickDetailKey            
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Failed On Table PICKDETAIL. (nsp_BackEndShipped)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            				ROLLBACK TRAN
                        BREAK
                     END
							ELSE
								COMMIT TRAN
                  END
               END 
            END -- While PickDetail Key
         END -- While Order
      END -- mbolkey not = null
   END

   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      execute nsp_logerror @n_err, @c_errmsg, "nsp_BackEndShipped"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
END


GO