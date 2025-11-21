SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Trigger: ntrWaveDetailAdd                                                  */
/* Creation Date:                                                             */
/* Copyright: IDS                                                             */
/* Written by:                                                                */
/*                                                                            */
/* Purpose:                                                                   */
/*                                                                            */
/* Input Parameters: NONE                                                     */
/*                                                                            */
/* OUTPUT Parameters: NONE                                                    */
/*                                                                            */
/* Return Status: NONE                                                        */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/* Local Variables:                                                           */
/*                                                                            */
/* Called By: When records Insert                                             */
/*                                                                            */
/* PVCS Version: 1.5                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */
/* 05-Feb-2013  Shong      1.1   Do not Allow Blank OrderKey                  */
/* 30-AUG-2018  SPChin     1.2   INC0349006 - Remove WaveKey From PickDetail  */
/*                                            When Delete                     */
/* 24-MAY-2022  LZG        1.3   JSM-69426 - Calculate Wave status when       */
/*                               adding order into WaveDetail (ZG01)          */
/* 20-OCT-2022  NJOW01     1.4   WMS-21042 call custom stored proc            */
/* 20-OCT-2022  NJOW01     1.4   DEVOPS Combine Script                        */
/* 23-Nov-2022  Wan01      1.5   LFWM-3861 - CN Loreal build Wave performance */
/*                               enhancement and Calculate Wave Status when   */
/*                               wave detail's orderkey change/remove         */ 
/* 26-OCT-2023  Wan02      1.6   LFWM-4529 - PROD-CNWAVE Release group        */
/*                               search slow and build wave slow              */
/*                               - By Pass Trigger if Trafficcop = '9'        */
/* 05-DEC-2023  Wan03      2.1   LFWM-4625 - CLONE - PROD-CNWAVE Release      */
/*                               group search slow and build wave slow        */
/*                               By Pass Trigger if Trafficcop = ''(optimization)*/
/******************************************************************************/
CREATE   TRIGGER [dbo].[ntrWaveDetailAdd]
ON [dbo].[WAVEDETAIL]
FOR  INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     INT -- Populated by calls to stored procedures - was the proc successful?
          ,@n_err         INT -- Error number returned by stored procedure or this trigger
          ,@n_err2        INT -- For Additional Error Detection
          ,@c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure or this trigger
          ,@n_continue    INT
          ,@n_starttcnt   INT -- Holds the current transaction count
          ,@c_preprocess  NVARCHAR(250) -- preprocess
          ,@c_pstprocess  NVARCHAR(250) -- post process
          ,@n_cnt         INT
          ,@c_wavekey     NVARCHAR(10)
          ,@c_OrderKey    NVARCHAR(10) --INC0349006

          ,@c_Status_ORD      NVARCHAR(10)   = '0'                -- (Wan01)
          ,@c_Status_Wav      NVARCHAR(10)   = '0'                -- (Wan01)
          ,@c_WaveKey_Prior   NVARCHAR(10)   = ''                 -- (Wan01)

   SET @c_wavekey  = '' --INC0349006
   SET @c_OrderKey = '' --INC0349006

   SELECT @n_continue = 1
         ,@n_starttcnt = @@TRANCOUNT
   /* #INCLUDE <TROHA1.SQL> */
   IF @n_continue = 1 OR @n_continue = 2                                            --(Wan02) - START
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED WHERE TrafficCop IS NOT NULL)
      BEGIN
         UPDATE w WITH (ROWLOCK)
            SET w.TrafficCop = NULL
               ,w.ArchiveCop = w.ArchiveCop
         FROM INSERTED
         JOIN dbo.WAVEDETAIL AS w ON w.WaveDetailKey = Inserted.WaveDetailKey
         AND w.TrafficCop IS NOT NULL
         AND w.TrafficCop <> ''                                                     --(Wan03)
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 62302
            SET @c_ErrMsg   = 'NSQL'+CONVERT(char(5),@n_err)
                            +': Update failed On Wavedetail. (ntrWaveDetailAdd)'      
         END
         ELSE     
            SET @n_continue = 4       
      END  
   END                                                                              --(Wan02) - END   

   -- Added by Jeff - HK Customization - FBR 071 - Wave Planning
   -- reject any population of orders with status = 'shipped'
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
       IF EXISTS (
              SELECT 1
              FROM   INSERTED
                    ,ORDERS(NOLOCK)
              WHERE  ORDERS.Orderkey = INSERTED.Orderkey
              AND    ORDERS.Status IN ('8' ,'9')
          )
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 62301 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) +
                  ': Shipped Orders cannot be populated into WaveDetail. (ntrWaveDetailAdd)'
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') +
                  ' ) '
       END
   END
   -- Added by SHONG - Do not allow Blank OrderKey
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
      IF EXISTS (
             SELECT 1
             FROM   INSERTED
             WHERE  OrderKey = ''
             OR     OrderKey IS NULL
         )
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 62301 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) +
                 ': Insert Failed, OrderKey BLANK. (ntrWaveDetailAdd)' + ' ( '
                 + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
      END
   END
   -- reject if user manually inserts orders that has already been waved
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
       IF EXISTS (
              SELECT 1
              FROM   INSERTED
                    ,ORDERS(NOLOCK)
              WHERE  ORDERS.Orderkey = INSERTED.Orderkey
              AND    (ORDERS.Userdefine09 IS NOT NULL)
              AND    (ORDERS.Userdefine09 <> '')
          )
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 62301 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) +
                  ': Orders have been waved.(ntrWaveDetailAdd)' + ' ( ' +
                  ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
       END
   END
   -- reject manual type orders ('M'): SOS 4565
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
       IF EXISTS (
              SELECT 1
              FROM   INSERTED
                    ,ORDERS(NOLOCK)
              WHERE  ORDERS.Orderkey = INSERTED.Orderkey
              AND    ORDERS.type = 'M'
          )
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 62301 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) +
                  ': Manual Orders cannot be waved.(ntrWaveDetailAdd)' + ' ( ' +
                  ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
       END
   END

   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN
       UPDATE ORDERS
       SET    ORDERS.USERDEFINE09 = INSERTED.WaveKey
             ,TRAFFICCOP = NULL
       FROM   ORDERS
             ,INSERTED
       WHERE  ORDERS.Orderkey = INSERTED.Orderkey
       AND    (ORDERS.Status <> '8' OR ORDERS.Status <> '9')

       SELECT @n_err = @@ERROR
             ,@n_cnt = @@ROWCOUNT

       IF @n_err <> 0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 62301 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) +
                  ': Insert Failed On WaveDetail. (ntrWaveDetailAdd)' + ' ( ' +
                  ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
       END
   END

   --INC0349006 Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_Wv_Cur_Status NVARCHAR(10) = ''
      DECLARE CUR_Wave_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT I.WaveKey, I.OrderKey, w.[Status], o.[Status]              --(Wan01)
      FROM INSERTED I
      JOIN ORDERS O WITH (NOLOCK) ON I.OrderKey = O.OrderKey
      JOIN dbo.WAVE AS w WITH (NOLOCK) ON I.WaveKey = w.WaveKey                  --(Wan01)
      ORDER BY I.WaveKey, o.[Status]

      OPEN CUR_Wave_Orders
      FETCH NEXT FROM CUR_Wave_Orders INTO @c_wavekey, @c_OrderKey
                                          ,@c_Wv_Cur_Status, @c_Status_ORD       --(Wan01)

      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN ( 1, 2 )                     --(Wan01)
      BEGIN
         IF EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK)
                    WHERE OrderKey = @c_OrderKey)
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET WAVEKEY    = @c_wavekey
              , TRAFFICCOP = NULL
            WHERE Orderkey = @c_OrderKey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                                 , @n_err = 62309 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) +
                                  ': Insert Failed On WaveDetail. (ntrWaveDetailAdd)' + ' ( ' +
                                  ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
            END
         END

         IF @n_continue = 1                                                      --(Wan01) - START
         BEGIN
            IF @c_WaveKey_Prior <> @c_Wavekey                                        
            BEGIN
               SET @c_Status_Wav = @c_Wv_Cur_Status
            END  
             
            IF @c_Status_ORD BETWEEN '0' AND '5' AND
            1 = CASE WHEN @c_Status_Wav = '0' AND @c_Status_ORD > '0' THEN 1              
                     WHEN @c_Status_Wav = '2' AND @c_Status_ORD < '2' THEN 1
                     WHEN @c_Status_Wav = '5' AND @c_Status_ORD < '5' THEN 1  
                     ELSE 0
                     END                    

            SET @c_Status_Wav = IIF (@c_Status_ORD IN (3,4), '2', @c_Status_ORD)
  
            IF @c_Wv_Cur_Status <> @c_Status_Wav
            BEGIN
               UPDATE dbo.WAVE WITH (ROWLOCK)
                  SET [Status] = @c_Status_Wav      
                  ,   EditWho  = SUSER_SNAME()      
                  ,   EditDate = GETDATE()      
                  ,   TrafficCop = NULL 
               WHERE WaveKey = @c_wavekey 
               AND [Status] = @c_Status_Wav         
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3      
                  SET @n_Err      = 67890      
                  SET @c_ErrMsg   = ERROR_MESSAGE()      
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update WAVE Table fail. (ntrWaveDetailAdd)'      
                                  + '( ' + @c_ErrMsg + ' )'      
               END
            END
            -- ZG01 (Start)
            --EXEC [dbo].[isp_GetWaveStatus]
            --    @c_WaveKey    = @c_WaveKey
            -- ,  @b_UpdateWave = 1                         --1 => yes, 0 => No
            -- ,  @c_Status     = @c_Status_Wav    OUTPUT                          
            -- ,  @b_Success    = @b_Success       OUTPUT
            -- ,  @n_Err        = @n_Err           OUTPUT
            -- ,  @c_ErrMsg     = @c_ErrMsg        OUTPUT
         
            --IF @b_Success = 0
            --BEGIN
            --   SET @n_continue = 3
            --END
            ---- ZG01 (End)
         END                                                                      
         SET @c_WaveKey_Prior = @c_Wavekey                                       --(Wan01) - END
         
         FETCH NEXT FROM CUR_Wave_Orders INTO @c_wavekey, @c_OrderKey
                                             ,@c_Wv_Cur_Status, @c_Status_ORD    --(Wan01)
      END
      CLOSE CUR_Wave_Orders
      DEALLOCATE CUR_Wave_Orders
   END
   --INC0349006 End
   
   --NJOW01
   IF @n_continue=1 or @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED i
                 JOIN ORDERS       o WITH (NOLOCK) ON i.OrderKey = o.OrderKey
                 JOIN storerconfig s WITH (NOLOCK) ON o.StorerKey = s.StorerKey
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'WaveDetailTrigger_SP')
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

         EXECUTE dbo.isp_WaveDetailTrigger_Wrapper
                   'INSERT'  --@c_Action
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrWaveDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END   

   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
       IF @@TRANCOUNT = 1
       AND @@TRANCOUNT >= @n_starttcnt
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
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWaveDetailAdd'
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
END


GO