SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure isp_Scanning : 
--

/************************************************************************/
/* Stored Procedure: isp_Scanning                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Replace isp_Scanning Trigger, use Stored Proc					*/
/*			   to improve performance.													*/
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/*                                                                      */ 
/************************************************************************/

CREATE PROC [dbo].[isp_Scanning] 
       @c_PickSlipNo    NVARCHAR(10),
	    @b_ReturnCode	   int = 0        OUTPUT, -- 0 = OK, -1 = Error, 1 = Warning 
       @n_err				int = 0        OUTPUT,
       @c_errmsg		 NVARCHAR(255) = '' OUTPUT   
AS
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 

	DECLARE  @n_continue 	int
	, @n_starttcnt 			int
	, @b_Success   			int       
	, @n_err2       			int       
   , @n_cnt        			int                    
   , @c_rfbatchpickenabled NVARCHAR(1)
   , @c_OrderKey           NVARCHAR(10)
   , @c_tablename          NVARCHAR(15)
   , @c_OrderLineNumber    NVARCHAR(5)
   , @c_TransmitLogKey     NVARCHAR(10)
   , @c_storerkey 		 NVARCHAR(15)
   , @c_authority 		 NVARCHAR(1)  
	, @b_debug         		int 
	, @c_PickDetailKey 	 NVARCHAR(18)
	, @c_loadkey       	 NVARCHAR(10)
	, @c_PickOrderKey  	 NVARCHAR(10)
	, @c_WaveKey       	 NVARCHAR(10)    
	, @n_RF_BatchPicking  	int
	, @c_TicketType       NVARCHAR(10)
	, @c_NextOrderKey      NVARCHAR(10)
	, @c_loritf 			 NVARCHAR(1) 


	SELECT @b_debug = 0
	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   -- (June01) - Start
   -- TraceInfo
   DECLARE    @c_starttime    datetime,
              @c_endtime      datetime,
              @c_step1        datetime,
              @c_step2        datetime,
              @c_step3        datetime,
              @c_step4        datetime,
              @c_step5        datetime   
   SET @c_starttime = getdate()
   -- (June01) - End

   BEGIN TRAN 

   IF EXISTS( SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE CONFIGKEY = 'RF_BATCH_PICK' AND NSQLVALUE = '1') 
      SELECT @n_RF_BatchPicking = 1
   ELSE
      SELECT @n_RF_BatchPicking = 0     

   IF @n_continue = 1 or @n_continue=2 
   BEGIN
      DECLARE C_PkngInfoPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PICKHEADER.ZONE,
                PICKHEADER.ExternOrderKey,
                ISNULL(PICKHEADER.OrderKey, '')
         FROM   PICKINGINFO (NOLOCK)
         JOIN   PICKHEADER (NOLOCK) ON PickHeaderKey = PICKINGINFO.PickSlipNo
         WHERE  PICKINGINFO.ScanOutDate IS NOT NULL 
			AND    PICKINGINFO.PickSlipNo = @c_PickSlipNo
         ORDER BY PICKINGINFO.PickSlipNo, PICKHEADER.ExternOrderKey, ISNULL(PICKHEADER.OrderKey, '')

      OPEN C_PkngInfoPickSlip  

      WHILE 1=1 
      BEGIN
         FETCH NEXT FROM C_PkngInfoPickSlip INTO @c_TicketType, @c_LoadKey, @c_OrderKey

         IF @@FETCH_STATUS = -1 
            BREAK

         IF @b_debug = 1
         BEGIN
            Print 'Loop 1 - Picking Info, PickSlip No = ' + dbo.fnc_RTRIM(@c_PickSlipNo)
         END 

         IF @c_TicketType <> 'XD' AND @c_TicketType <> 'LB' 
         AND @c_TicketType <> 'LP' 
         BEGIN
            IF dbo.fnc_RTRIM(@c_OrderKey) IS NULL OR dbo.fnc_RTRIM(@c_OrderKey) = '' 
            BEGIN 
               -- Conso PickSlip - Loop for Order 
               SELECT @c_NextOrderKey = SPACE(10) 

               DECLARE C_PkngInfonNxtOrdKy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT LOADPLANDETAIL.OrderKey, ORDERS.StorerKey
                  FROM   LOADPLANDETAIL (NOLOCK)
                  JOIN   ORDERS (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
                  WHERE  LOADPLANDETAIL.LoadKey = @c_LoadKey 
                  ORDER BY LOADPLANDETAIL.OrderKey
            END
            ELSE
            BEGIN 
               DECLARE C_PkngInfonNxtOrdKy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
                  SELECT ORDERS.OrderKey, ORDERS.StorerKey 
                  FROM   ORDERS (NOLOCK) 
                  WHERE  ORDERS.OrderKey = @c_OrderKey 
                  ORDER BY ORDERS.OrderKey 
            END 

            SET @c_step1 = GETDATE()                        
            OPEN C_PkngInfonNxtOrdKy 

            WHILE 1=1 
            BEGIN
               FETCH NEXT FROM C_PkngInfonNxtOrdKy INTO @c_NextOrderKey, @c_StorerKey

               IF @@FETCH_STATUS = -1 
                  BREAK 

               IF @b_debug = 1
               BEGIN
                  Print 'Loop 2 - Loadplan Detail, OrderKey = ' + dbo.fnc_RTRIM(@c_NextOrderKey)
               END 

               BEGIN TRAN UpdatePickDetail    
   
               SET @c_step3 = GETDATE()
                 
               IF dbo.fnc_RTRIM(@c_LoadKey) IS NOT NULL AND dbo.fnc_RTRIM(@c_LoadKey) <> ''
               BEGIN
                  IF @n_RF_BatchPicking = 1 and @c_TicketType = '9'
                  BEGIN
                     IF EXISTS(SELECT 1 FROM PickingInfo (NOLOCK) 
										 WHERE  ScanOutDate IS NOT NULL
										 AND    PickSlipno = @c_PickSlipNo
										 AND    ScanOutDate < GetDate())
                     BEGIN
                        EXEC dbo.ispPickConfirmCheck @c_LoadKey 
                     END 
   
                     UPDATE PICKDETAIL SET STATUS = '5'
                     FROM  PICKDETAIL 
                     JOIN  ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND
                                                    ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)  
                     WHERE PICKDETAIL.OrderKey = @c_NextOrderKey  
                     AND   (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '') 
                     AND   PICKDETAIL.Status < '5' 
                     AND   ORDERDETAIL.LoadKey = @c_LoadKey 

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                  END
                  ELSE
                  BEGIN
                     IF EXISTS(SELECT 1 FROM PickingInfo (NOLOCK) 
										 WHERE  ScanOutDate IS NOT NULL
										 AND    PickSlipno = @c_PickSlipNo
										 AND    ScanOutDate < GetDate())
                     BEGIN
                        EXEC dbo.ispPickConfirmCheck @c_LoadKey
                     END 

                     UPDATE PICKDETAIL SET STATUS = '5'  
                     FROM  PICKDETAIL WITH (INDEX (PICKDETAIL10) ) 
                     JOIN  ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND
                                                    ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)  
                     WHERE PICKDETAIL.OrderKey = @c_NextOrderKey  
                     AND   PICKDETAIL.Status < '5' 
                     AND   ORDERDETAIL.LoadKey = @c_LoadKey 

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                  END
               END
               ELSE
               BEGIN
                  IF @n_RF_BatchPicking = 1 and @c_TicketType = '9'
                  BEGIN
                     IF EXISTS(SELECT 1 FROM PickingInfo (NOLOCK) 
										 WHERE  ScanOutDate IS NOT NULL
										 AND    PickSlipno = @c_PickSlipNo
										 AND    ScanOutDate < GetDate())
                     BEGIN
                        EXEC dbo.ispPickConfirmCheck @c_LoadKey, @c_NextOrderKey                        
                     END 

                     UPDATE PICKDETAIL SET STATUS = '5'
                     FROM  PICKDETAIL 
                     WHERE PICKDETAIL.OrderKey = @c_NextOrderKey  
                     AND   (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '') 
                     AND   PICKDETAIL.Status < '5' 

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                  END
                  ELSE
                  BEGIN
                     IF EXISTS(SELECT 1 FROM PickingInfo (NOLOCK) 
										 WHERE  ScanOutDate IS NOT NULL
										 AND    PickSlipno = @c_PickSlipNo
										 AND    ScanOutDate < GetDate())
                     BEGIN
                        EXEC dbo.ispPickConfirmCheck @c_LoadKey, @c_NextOrderKey
                     END 

                     UPDATE PICKDETAIL SET STATUS = '5'  
                     FROM  PICKDETAIL 
                     WHERE PICKDETAIL.OrderKey = @c_NextOrderKey  
                     AND   PICKDETAIL.Status < '5' 

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                      
                  END
               END

               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @n_err = 61781 
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Scanning)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                  GOTO EXIT_SP
               END              
               ELSE
               BEGIN
                  COMMIT TRAN UpdatePickDetail 
               END  

               SET @c_step3 = GETDATE() - @c_step3   
               
               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN             
                  IF EXISTS(SELECT 1 FROM PickDetail (NOLOCK) WHERE OrderKey = @c_NextOrderKey) AND
                     NOT EXISTS(SELECT 1 FROM PickDetail (NOLOCK) WHERE OrderKey = @c_NextOrderKey AND Status < '5')
                  BEGIN
                     UPDATE ORDERS 
                        SET Status = '5', 
                            EditDate = GetDate(),
                            EditWho  = sUser_sName(), 
                            TrafficCop = NULL 
                     WHERE  OrderKey = @c_NextOrderKey
                     AND    Status < '5'
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61782 
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (isp_Scanning)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                        GOTO EXIT_SP
                     END              
                  END
               END

               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN             
                  IF EXISTS( SELECT OrderKey FROM ORDERDETAIL (NOLOCK)
                             WHERE  OrderKey = @c_NextOrderKey
                             AND    Status < '5')
                  BEGIN
                     -- cater for split orders in loadplan
                     UPDATE OrderDetail 
                        SET Status = '5',
                            EditDate = GetDate(),
                            EditWho  = sUser_sName(),  
                            TrafficCop = NULL 
                     WHERE  OrderKey = @c_NextOrderKey
                     AND    Loadkey = @c_LoadKey
                     AND    Status < '5'
   
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61783 
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERDETAIL. (isp_Scanning)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                        GOTO EXIT_SP
                     END               
                  END 
               END 

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_loadkey)) <> '' OR dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_loadkey)) IS NOT NULL  
                  BEGIN 
                     IF EXISTS( SELECT 1 FROM LOADPLANDETAIL (NOLOCK) WHERE Loadkey = @c_loadkey 
                                AND OrderKey = @c_NextOrderKey 
                                AND STATUS < '5' )
                     BEGIN 
                        UPDATE LOADPLANDETAIL  
                           SET STATUS = '5', EditDate = GetDate(),
                               EditWho   = sUser_sName(), trafficcop = null  
                        WHERE Loadkey = @c_loadkey 
                          and OrderKey = @c_NextOrderKey 
                          AND STATUS < '5'
                        
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                        IF @n_err <> 0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61784 
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLANDETAIL. (isp_Scanning)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                           GOTO EXIT_SP
                        END 
                     END 
                  END 
               END  
                                 
               IF @c_TicketType = '8' OR @c_TicketType = '7'             
               OR @c_TicketType = '9' 
               BEGIN
                  IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE Storerkey = @c_StorerKey
                                         AND Configkey = 'ULVITF' AND SVALUE = '1')
                  BEGIN
                     IF NOT EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) 
                                 WHERE StorerKey = @c_StorerKey AND Configkey = 'ULVPODITF' AND SValue = '1' )
                     BEGIN
                        SELECT @c_tablename = CASE TYPE WHEN 'WT' THEN 'ULVNSO'
                                                        WHEN 'W'  THEN 'ULVHOL'
                                                        WHEN 'WC' THEN 'ULVINVTRF'  
                                                        WHEN 'WD' THEN 'ULVDAMWD'   
                                                        ELSE 'ULVPCF'     
                                              END
                        FROM ORDERS (NOLOCK)
                        WHERE ORDERKEY = @c_NextOrderKey         
   
                        SELECT @c_OrderLineNumber = ''

                        DECLARE C_PkngInfOrdLnNr CURSOR LOCAL FAST_FORWARD READ_ONLY
                           FOR   SELECT ORDERDETAIL.Orderlinenumber
                           FROM  ORDERDETAIL (NOLOCK) 
                           WHERE Orderkey = @c_NextOrderKey
                           AND 	Status = '5' 
                           ORDER BY ORDERDETAIL.Orderlinenumber

                        OPEN C_PkngInfOrdLnNr
            
                        WHILE (1 = 1) AND (@n_continue = 1 OR @n_continue = 2)
                        BEGIN
                           FETCH NEXT FROM C_PkngInfOrdLnNr INTO @c_OrderLineNumber
             
                           IF @@FETCH_STATUS = -1 
                              BREAK
            
                           EXEC dbo.ispGenTransmitLog2  @c_Tablename, @c_NextOrderKey, @c_OrderLineNumber, @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
                       
                           IF NOT @b_success = 1
                           BEGIN
                              SELECT @n_continue=3 
                              GOTO EXIT_SP
                           END 
                        END -- While Loop Order Line  
                        CLOSE C_PkngInfOrdLnNr
                        DEALLOCATE C_PkngInfOrdLnNr                  
                     END -- ULVPODITF turn on
                  END -- if ULVITF Turn on 
               END -- IF @c_TicketType = '8' OR @c_TicketType = '7'   
                            
               IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE Storerkey = @c_StorerKey
                                         AND Configkey = 'PICKLOG' AND SVALUE = '1')
               BEGIN
                  EXEC dbo.ispGenTransmitLog 'PICK', @c_NextOrderKey, '', @c_PickSlipNo, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
   
                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3 
                     SELECT @n_err = 61785 
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (PICK) Failed (ntrOrderDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     GOTO EXIT_SP
                  END                 
               END -- Interface ConfigKey 'PICKLOG'
               
               IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE Storerkey = @c_StorerKey
                         AND Configkey = 'CDSORD' AND SVALUE = '1')
               BEGIN
                  EXEC dbo.ispGenTransmitLog 'CDSORD', @c_NextOrderKey, '', '', ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
   
                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3 
                     SELECT @n_err = 61786 
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (CDSORD) Failed (ntrOrderDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     GOTO EXIT_SP
                  END                     
               END -- Interface ConfigKey 'CDSORD'
   
               IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE Storerkey = @c_StorerKey
                                         AND Configkey = 'LORITF' AND SVALUE = '1')
               BEGIN
                  EXEC dbo.ispGenTransmitLog 'LORPICK', @c_NextOrderKey, '', '', ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
   
                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3 
                     SELECT @n_err = 61787 
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (LORPICK) Failed (ntrOrderDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     GOTO EXIT_SP
                  END                     
               END -- Interface ConfigKey 'LORITF'
            END -- While loop Order Key
            CLOSE C_PkngInfonNxtOrdKy 
            DEALLOCATE C_PkngInfonNxtOrdKy 
            
            SET @c_step1 = GETDATE() - @c_step1 

            --- End Order Key Loop ---------------------------------------------------------------------          

            SET @c_step2 = GETDATE()
            
            IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_loadkey)) <> '' OR dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_loadkey)) IS NOT NULL  
            BEGIN  
              IF NOT EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK), LOADPLANDETAIL (NOLOCK), ORDERDETAIL (NOLOCK)
                 WHERE LOADPLANDETAIL.Loadkey = ORDERDETAIL.Loadkey
                 AND   LOADPLANDETAIL.Loadkey = @c_loadkey   
                 AND   PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey                                     
                 AND   PICKDETAIL.OrderlineNumber = ORDERDETAIL.OrderlineNumber
                 AND   PICKDETAIL.Status < '5') -- no more pickdetail with status < '5'  
              BEGIN  
                  UPDATE LOADPLAN WITH (ROWLOCK)   
                     SET STATUS = '5', EditDate = GetDate(),
                            EditWho  = sUser_sName(), trafficcop = null  
                  WHERE Loadkey = @c_loadkey 
                    AND Status < '5' 
      
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT     
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61788 
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLAN. (isp_Scanning)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                     GOTO EXIT_SP
                  END             
               END -- NOT EXISTS
            END -- IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_loadkey)) <> ''

            SET @c_step2 = GETDATE() - @c_step2             
         END -- IF @c_TicketType <> 'XD' AND @c_TicketType <> 'LB'
         ELSE 
         BEGIN
            IF @c_TicketType = 'XD' OR @c_TicketType = 'LB' 
               OR @c_TicketType = 'LP' 
            BEGIN
               SELECT @c_PickDetailKey = SPACE(18)

               -- Step 2
               SET @c_step2 = GETDATE() 

               DECLARE C_PkngInfPckDtlKy CURSOR LOCAL FAST_FORWARD READ_ONLY
                  FOR  SELECT RefKeyLookup.PickDetailKey
                  FROM  RefKeyLookup (NOLOCK) 
                  WHERE PickslipNo = @c_PickSlipNo 
                  ORDER BY RefKeyLookup.PickDetailKey
         
               OPEN C_PkngInfPckDtlKy   

               WHILE (1 = 1) 
               BEGIN  
                  FETCH NEXT FROM C_PkngInfPckDtlKy INTO @c_PickDetailKey

                  IF @@FETCH_STATUS = -1 
                     BREAK
                                             
                  UPDATE PICKDETAIL WITH (ROWLOCK) 
                     SET STATUS = '5'  
                  WHERE PickDetailKey = @c_pickdetailkey  
                    AND Status < '5' 
                  
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61789 
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (isp_Scanning)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                     GOTO EXIT_SP
                  END                  
               END -- WHILE pickdetail
               CLOSE C_PkngInfPckDtlKy
               DEALLOCATE C_PkngInfPckDtlKy

               SET @c_step2 = GETDATE() - @c_step2 

               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN              
                  -- Step 3
                  SET @c_step3 = GETDATE() 

                  IF EXISTS(SELECT 1 FROM ORDERS (NOLOCK) 
                              JOIN PICKDETAIL (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)
                              WHERE PICKDETAIL.PickslipNo = @c_PickSlipNo 
                              AND   ORDERS.Status < '5' )
                  BEGIN 
                     UPDATE ORDERS 
                        SET STATUS = '5', EditDate = GetDate(),
                            EditWho  = sUser_sName(), Trafficcop = NULL
                     FROM ORDERS  
                     JOIN PICKDETAIL (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)
                     WHERE PICKDETAIL.PickslipNo = @c_PickSlipNo 
                     AND   ORDERS.Status < '5' 

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61790 
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ORDERS. (isp_Scanning)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                        GOTO EXIT_SP
                     END                  
                  END         
                  SET @c_step3 = GETDATE() - @c_step3          
               END                  
            END -- @c_TicketType = 'XD' OR @c_TicketType = 'LB'
         END
      END -- while loop picking info 
      CLOSE C_PkngInfoPickSlip
      DEALLOCATE C_PkngInfoPickSlip
   END -- @n_continue = 1 or @n_continue=2 

   EXIT_SP:
	/*
   -- To turn this on only when need to trace on the performance.
   -- insert into table, TraceInfo for tracing purpose.
     IF @n_continue = 1 or @n_continue=2 
     BEGIN 
        BEGIN TRAN
        SET @c_endtime = GETDATE()
        INSERT INTO TraceInfo VALUES
           ('isp_Scanning - PS# = ' + @c_PickSlipNo + ' Type = ' + dbo.fnc_RTRIM(@c_TicketType) 
             , @c_starttime, @c_endtime 
           ,CONVERT(CHAR(12),@c_endtime-@c_starttime ,114) 
           ,ISNULL(CONVERT(CHAR(12),@c_step1,114), '00:00:00:000') 
           ,ISNULL(CONVERT(CHAR(12),@c_step2,114), '00:00:00:000')  
           ,ISNULL(CONVERT(CHAR(12),@c_step3,114), '00:00:00:000')  
           ,ISNULL(CONVERT(CHAR(12),@c_step4,114), '00:00:00:000')  
           ,ISNULL(CONVERT(CHAR(12),@c_step5,114), '00:00:00:000') )
        COMMIT TRAN
     END 
	*/

	
	/* #INCLUDE <TRMBOHU2.SQL> */	
   /***** End Add by DLIM *****/
	IF @n_continue=3  -- Error Occured - Process AND Return
	BEGIN
		IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
		EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_Scanning'		
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
END -- main

GO