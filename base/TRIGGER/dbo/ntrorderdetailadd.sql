SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Trigger: ntrOrderDetailAdd                                            */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Input Parameters: NONE                                                */
/*                                                                       */
/* OUTPUT Parameters: NONE                                               */
/*                                                                       */
/* Return Status: NONE                                                   */
/*                                                                       */
/* Usage:                                                                */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By: When records INSERTED                                      */
/*                                                                       */
/* PVCS Version: 1.2                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  ver  Purposes                                    */
/* 03-Jan-2008  Shong   1.1  SOS#89405 - ReOpen CANCEL Status when new   */
/*                           line Added for all.                         */
/* 24-Aug-2009  TLTING  1.2  SOS#140063 - Keep original Open Qty         */
/*                                      No change to it  (tlting01)      */
/* 01-Dec-2009  SHONGN  1.3  SOS#143271 Added Error Checking When update */
/*                           ExternOrderKey                              */  
/* 27-Feb-2012  NJOW01  1.4  237150-Populate sku outgoing shelflife to   */
/*                           orderdetail                                 */
/* 12-May-2014  YTWan   1.5  SOS#310515 - New Requirement Caculate       */
/*                           Orders.Capacity from Pack module (Wan01)    */
/* 26-Jan-2016  YTWan   1.6  Fixed (Wan02)                               */
/* 08-Aug-2016  TLTING  1.7  Add nolock                                  */
/* 20-Sep-2016  TLTING  1.8  Change SetROWCOUNT 1 to Top 1               */
/* 03-Feb-2017  TLTING  1.9  Extend field length for decimal             */
/* 15-May-2018  tlting02 2.0 Single\Multi Orders                         */
/* 24-Aug-2018  SWT01    2.1  Performance Tuning                         */ 
/* 27-Sep-2018  TLTING03 2.2  Performance Tuning                         */ 
/* 17-Aug-2020  Shong    2.3  Split Trigger to Pre and Post              */
/* 11-Nov-2020  Shong    2.4  Fixing CANC Order status update to 1 issues*/
/*                            (SWT001)                                   */
/* 02-Jun-2021  NJOW03   2.5  WMS-16977 Fix @c_newstatus default value   */
/* 07-May-2024  NJOW04   2.6  UWP-18748  Allow config to call custom sp  */
/*************************************************************************/
CREATE   TRIGGER [dbo].[ntrOrderDetailAdd]
ON  [dbo].[ORDERDETAIL]
FOR INSERT
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
          @b_Success    INT       -- Populated by calls to stored procedures - was the proc successful?
,         @n_err        INT       -- Error number returned by stored procedure or this trigger       -- For Additional Error Detection
,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
,         @n_Continue   INT                 
,         @n_starttcnt  INT                -- Holds the current transaction count
,         @n_cnt        INT


SELECT @n_Continue=1, @n_starttcnt=@@TRANCOUNT
     /* #INCLUDE <TRODA1.SQL> */     

-- Added By SHONG 14-Apr-2003
-- To skip all the trigger process when insert from Archive DB due to User Request
IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   SELECT @n_Continue = 4

Declare @c_Authority            NVARCHAR(1) = '0', 
        @c_Authority_OrdWgtVol  NVARCHAR(1) = '0', 
        @c_AuthOrdersStop       NVARCHAR(1) = '0',
        @c_Authority_OrdTLLog   NVARCHAR(1) = '0', 
        @c_Facility             NVARCHAR(5) = '', 
        @c_StorerKey            NVARCHAR(15) = '',
        @c_Sku                  NVARCHAR(20) = '',
        @c_OrderKey             NVARCHAR(10) = '', 
        @n_InsertedCount        INT = 0,  
        @c_OrderLineNumber      NVARCHAR(5),
        @c_ExternLineNo         NVARCHAR(5), 
        @c_ExternOrderKey       NVARCHAR(50),
        @c_SpecialHandling      NVARCHAR(10) = '',
        @n_Weight               DECIMAL(25,5) = 0,
        @n_CBM                  DECIMAL(25,5) = 0,
        @n_OpenQty              INT = 0,
        @c_Status               NVARCHAR(10) = '',
        @c_SOStatus             NVARCHAR(10) = '',
        @c_OrdType              NVARCHAR(10) = '',
        @c_NewStatus            NVARCHAR(10) = ''        

--NJOW04
IF (@n_continue=1 or @n_continue=2)          
BEGIN   	  
   IF EXISTS (SELECT 1 FROM INSERTED i   ----->Put INSERTED if INSERT action
              JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey    
              JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
              WHERE  s.configkey = 'OrderDetailTrigger_SP')   -----> Current table trigger storerconfig
   BEGIN        	  
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

   	 SELECT * 
   	 INTO #INSERTED
   	 FROM INSERTED
       
      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL 
         DROP TABLE #DELETED
 
   	 SELECT * 
   	 INTO #DELETED
   	 FROM DELETED

      EXECUTE dbo.isp_OrdertDetailTrigger_Wrapper ----->wrapper for current table trigger
                'INSERT'  -----> @c_Action can be INSERT, UPDATE, DELETE
              , @b_Success  OUTPUT  
              , @n_Err      OUTPUT   
              , @c_ErrMsg   OUTPUT 

      IF @b_success <> 1  
      BEGIN  
         SELECT @n_continue = 3  
               ,@c_errmsg = 'ntrOrderDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
      END  
      
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED
   END
END      
         
IF (@n_Continue = 1 or @n_Continue=2)  
BEGIN
   DECLARE CUR_ORDHEADER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ORDERS.OrderKey, ORDERS.StorerKey, ORDERS.Facility, 
          ISNULL(ORDERS.SpecialHandling, ''), ORDERS.[Status], 
          ORDERS.SOStatus, ORDERS.[Type] 
   FROM dbo.ORDERS AS ORDERS (NOLOCK)
   WHERE EXISTS(SELECT 1 FROM INSERTED WHERE ORDERS.OrderKey = INSERTED.OrderKey) 

   OPEN CUR_ORDHEADER

   FETCH FROM CUR_ORDHEADER INTO @c_OrderKey, @c_StorerKey, @c_Facility, @c_SpecialHandling, @c_Status, @c_SOStatus, @c_OrdType

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @b_Success = 0
      
      SET @c_AuthOrdersStop = '0'
      
      Execute nspGetRight @c_Facility, 
            @c_StorerKey,   -- Storer
            '',              -- Sku
            'OrdersStop',    -- ConfigKey
            @b_Success               OUTPUT, 
            @c_AuthOrdersStop        OUTPUT, 
            @n_err                   OUTPUT, 
            @c_errmsg                OUTPUT

      IF @b_Success <> 1
      BEGIN
         Select @n_Continue = 3 
         SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve of Right (OrderStop) Failed (ntrOrderDetailAdd)' + ' ( ' 
         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
         BREAK 
      END
      
      IF (@n_Continue = 1 or @n_Continue=2) AND @c_AuthOrdersStop = '1'
      BEGIN
         IF EXISTS(SELECT 1 
                     FROM INSERTED 
                     JOIN SKU (NOLOCK) ON SKU.Storerkey = INSERTED.Storerkey 
                                       AND SKU.SKU = INSERTED.SKU
                                       AND SKU.SKUGROUP = 'OD' 
                     WHERE INSERTED.OrderKey = @c_OrderKey)
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
                  SET ORDERS.Stop = StorerSODefault.Stop, 
                     TrafficCop = NULL,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()  
               FROM ORDERS  
               JOIN STORERSODEFAULT (NOLOCK) ON STORERSODEFAULT.STORERKEY = ORDERS.STORERKEY
            WHERE ORDERS.OrderKey = @c_OrderKey
            
         END
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Of Stop On ORDERS Failed (ntrOrderDetailAdd)' 
            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
            BREAK
         END         
      END
      
      IF @n_Continue=1 or @n_Continue=2
      BEGIN
         Select @b_Success = 0

         Execute nspGetRight 
                  @c_Facility, 
                  @c_StorerKey,   -- Storer
                  '',                   -- Sku
                  'WgtnVolCalcInOrd',   -- ConfigKey
                  @b_Success          OUTPUT, 
                  @c_Authority_OrdWgtVol    OUTPUT, 
                  @n_err              OUTPUT, 
                  @c_errmsg           OUTPUT

         IF @b_Success <> 1
         BEGIN
            Select @n_Continue = 3 
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve of Right (OrderStop) Failed (ntrOrderDetailAdd)' + ' ( ' 
            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
            BREAK
         END
      END -- IF @n_Continue=1 or @n_Continue=2
      
      -- To Calclulate the Weight and Capacity for Order Header base on INSERTED Orderdetail
      IF (@n_Continue = 1 or @n_Continue=2)  
      BEGIN
         SELECT @n_Weight = 0, 
                @n_CBM = 0, 
                @n_OpenQty = 0
                -- (SWT001) Comment by SHONG on 11/11/2020, should not initial this 
                -- @c_SOStatus = '' 
                -- @c_Status = '', 

         
         SELECT @n_Weight = ISNULL(SUM(CASE WHEN @c_Authority_OrdWgtVol IN ('1','2')
                                          THEN (INSERTED.OpenQty * SKU.STDGROSSWGT)
                                          ELSE 0
                                          END), 0.00000)
               ,@n_CBM    = ISNULL(SUM(CASE WHEN @c_Authority_OrdWgtVol = '2' AND PACK.CubeUOM1 > 0 AND PACK.CaseCnt > 0 
                                          THEN (INSERTED.OpenQty * (PACK.CubeUOM1 / PACK.CaseCnt))
                                          WHEN @c_Authority_OrdWgtVol IN ( '1', '2' )
                                          THEN (INSERTED.OpenQty * SKU.STDCUBE)
                                          ELSE 0
                                          END), 0.00000)
              , @n_OpenQty = SUM(INSERTED.OpenQty) 
         FROM INSERTED 
         JOIN SKU   WITH (NOLOCK)   ON (INSERTED.StorerKey = SKU.StorerKey)
                                          AND(INSERTED.SKU = SKU.SKU)
         JOIN PACK  WITH (NOLOCK)   ON (SKU.Packkey = PACK.Packkey)
         WHERE INSERTED.OrderKey = @c_OrderKey  
 	   
         IF @c_Status NOT IN ('0','9','CANC')
         BEGIN
         	  SET @c_NewStatus = @c_Status --NJOW03
         	  
            EXEC ispGetOrderStatus
               @c_OrderKey = @c_OrderKey,
               @c_StorerKey = @c_StorerKey,
               @c_OrdType = @c_OrdType,
               @c_NewStatus = @c_NewStatus OUTPUT,
               @b_Success = @b_Success OUTPUT,
               @n_err = @n_Err OUTPUT,
               @c_errmsg = @c_ErrMsg OUTPUT 
         END
         ELSE 
         BEGIN
            SET @c_NewStatus = @c_Status
         END
      
         UPDATE ORDERS WITH (ROWLOCK)
         SET ORDERS.GrossWeight=CONVERT(FLOAT, CONVERT(DECIMAL(15,5), ORDERS.GrossWeight) + @n_Weight)                   
            ,ORDERS.Capacity   =CONVERT(FLOAT, CONVERT(DECIMAL(15,5), ORDERS.Capacity) + @n_CBM)
            ,ORDERS.OpenQty = ORDERS.OpenQty + @n_OpenQty
            ,ORDERS.TrafficCop = NULL
            ,ORDERS.Status = @c_NewStatus
            ,ORDERS.SOStatus = CASE WHEN ORDERS.SOStatus IN ('CANC') THEN '0' ELSE ORDERS.SOStatus END
            ,ORDERS.ECOM_Single_Flag =  ( CASE WHEN ORDERS.Status NOT IN ('9','CANC') AND ORDERS.DocType = 'E' THEN 
                                          (  CASE WHEN (ORDERS.OpenQty + @n_OpenQty ) > 1 THEN 'M' ELSE 'S' END )  
                                          ELSE ORDERS.ECOM_SINGLE_Flag END  )
            ,EditDate = GETDATE()
            ,EditWho = SUSER_SNAME()                
         WHERE ORDERS.OrderKey = @c_OrderKey
          
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62906  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                     +': Insert failed on table ORDERS. (ntrOrderDetailAdd)' + ' ( ' 
                     + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
            BREAK
         END            
      END -- IF (@n_Continue = 1 or @n_Continue=2)

      -- Comment this section, no one using this anymore.
      --IF @n_Continue = 1 OR @n_Continue = 2
      --BEGIN
      --   SELECT @b_Success = 0, 
      --          @c_Authority_OrdTLLog = '0'

      --   Execute nspGetRight @c_Facility, 
      --                       @c_StorerKey,   -- Storer
      --                       '',             -- Sku
      --                       'ORDTLLOG',     -- ConfigKey
      --                       @b_Success            OUTPUT, 
      --                       @c_Authority_OrdTLLog OUTPUT, 
      --                       @n_err                OUTPUT, 
      --                       @c_errmsg             OUTPUT

      --   IF @b_Success <> 1
      --   BEGIN
      --      Select @n_Continue = 3 
      --      SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      --      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve of Right (OrderStop) Failed (ntrOrderDetailAdd)' 
      --            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      --      BREAK
      --   END

      --   IF @c_Authority_OrdTLLog = '1' 
      --   BEGIN
      --      SELECT TOP 1 
      --             @c_OrderLineNumber=INSERTED.OrderLineNumber,
      --             @c_ExternOrderKey =INSERTED.ExternOrderKey 
      --        FROM INSERTED  
      --       WHERE INSERTED.OrderKey = @c_OrderKey
      --       ORDER BY INSERTED.OrderKey, INSERTED.OrderLineNumber
   
        
      --      EXEC ispGenTransmitLog
      --         @c_TableName = 'ORDERS',
      --         @c_Key1 = @c_OrderKey,
      --         @c_Key2 = @c_OrderLineNumber,
      --         @c_Key3 = @c_ExternOrderKey,
      --         @c_TransmitBatch = 'ORDERS',
      --         @b_Success = @b_Success OUTPUT,
      --         @n_err = @n_err OUTPUT,
      --         @c_errmsg = @c_errmsg OUTPUT
                      
      --       IF @b_Success <> 1
      --       BEGIN
      --           SELECT @n_Continue = 3
      --           SELECT @c_errmsg = CONVERT(CHAR(250), @n_err),
      --                  @n_err = 62901  
      --           SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5), @n_err)+
      --                  ': Insert Into Transmitlog Failed. (ntrOrderDetailAdd)' 
      --                 +'  ( '+' SQLSvr   MESSAGE=' + RTrim(@c_errmsg) 
      --                 +' ) '
      --          BREAK
      --       END
      --   END
      --END -- IF @n_Continue = 1 OR @n_Continue = 2
   
      ------- > START: SOS 28368 : set specialhandling on ORDERS header
      IF @n_Continue=1 or @n_Continue=2
      BEGIN
         Select @b_Success = 0, @c_authority = '0'

         Execute nspGetRight 
                     '', -- Facility 
                     @c_StorerKey, -- Storer
                     '', -- Sku
                     'PoisonOrderHandling', -- ConfigKey
                     @b_Success         OUTPUT, 
                     @c_authority      OUTPUT, 
                     @n_err             OUTPUT, 
                     @c_errmsg          OUTPUT

         IF @b_Success <> 1
         BEGIN
            Select @n_Continue = 3 
            SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Retrieve of Right (OrderStop) Failed (ntrOrderDetailAdd)' 
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
            BREAK
         END
      END   
   
      IF (@n_Continue = 1 or @n_Continue=2) AND @c_authority = '1'
      BEGIN
         IF @c_SpecialHandling NOT IN ('Y','N') 
         BEGIN
            -- IF SKU.busr8 has value update to Y
            IF EXISTS (SELECT 1 FROM SKU (NOLOCK) 
                        JOIN INSERTED ON SKU.Storerkey = INSERTED.Storerkey
                                     AND SKU.SKU = INSERTED.SKU
                        WHERE ( SKU.BUSR8 > '' AND SKU.BUSR8 IS NOT NULL )
                        AND INSERTED.OrderKey = @c_OrderKey)
            BEGIN
               UPDATE ORDERS WITH (ROWLOCK) 
               SET ORDERS.SpecialHandling = 'Y',
                   ORDERS.TrafficCop = NULL,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME() 
               FROM ORDERS   
               WHERE ORDERS.OrderKey = @c_OrderKey               
            END
            ELSE IF @c_SpecialHandling <> 'N'
            BEGIN
               UPDATE ORDERS  
               SET ORDERS.SpecialHandling = 'N',
                   ORDERS.TrafficCop = Null,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()  
               FROM ORDERS  
               WHERE ORDERS.OrderKey = @c_OrderKey              
            END
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_errmsg = CONVERT(VARCHAR(10),@n_err), @n_err=62907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Of Special Handling On ORDERS Failed (ntrOrderDetailAdd)' 
               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
               BREAK
            END         
         END
      END -- (@n_Continue = 1 or @n_Continue=2)

      FETCH FROM CUR_ORDHEADER INTO @c_OrderKey, @c_StorerKey, @c_Facility, @c_SpecialHandling, @c_Status, @c_SOStatus, @c_OrdType
   END

   CLOSE CUR_ORDHEADER
   DEALLOCATE CUR_ORDHEADER
END

/* #INCLUDE <TRODA2.SQL> */
IF @n_Continue=3  -- Error Occured - Process And Return
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

    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrOrderDetailAdd'
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


GO