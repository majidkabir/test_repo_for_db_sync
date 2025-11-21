SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Ship_ULP_Order											*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 3.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                  		*/
/* 19.Aug.2005  June			SOS39595 - IDSPH ULP v54 bug fixed				*/
/* 22.Aug.2005	 June			SQL2K upgrade											*/
/* 15-Nov-2006	 June			SOS39706 - IDSPH ULP v54 bug fixed.			   */
/*								  (Original fixed at 22-Aug-2005. Conso version	*/
/*									from PVCS at 15-Nov-2006)							*/
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_Ship_ULP_Order] 
	@c_MBOLKey        NVARCHAR(10),
   @c_OrderKey       NVARCHAR(10), 
   @c_RealTmShip     NVARCHAR(1), 
   @b_Success	      int = 1        OUTPUT, 
   @n_err				int = 0        OUTPUT,
   @c_errmsg		 NVARCHAR(255) = '' OUTPUT   
AS
BEGIN -- main
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE @c_Short          NVARCHAR(10), 
           @c_ExternOrderKey NVARCHAR(50),   --tlting_ext
           @n_cnt            int, 
           @n_continue       int,
           @c_LastLoad       NVARCHAR(1), 
           @n_starttcnt      int, 
			  @c_Loadkey 		  NVARCHAR(10)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT  


   -- Create Temp Table for Updating
   SELECT ORDERDETAIL.MBOLKEY, ORDERDETAIL.LoadKey, 
          ORDERDETAIL.OrderKey, ORDERDETAIL.OrderLineNumber, 
          ORDERDETAIL.ExternOrderKey  
   INTO   #OrderRef 
   FROM   ORDERDETAIL (NOLOCK) 
   JOIN   MBOLDETAIL (NOLOCK) ON (MBOLDETAIL.MBOLKEY  = ORDERDETAIL.MBOLKEY AND
                                  MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey AND
                                  MBOLDETAIL.Loadkey = ORDERDETAIL.Loadkey)
   WHERE ORDERDETAIL.MBOLKey = @c_MBOLKey
   AND   ORDERDETAIL.OrderKey = @c_OrderKey 

	SELECT @c_Short = ISNULL(dbo.fnc_RTrim(c.SHORT), '0'), 
          @c_ExternOrderKey = ExternOrderKey 
	FROM ORDERS O (NOLOCK) 
   JOIN CODELKUP c (NOLOCK) on o.type = c.code and c.listname = 'ORDERTYPE'
	WHERE OrderKey = @c_OrderKey

   -- Clean all the tran_count
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN 
   END


	IF @c_Short = '0'                                          
	BEGIN 
		-- Stock Issuance 
		EXEC dbo.ispGenTransmitLog 'ISSUANCE', @c_mbolkey, '', @c_OrderKey, ''
			, @b_success OUTPUT
			, @n_err OUTPUT
			, @c_errmsg OUTPUT
					
		-- Start - SOS20494    
      IF @b_success = 1
      BEGIN  
			BEGIN TRAN 
			
			UPDATE OrderDetail
			SET  	trafficcop = null,
					EditDate = GetDate(),
					EditWho  = sUser_sName(), 
					status = '9'
			FROM  #OrderRef 
			WHERE OrderDetail.OrderKey = #OrderRef.OrderKey 
			AND   OrderDetail.OrderLineNumber = #OrderRef.OrderLineNumber      
			AND   OrderDetail.Status < '9'
	--		AND   OrderDetail.externorderkey = @c_externorderkey
		   AND   OrderDetail.Orderkey = @c_Orderkey
			
			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
			   ROLLBACK TRAN 
			END
			ELSE
			BEGIN
			  WHILE @@TRANCOUNT > 0
			  BEGIN
			     COMMIT TRAN 
			  END
			END 
		END
	
      IF @n_continue = 1 or @n_continue = 2
  		BEGIN	
			IF NOT EXISTS (SELECT 1 FROM orderdetail (nolock) 
										WHERE orderdetail.Orderkey = @c_Orderkey
										AND   orderdetail.status < '9')
			BEGIN                    							
				BEGIN TRAN                
                           
	   		UPDATE ORDERS
	   		SET   Trafficcop = null,
	   			   EditDate = GetDate(),
					   EditWho  = sUser_sName(), 
			   	   Status = '9', 
			   	   SoStatus = '9'
			   FROM  #OrderRef 
				WHERE ORDERS.OrderKey = #OrderRef.OrderKey 					
			-- AND   ORDERS.externOrderKey = @c_ExternOrderKey				
			   AND   ORDERS.Orderkey = @c_Orderkey
				AND   Status < '9'
	   		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	   		IF @n_err <> 0
	   		BEGIN
	   			SELECT @n_continue = 3
	   			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	   			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	   	      ROLLBACK TRAN 
	   		END
	      	ELSE
			  	BEGIN
			      WHILE @@TRANCOUNT > 0
			      BEGIN
			         COMMIT TRAN 
			      END
    			END 
		  END -- OrderDetail.Status < '9'
		END -- @n_continue = 1 or @n_continue = 2

		/*
      IF @n_continue = 1 or @n_continue = 2
		BEGIN	
	      BEGIN TRAN 
   						
			UPDATE PickDetail
			SET   ShipFlag = 'Y',
					EditDate = GetDate(),
			 		EditWho  = sUser_sName(), 
			   	TrafficCop = NULL
			FROM  PickDetail  (NOLOCK) 								
			JOIN  #OrderRef ON PickDetail.OrderKey = #OrderRef.OrderKey AND 
               				 PickDetail.OrderLineNumber = #OrderRef.OrderLineNumber                                                                     
			WHERE #OrderRef.ExternOrderkey = @c_externorderkey
			AND   PickDetail.Status < '9'                 
			AND   PickDetail.ShipFlag <> 'Y' 			

   		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   		IF @n_err <> 0
   		BEGIN
   			SELECT @n_continue = 3
   			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            ROLLBACK TRAN 
   		END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN 
            END
         END 
	   END -- @n_continue = 1
		*/
	END -- @c_Short = '0'
	ELSE IF @c_Short = '1' -- Normal Sales Order
	BEGIN
		IF @n_continue = 1 OR @N_continue = 2
		BEGIN
			IF EXISTS (SELECT 1 FROM MBOL (NOLOCK), MBOLDetail (NOLOCK), ORDERDETAIL (NOLOCK)
                 WHERE MBOL.Mbolkey = MBOLDetail.Mbolkey
                 AND   MBOLDetail.Orderkey = ORDERDETAIL.Orderkey
                 AND   MBOLDetail.Mbolkey  = ORDERDETAIL.Mbolkey
                 AND   ORDERDETAIL.ExternOrderkey = @c_externorderkey
                 AND   MBOL.Status <> '9'
					  AND   MBOL.Mbolkey <> @c_Mbolkey)                      
		   BEGIN
					SELECT @c_LastLoad = 'N'
	      END
			ELSE
			BEGIN
				IF EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK)
						      WHERE ExternOrderKey = @c_ExternOrderKey
						      AND (dbo.fnc_RTrim(Mbolkey) = '' OR dbo.fnc_RTrim(MBOLKey) is null) 
						      AND qtyallocated+qtypicked+shippedqty > 0)						                                    
					SELECT @c_LastLoad = 'N'   
				ELSE
				BEGIN -- 1
					SELECT @c_LastLoad = 'Y'   

	            BEGIN TRAN 

				   UPDATE ORDERS
					SET   trafficcop = null,
							EditDate = GetDate(),
	            		EditWho  = sUser_sName(), 
							Status = '9', 
							SoStatus = '9'
					WHERE externOrderKey = @c_ExternOrderKey
					AND   Status < '9' 				
								
					SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
					IF @n_err <> 0
					BEGIN
						SELECT @n_continue = 3
						SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
						SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
						ROLLBACK TRAN 
					END
					ELSE
					BEGIN
					  WHILE @@TRANCOUNT > 0
					  BEGIN
					     COMMIT TRAN 
					  END
					END 
	
					IF @n_continue = 1 OR @N_continue = 2
					BEGIN -- 2
		            BEGIN TRAN 

				      UPDATE ORDERDETAIL
				      SET   Trafficcop = null,
				      	 	EditDate = GetDate(),
		                  EditWho  = sUser_sName(), 
				            Status = '9'
				      WHERE externOrderKey = @c_ExternOrderKey
				      AND   Status < '9' 				      

				      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				      IF @n_err <> 0
				      BEGIN
				         SELECT @n_continue = 3
				         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	                  ROLLBACK TRAN 
   	       		END
						ELSE
						BEGIN
						  WHILE @@TRANCOUNT > 0
						  BEGIN
						     COMMIT TRAN 
						  END
						END            
					END                        

					/*	      
			      IF @n_continue = 1 OR @N_continue = 2
			      BEGIN -- 4        
						BEGIN TRAN 

			         UPDATE PICKDETAIL
			         SET ShipFlag = 'Y',
			             EditDate = GetDate(),
			             EditWho  = sUser_sName(),                              
			             TrafficCop = NULL
			         FROM PICKDETAIL  (NOLOCK) 
			         JOIN  #OrderRef (NOLOCK) ON PICKDETAIL.OrderKey = #OrderRef.OrderKey AND  
		                                       PICKDETAIL.OrderLineNumber = #OrderRef.OrderLineNumber
			         WHERE #OrderRef.externOrderKey = @c_ExternOrderKey
			         AND   PICKDETAIL.Status < '9'
			         AND   PickDetail.ShipFlag <> 'Y'			         
                                       
			         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			         IF @n_err <> 0
			         BEGIN
			            SELECT @n_continue = 3
			            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		                 ROLLBACK TRAN 
		        		END
						ELSE
						BEGIN
						  WHILE @@TRANCOUNT > 0
						  BEGIN
						     COMMIT TRAN 
						  END
						END      
			      END -- 4                                  
					*/
				END -- 2
			END -- 1      
		
			/*
			IF @n_continue = 1 OR @N_continue = 2
			BEGIN 
				IF @c_LastLoad = 'N'
				BEGIN               
					UPDATE PICKDETAIL
					SET ShipFlag = 'Y',
					 		EditDate = GetDate(),
							EditWho  = sUser_sName(), 
							TrafficCop = NULL
					FROM PICKDETAIL  (NOLOCK) 
					JOIN #OrderRef (NOLOCK) ON PICKDETAIL.OrderKey = #OrderRef.OrderKey AND  
					                           PICKDETAIL.OrderLineNumber = #OrderRef.OrderLineNumber                                      
					-- WHERE PICKDETAIL.OrderKey = @c_OrderKey
		         WHERE #OrderRef.externOrderKey = @c_ExternOrderKey
					AND   PICKDETAIL.Status < '9'
					AND   PICKDETAIL.ShipFlag <> 'Y'
					
				  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				  IF @n_err <> 0
				  BEGIN
				     SELECT @n_continue = 3
				     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
				     ROLLBACK TRAN 
				  END
				  ELSE
				  BEGIN
				     WHILE @@TRANCOUNT > 0
				     BEGIN
				        COMMIT TRAN 
				     END
				  END    
				END -- @c_lastLoad                       
			END
			*/

			IF @n_continue = 1 OR @N_continue = 2
			BEGIN 
				SELECT @b_success = 1
				
				EXEC dbo.ispGenTransmitLog 'ULPMBOL', @c_mbolkey, @c_LastLoad, @c_OrderKey, ''
				, @b_success OUTPUT
				, @n_err OUTPUT
				, @c_errmsg OUTPUT
			END -- @n_continue   
		END -- Continue = 1
	END -- Normal Sales Order              
	

	IF @n_continue = 1 OR @N_continue = 2
	BEGIN 
		BEGIN TRAN 

      UPDATE PICKDETAIL
	      SET ShipFlag = 'Y',
	          EditDate = GetDate(),
	          EditWho  = sUser_sName(),                              
	          TrafficCop = NULL
      FROM PICKDETAIL  (NOLOCK) 
      JOIN  #OrderRef (NOLOCK) ON PICKDETAIL.OrderKey = #OrderRef.OrderKey AND  
                                 PICKDETAIL.OrderLineNumber = #OrderRef.OrderLineNumber
      WHERE #OrderRef.externOrderKey = @c_ExternOrderKey
      AND   PICKDETAIL.Status < '9'
      AND   PickDetail.ShipFlag <> 'Y'			         
                           
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Ship_ULP_Order)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
           ROLLBACK TRAN 
  		END
		ELSE
		BEGIN
		  WHILE @@TRANCOUNT > 0
		  BEGIN
		     COMMIT TRAN 
		  END
		END      
	END 

	IF @n_continue = 1 OR @N_continue = 2
	BEGIN 
		IF EXISTS(SELECT 1 FROM LOADPLANDETAIL (nolock)
                 WHERE LOADPLANDETAIL.Orderkey = @c_OrderKey 
                 AND   LOADPLANDETAIL.Status < '9')
      BEGIN
          UPDATE LOADPLANDETAIL
             SET STATUS = '9', 
					  EditDate = GetDate(),
	              EditWho  = sUser_sName(), 
                 Trafficcop = null
          FROM  LOADPLANDETAIL
          JOIN  #OrderRef ON #OrderRef.Orderkey = LOADPLANDETAIL.Orderkey 
					 			 AND #OrderRef.Loadkey = LOADPLANDETAIL.Loadkey
          WHERE LOADPLANDETAIL.Orderkey = @c_OrderKey 
			 AND   #OrderRef.Mbolkey = @c_Mbolkey
          AND   LOADPLANDETAIL.Status < '9'

          SELECT @n_err = @@ERROR
          SELECT @n_cnt = @@ROWCOUNT
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrMBOLHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
          END
      END         
	
		IF @n_continue = 1 OR @N_continue = 2
		BEGIN 
			SELECT @c_Loadkey = Loadkey	
			FROM   #OrderRef 
			WHERE  Orderkey = @c_OrderKey
			AND 	 Mbolkey  = @c_Mbolkey	
	
			IF NOT EXISTS (SELECT 1 FROM LOADPLANDETAIL (NOLOCK) WHERE Loadkey = @c_Loadkey AND Status < '9')
			BEGIN
				UPDATE LoadPlan
				SET 	 Status = '9',
						 EditDate = GetDate(),
					    EditWho  = sUser_sName(), 
					    TrafficCop = NULL
				WHERE  Loadkey = @c_Loadkey
				AND    LoadPlan.Status < '9'
			
				SELECT @n_err = @@ERROR
				SELECT @n_cnt = @@ROWCOUNT
				IF @n_err <> 0
				BEGIN
				 SELECT @n_continue = 3
				 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrMBOLHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
				END
				ELSE
				BEGIN
				   WHILE @@TRANCOUNT > 0
				   BEGIN
				      COMMIT TRAN 
				   END
				END 
			END
		END
   END

	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
		execute dbo.nsp_logerror @n_err, @c_errmsg, 'isp_Ship_ULP_Order'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		WHILE @@TRANCOUNT > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END -- procedure

GO