SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/  
/* Trigger: ntrPickingInfoUpdate                                               */  
/* Creation Date:                                                              */  
/* Copyright: IDS                                                              */  
/* Written by:                                                                 */  
/*                                                                             */  
/* Purpose:                                                                    */  
/*                                                                             */  
/* Input Parameters:                                                           */  
/*                                                                             */  
/* Output Parameters:                                                          */  
/*                                                                             */  
/* Return Status:                                                              */  
/*                                                                             */  
/* Usage:                                                                      */  
/*                                                                             */  
/* Local Variables:                                                            */  
/*                                                                             */  
/* Called By: When records updated                                             */  
/*                                                                             */  
/* Revision: 1.3                                                               */  
/*                                                                             */  
/* Version: 5.4                                                                */  
/*                                                                             */  
/* Data Modifications:                                                         */  
/*                                                                             */  
/* Updates:                                                                    */  
/* Date         Author    Ver.   Purposes                                      */  
/* 22-Feb-2005  SHONG            Include the Patching for Qty Picked AND       */  
/*                               Qty Allocated in case update done halfway     */  
/* 22-Mar-2005  SHONG            Call ispPickConfirmCheck only when re-scan    */  
/* 29-Jun-2005  SHONG            Include TrafficCop AND Archive Cop            */  
/* 27-Mar-2006  SHONG            Performance Tuning                            */  
/* 13-Apr-2006  SHONG            Performance Tuning                            */  
/* 07-Sep-2006  MaryVong         Add in RDT compatible error messages          */  
/* 13-Nov-2007  YokeBeen         SOS#84285 - Consolidated Pick Ticket of USA.  */  
/*                               PickHeader.Zone -> Conso = 'C'                */  
/*                                               -> Discrete = 'D'             */  
/*                               - (YokeBeen03)                                */  
/* 30-Jul-2008  MCTANG    1.1    SOS#110279 - Vital Pack Confirm.              */  
/* 25-Nov-2008  KC        1.2    Incorporate SQL2005 Std - WITH (NOLOCK)       */  
/* 19-Apr-2012  Leong     1.3    SOS# 241301 - Exclude short pick record       */  
/* 28-Oct-2013  TLTING    1.4    Review Editdate column update                 */  
/* 19-Aug-2015  Shong01   1.5    Added Backend Pick Confirm                    */  
/* 21-Jun-2016  Wan01     1.6    Performance Tune                              */  
/* 22-Sep-2016  SHONG02   1.7    Backend Pack Confirm only for ECOM Orders     */
/* 23-Oct-2017  Shong     1.8    Performance Tuning (SWT02)                    */
/* 07-FEB-2018  Wan02     1.9    Bug Fixed                                     */
/* 15-JAN-2019  NJOW01    2.0    Fix - check discrete by orderkey              */
/* 02-Nov-2021  TLTING01  2.1    Deadlock tuning                               */
/*******************************************************************************/  
CREATE TRIGGER [dbo].[ntrPickingInfoUpdate]  
ON  [dbo].[PickingInfo]  
FOR UPDATE  
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

   -- Rewrote by SHONG on 16-Dec-2003  
  
   DECLARE @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err                int       -- Error number returned by stored procedure OR this trigger  
         , @n_err2               int       -- For Additional Error Detection  
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure eor this trigger  
         , @n_continue           int  
         , @n_starttcnt          NVARCHAR(250) -- preprocess  
         , @c_pstprocess         NVARCHAR(250) -- post process  
         , @n_cnt                int  
         , @c_rfbatchpickenabled NVARCHAR(1)  
         , @c_OrderKey           NVARCHAR(10)  
         , @c_tablename          NVARCHAR(15)  
         , @c_OrderLineNumber    NVARCHAR(5)  
         , @c_TransmitLogKey     NVARCHAR(10)  
         , @c_storerkey          NVARCHAR(15)  
         , @c_authority          NVARCHAR(1)  -- Add by June 1.Jul.02 for IDSV5  
  
   DECLARE @b_debug                int  
         , @c_PickDetailKey        NVARCHAR(18) -- Change by SHONG from NVARCHAR(10) to NVARCHAR(18) follow table length  
         , @c_LoadKey              NVARCHAR(10)  
         , @c_PickOrderKey         NVARCHAR(10)  
         , @c_WaveKey              NVARCHAR(10)  
  
   DECLARE @c_PickSlipNo           NVARCHAR(10)  
         , @n_RF_BatchPicking      int  
         , @c_TicketType           NVARCHAR(10)  
         , @c_NextOrderKey         NVARCHAR(10)  
         , @c_NextPickSlipNo       NVARCHAR(10)  
         , @c_loritf               NVARCHAR(1) -- Added by Vicky - IDSPH LOREAL  
         , @c_BackendPickCfm       CHAR(1) -- SHONG01   
         , @c_DocType              NVARCHAR(1)           
         , @c_PickDet_Status       NVARCHAR(10) = ''  --SWT02
         , @c_PickDet_ShpFlg       NVARCHAR(1)  = ''  --SWT02
         , @c_Status               NVARCHAR(10) = ''  --SWT02
         , @c_LoadLineNumber       NVARCHAR(5)  = ''  --SWT02         
  
   SELECT @b_debug = 0, @c_PickDetailKey = ''  
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT  
  
   BEGIN TRAN; 
   
   IF UPDATE(TrafficCop)  
   BEGIN  
      SELECT @n_continue = 4  
   END  
   IF UPDATE(ArchiveCop)  
   BEGIN  
      SELECT @n_continue = 4  
   END  
  
   -- Added By SHONG 27-Mar-2006  
   IF NOT UPDATE(ScanOutDate)  
   BEGIN  
      SELECT @n_continue = 4  
   END  
  
   -- (June01) - Start  
   -- TraceInfo  
   DECLARE @c_starttime datetime  
         , @c_endtime   datetime  
         , @c_step1     datetime  
         , @c_step2     datetime  
         , @c_step3     datetime  
         , @c_step4     datetime  
         , @c_step5     datetime  
         , @c_col1      NVARCHAR(20)  
         , @c_col2      NVARCHAR(20)  
         , @c_col3      NVARCHAR(20)  
         , @c_col4      NVARCHAR(20)  
         , @c_col5      NVARCHAR(20)  
         , @c_TraceName NVARCHAR(80)  
  
   SET @c_col1 = ''  
   SET @c_col2 = ''  
   SET @c_col3 = ''  
   SET @c_col4 = ''  
   SET @c_col5 = ''  
   SET @c_starttime = GetDate()
     
   -- TraceInfo  
   -- (June01) - End  
   /* #INCLUDE <TRMBOA1.SQL> */  
  
   IF @n_continue = 1 OR @n_continue = 2        --(Wan01)
   BEGIN                                        --(Wan01)  
      IF EXISTS( SELECT 1 FROM NSQLCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'RF_BATCH_PICK' AND NSQLVALUE = '1')  
         SELECT @n_RF_BatchPicking = 1  
      ELSE  
         SELECT @n_RF_BatchPicking = 0  
  
      SELECT @c_PickSlipNo = SPACE(10)  
  
      DECLARE C_trPkngInfoPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT INSERTED.PickSlipNo,  
             PickHeader.ZONE,  
             PickHeader.ExternOrderKey,  
             ISNULL(PickHeader.OrderKey, '')  
      FROM  INSERTED  
      JOIN  PickHeader WITH (NOLOCK) ON PickHeaderKey = INSERTED.PickSlipNo  
      WHERE INSERTED.ScanOutDate IS NOT NULL  
      ORDER BY INSERTED.PickSlipNo, PickHeader.ExternOrderKey, ISNULL(PickHeader.OrderKey, '')  
  
      OPEN C_trPkngInfoPickSlip  
      WHILE 1=1  
      BEGIN  
         FETCH NEXT FROM C_trPkngInfoPickSlip INTO @c_PickSlipNo, @c_TicketType, @c_LoadKey, @c_OrderKey  
  
         IF @@FETCH_STATUS = -1  
            BREAK  
  
         IF @b_debug = 1  
         BEGIN  
            PRINT 'Loop 1 - Picking Info, PickSlip No/Ticket Type = '  
                  + ISNULL(RTRIM(@c_PickSlipNo),'') + '/' + ISNULL(RTRIM(@c_TicketType),'')  
         END  
  
         -- Added by Ricky  
         IF @c_TicketType NOT IN ('XD','LB','LP')
         BEGIN  
            IF ISNULL(RTRIM(@c_OrderKey),'') = ''  
            BEGIN  
               -- Conso PickSlip - Loop for Order  
               SELECT @c_NextOrderKey = SPACE(10)  
               SELECT @c_NextPickSlipNo = SPACE(10)  
  
               DECLARE C_trPkngInfonNxtOrdKy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT LoadPlanDetail.OrderKey, Orders.StorerKey, Orders.DocType  
               FROM   LoadPlanDetail WITH (NOLOCK)  
               JOIN   Orders WITH (NOLOCK) ON LoadPlanDetail.OrderKey = Orders.OrderKey  
               WHERE  LoadPlanDetail.LoadKey = @c_LoadKey  
               ORDER BY LoadPlanDetail.OrderKey  
            END  
            ELSE  
            BEGIN  
               DECLARE C_trPkngInfonNxtOrdKy CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT Orders.OrderKey, Orders.StorerKey, Orders.DocType  
               FROM   Orders WITH (NOLOCK)  
               WHERE  Orders.OrderKey = @c_OrderKey  
               ORDER BY Orders.OrderKey  
            END  
  
            SET @c_step1 = GetDate()  
  
            OPEN C_trPkngInfonNxtOrdKy
            FETCH NEXT FROM C_trPkngInfonNxtOrdKy INTO @c_NextOrderKey, @c_StorerKey, @c_DocType
              
            WHILE @@FETCH_STATUS = 0  
            BEGIN    
               IF @b_debug = 1  
               BEGIN  
                  IF @c_TicketType = 'C'  
                     PRINT 'Loop 2 - Loadplan Detail, PickSlipNo/OrderKey = '  
                           + ISNULL(RTRIM(@c_NextPickSlipNo),'') + '/' + ISNULL(RTRIM(@c_NextOrderKey),'')  
                  ELSE IF @c_TicketType <> 'C'  
                     PRINT 'Loop 2 - Loadplan Detail, OrderKey = ' + ISNULL(RTRIM(@c_NextOrderKey),'')  
               END  
  
               -- SHONG01  
               SET @c_BackendPickCfm = '0'  
               SELECT @c_BackendPickCfm = ISNULL(sValue, '0')  
               FROM   StorerConfig AS sc WITH (NOLOCK)   
               WHERE  StorerKey = @c_storerkey  
               AND    sc.ConfigKey = 'BackendPickConfirm'   
               AND    sc.SValue = '1'  
                   
               SET @c_step3 = GetDate()  
  
               -- 22-Feb-2005  
               -- Added By SHONG On 22-Mar-2005  
               IF EXISTS(SELECT 1 FROM DELETED, INSERTED  
                           WHERE INSERTED.PickSlipNo = @c_PickSlipNo  
                           AND   INSERTED.PickSlipNo = DELETED.PickSlipNo  
                           AND   INSERTED.ScanOutDate IS NOT NULL  
                           AND   INSERTED.ScanOutDate > DELETED.ScanOutDate)  
               BEGIN  
                  IF ISNULL(RTRIM(@c_LoadKey),'') <> '' 
                     EXEC dbo.ispPickConfirmCheck @c_LoadKey
                  ELSE 
                     EXEC dbo.ispPickConfirmCheck @c_LoadKey, @c_NextOrderKey  
               END
                 
               IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
                 AND ISNULL(@c_Orderkey,'') = '' --NJOW01
               BEGIN
                  IF  @c_TicketType = '9' AND @n_RF_BatchPicking = 1
                  BEGIN
                     DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM  PICKDETAIL WITH (NOLOCK)                             
                     JOIN  ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND  
                                                      ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber) 
                     WHERE ORDERDETAIL.OrderKey = @c_NextOrderKey     
                     AND   (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')   
                     AND   PICKDETAIL.Status < '4'   
                     AND   PICKDETAIL.ShipFlag <> 'P' --(Wan01)  
                     AND   ORDERDETAIL.LoadKey = @c_LoadKey                     	
                  END       
                  ELSE IF @c_TicketType = 'C'
                  BEGIN
                     DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM  PICKDETAIL WITH (NOLOCK)  
                     JOIN  ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND  
                                                         ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber) 
                     WHERE ORDERDETAIL.OrderKey = @c_NextOrderKey    
                     AND   PICKDETAIL.Status < '4'   
                     AND   PICKDETAIL.ShipFlag <> 'P' --(Wan01)   
                     AND   ORDERDETAIL.LoadKey = @c_LoadKey                          	
                  END
                  ELSE
                  BEGIN
                     DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM  PICKDETAIL WITH (NOLOCK)                       	    
                     JOIN  ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND  
                                                      ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)    
                     WHERE ORDERDETAIL.OrderKey = @c_NextOrderKey    
                     AND   PICKDETAIL.Status < '4' 
                     AND   PICKDETAIL.ShipFlag <> 'P' --(Wan01)  
                     AND   ORDERDETAIL.LoadKey = @c_LoadKey                      	
                  END                     	
               END
               ELSE 
               BEGIN
                  IF @c_TicketType = '9' AND @n_RF_BatchPicking = 1 -- (Wan02)
                  BEGIN
                     DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM  PICKDETAIL WITH (NOLOCK)                             
                     WHERE PICKDETAIL.OrderKey = @c_NextOrderKey     
                     AND   (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')   
                     AND   PICKDETAIL.Status < '4'   
                     AND   PICKDETAIL.ShipFlag <> 'P' --(Wan01)                       	
                  END       
                  ELSE
                  BEGIN
                     DECLARE CUR_UPDATE_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT PickDetailKey
                     FROM  PICKDETAIL WITH (NOLOCK)                       	    
                     WHERE PICKDETAIL.OrderKey = @c_NextOrderKey    
                     AND   PICKDETAIL.Status < '4' 
                     AND   PICKDETAIL.ShipFlag <> 'P' --(Wan01)                        	
                  END                              	
               END
                                               	
               OPEN CUR_UPDATE_PICKDETAIL
                        	
               FETCH FROM CUR_UPDATE_PICKDETAIL INTO @c_PickDetailKey
                        	
               WHILE @@FETCH_STATUS = 0
               BEGIN
               	-- SWT02 (Start)
                  SET @c_PickDet_Status = '' 
                  SET @c_PickDet_ShpFlg = ''
                  
                  SELECT @c_PickDet_Status = p.[Status], 
                         @c_PickDet_ShpFlg = p.ShipFlag
                  FROM PICKDETAIL AS p WITH(NOLOCK)  
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @c_PickDet_Status < '4' AND @c_PickDet_ShpFlg NOT IN ('P','Y')
                  BEGIN
                     IF  @c_BackendPickCfm = '1' AND @c_DocType = 'E'
                     BEGIN                  	 
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET ShipFlag = 'P', EditDate = GETDATE(), EditWho = SUSER_SNAME()
                        WHERE PickDetailKey = @c_PickDetailKey
                     END
                     ELSE
                     BEGIN
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET Status = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()
                        WHERE PickDetailKey = @c_PickDetailKey
                        AND   Status < '4'     --tlting01
                     END                  		
                  END
                  -- SWT02 (End) 
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0    
                  BEGIN    
                     SELECT @n_continue = 3    
                     SELECT @n_err = 61790   
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(RTrim(@n_err),0))   
                                       +': Update Failed On Table PICKDETAIL. (isp_ScanOutPickSlip)' + ' ( '   
                                       + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '    
                     --SET ROWCOUNT 0    
                     GOTO EXIT_TRIGGER  
                  END                           	
                        	
                  FETCH FROM CUR_UPDATE_PICKDETAIL INTO @c_PickDetailKey
               END                        	
               CLOSE CUR_UPDATE_PICKDETAIL
               DEALLOCATE CUR_UPDATE_PICKDETAIL                                                                       
                 
               IF @c_BackendPickCfm = '1'  
               BEGIN
                  EXEC isp_ConfirmPick 
                         @c_OrderKey  = @c_NextOrderKey
                        , @c_LoadKey  = @c_LoadKey
                        , @b_Success  = @b_Success OUTPUT
                        , @n_err      = @n_err     OUTPUT
                        , @c_errmsg   = @c_errmsg  OUTPUT  
                        
                 GOTO SKIP_ORDER_UPDATE
               END   
                 
               SET @c_step3 = GetDate() - @c_step3  
  
               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN  
                  IF EXISTS(SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_NextOrderKey) AND  
                     NOT EXISTS(SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_NextOrderKey AND Status < '5')  
                  BEGIN  
                  	 -- SWT02
                  	 SET @c_Status = ''                  	
                  	 SELECT @c_Status = o.[Status]
                     FROM ORDERS AS o WITH(NOLOCK)
                     WHERE o.OrderKey = @c_NextOrderKey
                     
                     IF @c_Status < '5' AND @c_Status <> ''
                     BEGIN
                        UPDATE ORDERS WITH (ROWLOCK)
                           SET Status = '5',
                               EditDate = GetDate(),
                               EditWho  = sUser_sName()
                        WHERE  OrderKey = @c_NextOrderKey
                        AND   [Status] < '5'       --tlting01
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	                      IF @n_err <> 0  
	                      BEGIN  
	                         SELECT @n_continue = 3  
	                         SELECT @n_err = 61782 --22802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
	                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Orders. (ntrPickingInfoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
	                         GOTO EXIT_TRIGGER  
	                      END  
	                   END
                  END  
               END  
               
  
               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN  
                  IF EXISTS( SELECT OrderKey FROM OrderDetail WITH (NOLOCK)  
                             WHERE  OrderKey = @c_NextOrderKey  
                             AND    Status < '5')  
                  BEGIN  
	               		-- SWT02
	                  DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	                  SELECT OrderLineNumber
	                  FROM ORDERDETAIL WITH (NOLOCK)
	                  WHERE OrderKey = @c_NextOrderKey 
	                  AND   [Status] < '5'
	      
	                  OPEN CUR_ORDER_LINES
	      
	                  FETCH FROM CUR_ORDER_LINES INTO @c_OrderLineNumber
	      
	                  WHILE @@FETCH_STATUS = 0
	                  BEGIN
	                     UPDATE ORDERDETAIL WITH (ROWLOCK)     
	                        SET [Status] = '5', EditDate = GETDATE(), EditWho=sUser_sName(), TrafficCop = NULL     
	                     WHERE OrderKey = @c_NextOrderKey   
	                     AND   OrderLineNumber = @c_OrderLineNumber
	                     AND   [Status] < '5'          --tlting01
	         
	                     IF @@ERROR <> 0    
	                     BEGIN    
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61783 --22803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table OrderDetail. (ntrPickingInfoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                        GOTO EXIT_TRIGGER    
	                     END    
	      
	      	            FETCH FROM CUR_ORDER_LINES INTO @c_OrderLineNumber
	                  END      
	                  CLOSE CUR_ORDER_LINES
	                  DEALLOCATE CUR_ORDER_LINES   
	                                    	
                     -- cater for split Orders in loadplan  
                     --UPDATE OrderDetail WITH (ROWLOCK)  
                     --   SET Status = '5',  
                     --       EditDate = GetDate(),  
                     --       EditWho  = sUser_sName(),  
                     --       TrafficCop = NULL  
                     --WHERE  OrderKey = @c_NextOrderKey  
                     --AND    Loadkey = @c_LoadKey  
                     --AND    Status < '5'  
  
                     --SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                       
                     --IF @n_err <> 0  
                     --BEGIN  
                     --   SELECT @n_continue = 3  
                     --   SELECT @n_err = 61783 --22803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table OrderDetail. (ntrPickingInfoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                     --   GOTO EXIT_TRIGGER  
                     --END  
                  END   
               END  
  
               -- Commented by SHONG on 13-Apr-2006  
               -- Not necessary, already update in OrderDetail update trigger.  
               -- IF @n_continue = 1 OR @n_continue = 2  
               -- BEGIN  
               --    IF @c_TicketType = '3' OR @c_TicketType = '8' OR @c_TicketType = '7'  
               --    BEGIN  
               --       UPDATE Orders  
               --          SET UserDefine03 = convert(char(20),(Select Sum(OrderDetail.QtyPicked * OrderDetail.unitprice)  
               --                                               From  OrderDetail (NOLOCK)  
               --                                               WHERE OrderDetail.OrderKey = Orders.OrderKey)),  
               --              EditDate = GetDate(),  
               --              EditWho  = sUser_sName(),  
               --              TrafficCop = NULL  
               --       FROM Orders  
               --       WHERE OrderKey = @c_NextOrderKey  
               --       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
               --       IF @n_err <> 0  
               --       BEGIN  
               --          SELECT @n_continue = 3  
               --          SELECT @n_err=22804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               --          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Orders. (ntrPickingInfoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
               --          GOTO EXIT_TRIGGER  
               --       END  
               --    END -- Ticket Type = 3 OR 8  
               -- END  
               
               SKIP_ORDER_UPDATE:
               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN  
                  IF ISNULL(RTRIM(@c_LoadKey),'') <> ''  
                  BEGIN  
                  	-- SWT02
                  	SET @c_LoadLineNumber = ''
                  	
                  	SELECT @c_LoadLineNumber = LoadLineNumber
                  	FROM LOADPLANDETAIL WITH (NOLOCK) 
                     WHERE Loadkey = @c_LoadKey
                     AND OrderKey = @c_NextOrderKey
                     AND STATUS < '5' 
                  	
                     IF @c_LoadLineNumber <> ''
                     BEGIN
                        UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                           SET STATUS = '5',
                                 EditDate = GetDate(),
                                 EditWho   = sUser_sName(),
                                 TrafficCop = null
                        WHERE Loadkey  = @c_LoadKey
                          AND LoadLineNumber = @c_LoadLineNumber
                          AND STATUS < '5'         --tlting01

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61784 --22805    
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrPickingInfoUpdate)'  
                                 + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                           GOTO EXIT_TRIGGER  
                        END  
                     END                          	                  	
                     
                     --IF EXISTS( SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE Loadkey = @c_LoadKey  
                     --           AND OrderKey = @c_NextOrderKey  
                     --           AND Status < '5' )  
                     --BEGIN  
                     --   UPDATE LoadPlanDetail WITH (ROWLOCK)  
                     --      SET Status = '5', EditDate = GetDate(),  
                     --          EditWho  = sUser_sName(), trafficcop = NULL  
                     --   WHERE Loadkey = @c_LoadKey  
                     --     AND OrderKey = @c_NextOrderKey  
                     --     AND Status < '5'  
  
                     --   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
                     --   IF @n_err <> 0  
                     --   BEGIN  
                     --      SELECT @n_continue = 3  
                     --      SELECT @n_err = 61784 --22805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     --      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LoadPlanDetail. (ntrPickingInfoUpdate)'  
                     --            + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                     --      -- 22-Feb-2005  
                     --      GOTO EXIT_TRIGGER  
                     --   END  
                     --END  
                  END  -- IF ISNULL(RTRIM(@c_LoadKey),'') <> ''
               END  
  
               IF @c_TicketType IN ('8','7','9') -- SWT02
               BEGIN  
                  IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE Storerkey = @c_StorerKey  
                            AND Configkey = 'ULVITF' AND SVALUE = '1')  
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK)  
                                    WHERE StorerKey = @c_StorerKey AND Configkey = 'ULVPODITF' AND SValue = '1' )  
                     BEGIN  
                        SELECT @c_tablename = CASE TYPE WHEN 'WT' THEN 'ULVNSO'  
                                                        WHEN 'W'  THEN 'ULVHOL'  
                                                        WHEN 'WC' THEN 'ULVINVTRF'  -- Added by YokeBeen on 19-Nov-2002 (FBR8623)  
                                                        WHEN 'WD' THEN 'ULVDAMWD'   -- (YokeBeen02)  
                                                        ELSE 'ULVPCF'  
                                              END  
                        FROM Orders WITH (NOLOCK)  
                        WHERE OrderKey = @c_NextOrderKey  
  
                        SELECT @c_OrderLineNumber = ''  
  
                        DECLARE C_trPkngInfOrdLnNr CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                           SELECT OrderDetail.Orderlinenumber  
                           FROM OrderDetail WITH (NOLOCK)  
                           WHERE OrderKey = @c_NextOrderKey  
                           AND Status = '5'  
                           ORDER BY OrderDetail.Orderlinenumber  
  
                        OPEN C_trPkngInfOrdLnNr  
                        WHILE (1 = 1) AND (@n_continue = 1 OR @n_continue = 2)  
                        BEGIN  
                           FETCH NEXT FROM C_trPkngInfOrdLnNr INTO @c_OrderLineNumber  
  
                           IF @@FETCH_STATUS = -1  
                              BREAK  
  
                           EXEC dbo.ispGenTransmitLog2  @c_Tablename, @c_NextOrderKey, @c_OrderLineNumber, @c_StorerKey, ''  
                                 , @b_success OUTPUT  
                                 , @n_err OUTPUT  
                                 , @c_errmsg OUTPUT  
  
                           IF NOT @b_success = 1  
                           BEGIN  
                              SELECT @n_continue = 3  
                              GOTO EXIT_TRIGGER  
                           END  
                        END -- While Loop Order Line  
                        CLOSE C_trPkngInfOrdLnNr  
                        DEALLOCATE C_trPkngInfOrdLnNr  
                     END -- ULVPODITF turn on  
                  END -- if ULVITF Turn on  
               END -- IF @c_TicketType = '8' OR @c_TicketType = '7'  
  
               IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE Storerkey = @c_StorerKey  
                         AND Configkey = 'PICKLOG' AND SVALUE = '1')  
               BEGIN  
                  EXEC dbo.ispGenTransmitLog 'PICK', @c_NextOrderKey, '', @c_PickSlipNo, ''  
                                 , @b_success OUTPUT  
                                 , @n_err OUTPUT  
                                 , @c_errmsg OUTPUT  
  
                  IF NOT @b_success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61785 --62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (PICK) Failed (ntrOrderDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                     GOTO EXIT_TRIGGER  
                  END  
               END -- Interface ConfigKey 'PICKLOG'  
  
               IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE Storerkey = @c_StorerKey  
                         AND Configkey = 'CDSORD' AND SVALUE = '1')  
               BEGIN  
                  EXEC dbo.ispGenTransmitLog 'CDSORD', @c_NextOrderKey, '', '', ''  
                                 , @b_success OUTPUT  
                                 , @n_err OUTPUT  
                                 , @c_errmsg OUTPUT  
  
                  IF NOT @b_success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61786 --62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (CDSORD) Failed (ntrOrderDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                     GOTO EXIT_TRIGGER  
                  END  
               END -- Interface ConfigKey 'CDSORD'  
  
               IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE Storerkey = @c_StorerKey  
                         AND Configkey = 'LORITF' AND SVALUE = '1')  
               BEGIN  
                  EXEC dbo.ispGenTransmitLog 'LORPICK', @c_NextOrderKey, '', '', ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                  IF NOT @b_success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61787 --62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (LORPICK) Failed (ntrOrderDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                     GOTO EXIT_TRIGGER  
                  END  
               END -- Interface ConfigKey 'LORITF'  
  
               -- Added by MCTANG on 30-Jul-2008 (SOS#110279 - Vital Pack Confirm) - Start  
               IF EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE Storerkey = @c_StorerKey  
                         AND Configkey = 'VPACKLOG' AND SVALUE = '1')  
               BEGIN  
                  SELECT @b_success = 1  
                  EXEC dbo.ispGenVitalLog 'VPACKLOG', @c_NextOrderKey, '', @c_storerkey, ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                  IF NOT @b_success = 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61788 --62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into TransmitLog Table (VPACKLOG) Failed (ntrPickingInfoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                     GOTO EXIT_TRIGGER  
                  END  
               END -- Interface ConfigKey 'VPACKLOG'  
               -- Added by MCTANG on 30-Jul-2008 (SOS#110279 - Vital Pack Confirm) - End  
               
               FETCH NEXT FROM C_trPkngInfonNxtOrdKy INTO @c_NextOrderKey, @c_StorerKey, @c_DocType               
            END -- While loop Order Key  
            CLOSE C_trPkngInfonNxtOrdKy  
            DEALLOCATE C_trPkngInfonNxtOrdKy  
  
            SET @c_step1 = GetDate() - @c_step1  
  
            --- End Order Key Loop ---------------------------------------------------------------------  
  
            SET @c_step2 = GetDate()  
  
            --IF ISNULL(RTRIM(@c_LoadKey),'') <> ''  
            --BEGIN  
            --   --(Wan01) - START
            --   SET @n_Cnt = 0 

            --   SELECT TOP 1 @n_Cnt = 1 
            --   FROM ORDERS WITH (NOLOCK)
            --   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey) 
            --   WHERE ORDERS.Loadkey = @c_LoadKey
            --   AND   PICKDETAIL.Status < '5' -- no more PickDetail with Status < '5'

            --   --IF NOT EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK), LoadPlanDetail WITH (NOLOCK), OrderDetail WITH (NOLOCK)
            --                  --WHERE LoadPlanDetail.Loadkey = OrderDetail.Loadkey
            --                  --AND   LoadPlanDetail.Loadkey = @c_LoadKey
            --                  --AND   PickDetail.OrderKey = OrderDetail.OrderKey
            --                  --AND   PickDetail.OrderlineNumber = OrderDetail.OrderlineNumber
            --                  --AND   PickDetail.Status < '5') -- no more PickDetail with Status < '5'
            --   IF @n_Cnt = 0 
            --   BEGIN
            --   --(Wan01) - END   
            --      UPDATE LOADPLAN WITH (ROWLOCK)  
            --         SET Status = '5', EditDate = GetDate(),  
            --             EditWho  = sUser_sName(), TrafficCop = NULL  
            --      WHERE Loadkey = @c_LoadKey --Added By Vicky 18 july 2002 Patch from IDSHK  
            --        AND Status < '5' --Added By Vicky 18 july 2002 Patch from IDSHK  
  
            --      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
  
            --      IF @n_err <> 0  
            --      BEGIN  
            --         SELECT @n_continue = 3  
            --         SELECT @n_err = 61788 --22809   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            --         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLAN. (ntrPickingInfoUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
            --         GOTO EXIT_TRIGGER  
            --      END  
            --   END -- NOT EXISTS  
            --END -- IF LTRIM(RTRIM(@c_LoadKey)) <> '' 
  
            SET @c_step2 = GetDate() - @c_step2  
         END -- IF @c_TicketType <> 'XD' AND @c_TicketType <> 'LB'  
         ELSE  
         BEGIN  
            IF @c_TicketType IN ('XD','LB','LP') -- SOS37177 & SOS37178, add by ONG 7.JUL.2005  
            BEGIN
               SELECT @c_PickDetailKey = SPACE(18)

               DECLARE C_PkngInfPckDtlKy CURSOR LOCAL FAST_FORWARD READ_ONLY
                  FOR  SELECT RefKeyLookup.PickDetailKey
                  FROM  RefKeyLookup WITH (NOLOCK)
                  WHERE PickslipNo = @c_PickSlipNo
                  ORDER BY RefKeyLookup.PickDetailKey

               OPEN C_PkngInfPckDtlKy
               FETCH NEXT FROM C_PkngInfPckDtlKy INTO @c_PickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
               	SET @c_PickDet_Status = '5'
               	
               	SELECT @c_PickDet_Status = p.[Status]
               	FROM PICKDETAIL AS p WITH(NOLOCK)
               	WHERE p.PickDetailKey = @c_PickDetailKey
               	
               	IF @c_PickDet_Status < '4'
               	BEGIN
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET STATUS = '5', EditDate = GETDATE(), EditWho = SUSER_SNAME()
                     WHERE  PickDetailKey = @c_PickDetailKey
                     AND    Status < '4'     --tlting01
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61789 --22801    
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PickDetail. (ntrPickingInfoUpdate)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                        GOTO EXIT_TRIGGER  
                     END               		
               	END                    

                  FETCH NEXT FROM C_PkngInfPckDtlKy INTO @c_PickDetailKey
               END -- WHILE pickdetail
               CLOSE C_PkngInfPckDtlKy
               DEALLOCATE C_PkngInfPckDtlKy


               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  --NJOW02
                  DECLARE cur_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT Orderkey
                     FROM ( SELECT DISTINCT PICKDETAIL.Orderkey
                            FROM PICKDETAIL (NOLOCK)
                            JOIN RefKeyLookup WITH (NOLOCK) ON RefKeyLookup.PickDetailKey = PickDetail.PickDetailKey
                            WHERE RefKeyLookup.PickslipNo = @c_PickSlipNo
                            AND   PickDetail.Status = '5' ) AS A
                     WHERE NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK) WHERE PD.Orderkey = A.Orderkey AND PD.Status < '5')
                     ORDER BY Orderkey

                  OPEN cur_Orders

                  FETCH NEXT FROM cur_Orders INTO @c_NextOrderKey

                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                  	SET @c_Status = '5'
                  	
                  	SELECT @c_Status = [Status]
                     FROM ORDERS AS o WITH(NOLOCK)
                     WHERE o.OrderKey = @c_NextOrderKey
                  	IF @c_Status < '5'
                  	BEGIN
                        UPDATE Orders WITH (ROWLOCK)
                           SET Status = '5', EditDate = GetDate(),
                               EditWho  = sUser_sName(), Trafficcop = NULL
                        WHERE Orderkey = @c_NextOrderKey
                        AND   Status < '5'    --tlting01

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61790 --22801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Orders. (ntrPickingInfoUpdate)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
                           GOTO EXIT_TRIGGER  
                        END                  		
                  	END
                     FETCH NEXT FROM cur_Orders INTO @c_NextOrderKey
                  END
                  CLOSE cur_Orders
                  DEALLOCATE cur_Orders
               END
            END  -- IF @c_TicketType IN ('XD','LB','LP') 
         END  
      END -- while loop picking info  
      CLOSE C_trPkngInfoPickSlip  
      DEALLOCATE C_trPkngInfoPickSlip  
  
   END -- @n_continue = 1 OR @n_continue=2  
  
   EXIT_TRIGGER:  
   -- To turn this on only when need to trace on the performance.  
   -- insert into table, TraceInfo for tracing purpose.  
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN  
         SET @c_col1      = @c_PickSlipNo  
         SET @c_col2      = RTRIM(@c_TicketType)  
         SET @c_TraceName = 'ntrPickingInfoUpdate'  
         SET @c_endtime = GetDate()  
  
--         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)  
--         VALUES ( @c_TraceName, @c_starttime, @c_endtime  
--                  , CONVERT(CHAR(12),@c_endtime-@c_starttime ,114)  
--                  , ISNULL(CONVERT(CHAR(12),@c_step1,114), '00:00:00:000')  
--                  , ISNULL(CONVERT(CHAR(12),@c_step2,114), '00:00:00:000')  
--                  , ISNULL(CONVERT(CHAR(12),@c_step3,114), '00:00:00:000')  
--                  , ISNULL(CONVERT(CHAR(12),@c_step4,114), '00:00:00:000')  
--                  , ISNULL(CONVERT(CHAR(12),@c_step5,114), '00:00:00:000')  
--                  , @c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5 )  
      END  
  
   /* #INCLUDE <TRMBOHA2.SQL> */  
   IF @n_continue = 3  -- Error Occured - Process AND Return  
   BEGIN  
      DECLARE @n_IsRDT INT  
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  
  
      IF @n_IsRDT = 1  
      BEGIN  
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here  
         -- Instead we commit AND raise an error back to parent, let the parent decide  
  
         -- Commit until the level we begin with  
         WHILE @@TRANCOUNT > @n_starttcnt  
            COMMIT TRAN  
  
         -- Raise error with severity = 10, instead of the default severity 16.  
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger  
         RAISERROR (@n_err, 10, 1) WITH SETERROR  
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten  
      END  
      ELSE  
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPickingInfoUpdate'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END  


GO