SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspLoadReleasePickTask_Wrapper                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 28-Mar-2012  NJOW01   1.0  238872-Allow to handle MULTI-STORER       */
/* 17-Oct-2014  NJOW02   1.1  314930-Update wave status and order       */
/*                            sostatus to release                       */
/* 30-OCT-2015  NJOW03   1.2  fix Capture error from called SP          */
/* 01-AUG-2017  NJOW04   1.3  fix Catpure error msg from called sp      */
/* 22-JUL-2022  NJOW05   1.4  fix allow BuildLoadReleaseTask_SP config  */
/*                            SP execute at load plan RCM               */
/************************************************************************/
CREATE PROCEDURE [dbo].[nspLoadReleasePickTask_Wrapper]
   @c_loadkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_AllowAllocate int
   DECLARE @i_success       integer,
           @i_error         integer,
           @c_ErrMsg        NVARCHAR(512),
           @n_starttcnt     INT,
           @nPrePackAlloc   INT,
           @cProcessFlag    NVARCHAR(1),
           @n_continue            INT,
           @n_Err                 INT,
           @c_StorerKey           NVARCHAR(15),
           @c_ReleasePickTaskCode NVARCHAR(30),
           @c_SQL                 NVARCHAR(MAX),
           @c_NoConfigStorerkey   NVARCHAR(15), --NJOW01
           @c_authority           NVARCHAR(10), --NJOW02
           @b_Success             INT = 1 --NJOW05

   SET @n_starttcnt = @@TRANCOUNT

   SELECT @cProcessFlag = ProcessFlag
   FROM LoadPlan lp WITH (NOLOCK)
   WHERE lp.LoadKey = @c_loadkey

   IF @cProcessFlag = 'L'
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
             @n_Err = 81001 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
             ': This Load is Currently Being Processed!' + ' ( ' +
             ' SQLSvr MESSAGE=' + @c_ErrMsg +
             ' ) '
      GOTO QUIT_SP
   END
--   ELSE
--   IF @cProcessFlag = 'Y'
--   BEGIN
--      SELECT @n_continue = 3
--      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
--             @n_Err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
--             ': Pick Tasks Have Been Released!' + ' ( ' + ' SQLSvr MESSAGE=' +
--             @c_ErrMsg + ' )'
--      GOTO QUIT_SP
--   END


   IF (SELECT COUNT(1)
       FROM LOADPLANDETAIL (NOLOCK)
       JOIN PICKDETAIL (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey)
       WHERE LOADPLANDETAIL.Loadkey = @c_loadkey) = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
             @n_Err = 81007 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
             ': Load Plan Not Allocated Yet' + ' ( ' + ' SQLSvr MESSAGE=' +
             @c_ErrMsg + ' )'
      GOTO QUIT_SP
   END

   --NJOW01
   SELECT TOP 1 @c_NoConfigStorerkey = O.Storerkey
   FROM LoadPlanDetail LD (NOLOCK)
   JOIN Orders O (NOLOCK) ON LD.Orderkey = O.Orderkey
   WHERE NOT EXISTS (SELECT * FROM Storerconfig SC (NOLOCK) WHERE O.Storerkey = SC.Storerkey AND SC.Configkey = 'ReleasePickTaskCode' AND LEN(ISNULL(SC.Svalue,'')) > 1)
   AND LD.Loadkey = @c_Loadkey

   IF ISNULL(@c_NoConfigStorerkey,'') <> ''
   BEGIN
       SELECT @n_continue = 3
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 81012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
              ': Please Setup Pick Task Strategy Code into Storer Configuration(ReleasePickTaskCode) For Storer ' +RTRIM(@c_NoConfigStorerkey) +' (nspLoadReleasePickTask_Wrapper)'
       GOTO QUIT_SP
   END

   --NJOW02 Start
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   BEGIN TRAN

   UPDATE LOADPLAN WITH (ROWLOCK)
   SET ProcessFlag = 'L',
       TrafficCop = NULL
   WHERE LoadKey = @c_loadkey

   SELECT @n_err = @@ERROR
   IF @n_err<>0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
            ,@n_err = 81013 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
             ': Update of LoadPlan Failed (nspLoadReleasePickTask_Wrapper)'+' ( '
            +' SQLSvr MESSAGE='+@c_ErrMsg
            +' ) '
      GOTO QUIT_SP
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN

      BEGIN TRAN
   END
   --NJOW02 End

   DECLARE CUR_Storer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT O.Storerkey
      FROM LoadPlanDetail LD (NOLOCK)
      JOIN Orders O (NOLOCK) ON LD.Orderkey = O.Orderkey
      WHERE LD.Loadkey = @c_Loadkey
      ORDER BY O.Storerkey

   OPEN CUR_Storer
   FETCH NEXT FROM CUR_Storer INTO @c_StorerKey

   WHILE (@@FETCH_STATUS<>-1)   --NJOW01
   BEGIN
      SET @c_ReleasePickTaskCode = ''

      /*
      SELECT TOP 1
             @c_StorerKey = o.StorerKey
      FROM LoadPlanDetail lpd WITH (NOLOCK)
      JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey
      WHERE lpd.LoadKey = @c_loadkey
      ORDER BY lpd.LoadLineNumber
      */

      SELECT @c_ReleasePickTaskCode = sVALUE
      FROM   StorerConfig WITH (NOLOCK)
      WHERE  StorerKey = @c_StorerKey
      AND    ConfigKey = 'ReleasePickTaskCode'

      IF ISNULL(RTRIM(@c_ReleasePickTaskCode),'') =''
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
                 @n_Err = 81002 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
                 ': Please Setup Pick Task Strategy Code into Storer Configuration. (nspLoadReleasePickTask_Wrapper)'
          GOTO QUIT_SP
      END
      
      IF EXISTS (SELECT 1
                 FROM [INFORMATION_SCHEMA].[PARAMETERS] 
                 WHERE SPECIFIC_NAME = @c_ReleasePickTaskCode
                 AND PARAMETER_NAME = '@b_Success')  --NJOW05 allow BuildLoadReleaseTask_SP config SP execute at load plan RCM
      BEGIN  
         SET @c_SQL = 'EXEC ' + @c_ReleasePickTaskCode + ' @c_LoadKey=@c_LoadKey, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT, @c_Storerkey=@c_Storerkey'  --NJOW01
         
         -- SELECT @c_SQL '@c_SQL'
         
         EXEC sp_executesql @c_SQL,
              N'@c_LoadKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT, @c_Storerkey NVARCHAR(15)',
              @c_LoadKey,
              @b_Success OUTPUT,
              @n_Err OUTPUT,
              @c_ErrMsg OUTPUT,
              @c_Storerkey  --NJOW01      	
      END
      ELSE
      BEGIN      	
         SET @c_SQL = 'EXEC ' + @c_ReleasePickTaskCode + ' @c_LoadKey=@c_LoadKey, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT, @c_Storerkey=@c_Storerkey'  --NJOW01
         
         -- SELECT @c_SQL '@c_SQL'
         
         EXEC sp_executesql @c_SQL,
              N'@c_LoadKey NVARCHAR(10), @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT, @c_Storerkey NVARCHAR(15)',
              @c_LoadKey,
              @n_Err OUTPUT,
              @c_ErrMsg OUTPUT,
              @c_Storerkey  --NJOW01
      END     

      --SELECT @n_Err = @@ERROR
      IF @n_Err <> 0 OR @@ERROR <> 0 --NJOW03
         OR @b_Success = 0 --NJOW05
      BEGIN
      	  SELECT @n_continue = 3
          --SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
          SELECT @n_Err = 81002 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +
                 ': Execute Release Pick Task Failed (nspLoadReleasePickTask_Wrapper)' + ' ( '
                 + ' SQLSvr MESSAGE=' + @c_ErrMsg
                 + ' ) '
          GOTO QUIT_SP
      END
      ELSE
      BEGIN
         --NJOW02
   	     EXECUTE nspGetRight
            '',
            @c_StorerKey,
            '', --sku
            'UpdateSOReleaseTaskStatus', -- Configkey
            @i_success    OUTPUT,
            @c_authority  OUTPUT,
            @n_err        OUTPUT,
            @c_errmsg     OUTPUT

         IF @i_success = 1 AND @c_authority = '1'
         BEGIN
         	  UPDATE ORDERS WITH (ROWLOCK)
         	  SET SOStatus = 'TSRELEASED',
         	      TrafficCop = NULL,
         	      EditWho = SUSER_SNAME(),
         	      EditDate = GETDATE()
         	  WHERE Loadkey = @c_Loadkey
         	  AND Storerkey = @c_Storerkey
         END
      END

      FETCH NEXT FROM CUR_Storer INTO @c_StorerKey --NJOW01
   END

   CLOSE CUR_Storer
   DEALLOCATE CUR_Storer

   QUIT_SP:

   --NJOW02 Start
   IF @n_continue = 3
   BEGIN
   	  WHILE @@TRANCOUNT > 0
     	  ROLLBACK TRAN

   	  BEGIN TRAN

      UPDATE LOADPLAN WITH (ROWLOCK)
      SET ProcessFlag = CASE WHEN @cProcessFlag = 'Y' THEN 'Y' ELSE 'N' END,
          TrafficCop = NULL
      WHERE LoadKey = @c_loadkey
      --AND @cProcessFlag <> 'L'

      WHILE @@TRANCOUNT > 0
         COMMIT TRAN

      WHILE @@TRANCOUNT < @n_starttcnt
          BEGIN TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT < @n_starttcnt
          BEGIN TRAN

      UPDATE LOADPLAN WITH (ROWLOCK)
      SET ProcessFlag = 'Y',
          TrafficCop = NULL
      WHERE LoadKey = @c_loadkey

      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
   --NJOW02 End

   IF @n_continue = 3
   BEGIN
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'nspLoadReleasePickTask_Wrapper'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
END

GO