SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispReleaseToTMS                          				*/
/* Creation Date: 02-July-2007                                          */
/* Copyright: IDS                                                       */
/* Written by: June	                                                	*/
/*                                                                      */
/* Purpose: Get candidate Order records with empty Loadkey					*/
/*	     	   To update ORDERS.RoutingTool = 'Y' for allocated Orders    	*/
/*          Insertion of TMSLog record handled in ntrOrderHeaderUpdate	*/
/*                                                                      */
/* Input Parameters:  @c_WaveKey      - WaveKey		        					*/
/*                                                                      */
/* Output Parameters: @b_Success      - Success Flag  = 0               */
/*                    @n_err          - Error Code    = 0               */
/*                    @c_errmsg       - Error Message = ''              */
/*                                                                      */
/* Usage:  To trigger records for TMS outbound interfaces.              */
/*                                                                      */
/* Called By:  PB object - w_wave_maintenance                         	*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[ispReleaseToTMS]  
            @c_Wavekey  NVARCHAR(10) , 
            @b_Success 	int OUTPUT , 
            @n_err 		int OUTPUT , 
            @c_errmsg  NVARCHAR(225) OUTPUT 
AS
BEGIN
	SET CONCAT_NULL_YIELDS_NULL OFF
	SET QUOTED_IDENTIFIER OFF
	SET NOCOUNT ON	

	DECLARE @n_continue int
	,@n_starttcnt int  -- Holds the current transaction count
	,@c_storerkey NVARCHAR(15)
	,@c_orderkey  NVARCHAR(10)
	,@c_Loadkey  NVARCHAR(10)
	,@c_TMSOutOrdHDR NVARCHAR(1)
	,@c_TMSOutOrdDTL NVARCHAR(1)
	,@c_TMSOutOrdHDRAlloc NVARCHAR(1)
	,@n_qtyalloc int
	,@b_debug int 	

	SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='' 
	SELECT @b_debug = 0
	
	IF @n_continue=1 OR @n_continue=2
	BEGIN
		BEGIN TRAN 

   	DECLARE TMS_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ORDERS.Storerkey, WAVEDETAIL.Orderkey, ORDERS.Loadkey, SUM(ORDERDETAIL.Qtyallocated + ORDERDETAIL.QtyPicked)
         FROM   WAVEDETAIL WITH (NOLOCK)
			JOIN   ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.Orderkey = WAVEDETAIL.Orderkey 
			JOIN   ORDERS WITH (NOLOCK) ON ORDERDETAIL.Orderkey = ORDERS.Orderkey AND ORDERS.Userdefine09 = WAVEDETAIL.Wavekey
			WHERE  WAVEDETAIL.Wavekey = @c_wavekey
			GROUP BY ORDERS.Storerkey, WAVEDETAIL.Orderkey, ORDERS.Loadkey 
			ORDER BY ORDERS.Storerkey, WAVEDETAIL.Orderkey 

   	OPEN TMS_CUR
  
   	FETCH NEXT FROM TMS_CUR INTO @c_storerkey, @c_Orderkey, @c_Loadkey, @n_qtyalloc

   	WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)
   	BEGIN
			IF @b_debug = 1
			BEGIN
				PRINT 'Order# ' + @c_OrderKey
			END 

			IF @c_Loadkey > '' 
			BEGIN
				SET @n_continue = 3
				SELECT @n_err = 69000
				SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Loadkey is not Empty (ispReleaseToTMS)'  
				BREAK
			END	

			IF @n_qtyalloc = 0 OR @n_qtyalloc IS NULL
			BEGIN
				SELECT @n_continue = 3
				SELECT @n_err = 69001
				SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Order Not allocated (ispReleaseToTMS)'  
				BREAK
			END

			SELECT @b_success = 0
			EXECUTE dbo.nspGetRight '', -- facility	
						@c_storerkey,  	-- Storerkey
						NULL,          	-- Sku
						'TMSOutOrdHDR',	-- Configkey
						@b_success    		output,
						@c_TMSOutOrdHDR   output, 
						@n_err        		output,
						@c_errmsg     	   output

			SELECT @b_success = 0
			EXECUTE dbo.nspGetRight '', -- facility	
						@c_storerkey,  	-- Storerkey
						NULL,          	-- Sku
						'TMSOutOrdDTL',	-- Configkey
						@b_success    		output,
						@c_TMSOutOrdDTL   output, 
						@n_err        		output,
						@c_errmsg     	   output
			
			SELECT @b_success = 0
			EXECUTE dbo.nspGetRight '', 		-- facility	
						@c_storerkey,  			-- Storerkey
						NULL,          			-- Sku
						'TMSOutOrdHDRAlloc',		-- Configkey
						@b_success    				output,
						@c_TMSOutOrdHDRAlloc   	output, 
						@n_err        				output,
						@c_errmsg     	   		output

			IF @b_success <> 1
			BEGIN
				SELECT @n_continue = 3
				SELECT @c_errmsg = 'ispReleaseToTMS' + RTRIM(@c_errmsg)
			END
			ELSE 
			BEGIN
				IF @c_TMSOutOrdHDR = '1' OR @c_TMSOutOrdDTL = '1' OR @c_TMSOutOrdHDRAlloc = '1'
				BEGIN							
					IF @b_debug = 1
					BEGIN
						PRINT 'UPDATING RoutingTool to ''Y'' - Order# ' + @c_OrderKey
					END 

					-- Update ORDERS.RoutingTool = 'Y' 
					UPDATE ORDERS
					SET 	 RoutingTool = 'Y'
					WHERE  ORDERS.OrderKey = @c_OrderKey 				
					IF @@ERROR <> 0
					BEGIN
						SELECT @n_continue = 3
						SELECT @n_err = 69002
						SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update records failed (ispReleaseToTMS)'  
					END					
				END -- @c_TMSOutOrdHDR = '1' OR @c_TMSOutOrdDTL = '1' OR @c_TMSOutOrdHDRAlloc = '1'
				ELSE
				BEGIN
					SELECT @n_continue = 3
					SELECT @n_err = 69003
					SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': StorerConfig ''TMSOutOrdHDR'' or ''TMSOutOrdDTL'' or ''TMSOutOrdHDRAlloc'' not enabled (ispReleaseToTMS)'  		
				END
			END			

		 	FETCH NEXT FROM TMS_CUR INTO @c_storerkey, @c_Orderkey, @c_Loadkey, @n_qtyalloc
		END 
		CLOSE TMS_CUR
		DEALLOCATE TMS_CUR


		/* #INCLUDE <SPIAD2.SQL> */
		IF @n_continue=3  -- Error Occured - Process And Return
		BEGIN
		 SELECT @b_success = 0
		 ROLLBACK TRAN
		 EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ispReleaseToTMS'
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
	END -- IF @n_continue=1 OR @n_continue=2
END -- procedure

GO