SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_BackEndPickConfirm                             */
/* Purpose: Update PickDetail to Status 5 from backend                  */
/* Return Status: None                                                  */
/* Called By: SQL Schedule Job   BEJ - Backend Pick (All Storers)       */
/* Updates:                                                             */
/* Date         Author       Purposes                                   */
/* 2017-11-11  KHLim     1.1  Log UPDATE PICKDETAIL stmt details (KH01) */
/* 2017-11-12  KHLim     1.2  NSQLConfig to toggle logging mode  (KH02) */
/* 2018-11-20  TLTING    1.3  Smaller Batch                             */
/************************************************************************/
CREATE   PROCEDURE [dbo].[nsp_BackEndPickConfirm]
     @cStorerKey NVARCHAR(15)
   , @b_debug    INT = 0 -- Leong01
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickDetailKey  CHAR (10),
           @n_Continue       INT ,
           @n_cnt            INT,
           @n_err            INT,
           @c_ErrMsg         CHAR (255),
           @n_RowCnt         INT,
           @b_success        INT,
           @f_Status         INT,
           @c_AlertKey     char(18) --KH01
         , @nErrSeverity   INT
         , @dBegin         DATETIME
         , @nErrState      INT
         , @cHost          NVARCHAR(128)
         , @cModule        NVARCHAR(128)
         , @cSQL           NVARCHAR(4000)
         , @cValue         NVARCHAR(30)

   SELECT @n_continue=1
   SET @cModule   = ISNULL(OBJECT_NAME(@@PROCID),'')
   IF  @cModule = ''
      SET @cModule= 'nsp_BackEndPickConfirm'
   SET @cHost     = ISNULL(HOST_NAME(),'')

   SET @cValue    = ''     --KH02
   SELECT @cValue = LTRIM(RTRIM([NSQLValue]))
   FROM [dbo].[NSQLCONFIG] WITH (NOLOCK)
   WHERE ConfigKey='LOGnsp_BackEndPickConfirm'

   DECLARE @cLOT             NVARCHAR(10),
           @cLOC             NVARCHAR(10),
           @cID              NVARCHAR(18)

   IF @cStorerKey = '%'
   BEGIN
      DECLARE CUR_Confirmed_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT   TOP 5000
             PICKDETAIL.LOT,
             PICKDETAIL.Loc,
             PICKDETAIL.ID
      FROM  PICKDETAIL WITH (NOLOCK)
      JOIN  StorerConfig AS sc WITH (NOLOCK) ON sc.Storerkey = PICKDETAIL.Storerkey AND sc.ConfigKey='BackendPickConfirm' AND sc.SValue='1'
      WHERE PICKDETAIL.Status < '5'
      AND   PICKDETAIL.ShipFlag = 'P'
      AND   PICKDETAIL.ShipFlag IS NOT NULL
   END
   ELSE
   BEGIN
      DECLARE CUR_Confirmed_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  DISTINCT  TOP 5000
             PICKDETAIL.LOT,
             PICKDETAIL.Loc,
             PICKDETAIL.ID
      FROM  PICKDETAIL WITH (NOLOCK)
      JOIN  StorerConfig AS sc WITH (NOLOCK) ON sc.Storerkey = PICKDETAIL.Storerkey AND sc.ConfigKey='BackendPickConfirm' AND sc.SValue='1'
      WHERE PICKDETAIL.Status < '5'
      AND   PICKDETAIL.ShipFlag = 'P'
      AND   PICKDETAIL.ShipFlag IS NOT NULL
      AND   PICKDETAIL.Storerkey = @cStorerKey
   END

   OPEN CUR_Confirmed_PickDetail

   FETCH NEXT FROM CUR_Confirmed_PickDetail INTO @cLOT, @cLOC, @cID

   SELECT @f_status = @@FETCH_STATUS

   WHILE @f_status <> -1
   BEGIN
      SELECT @c_ErrMsg = '', @n_Err = 0, @n_cnt = 0, @nErrSeverity=0   --KH01
      BEGIN TRY
         SET @dBegin = GETDATE()
         IF @b_debug = 1   -- KHLim01
         BEGIN
            PRINT 'Updating PickDetail with LOT: ' + @cLOT + ' LOC: ' + @cLOC + ' ID: '+ @cID + '. Start at ' + CONVERT(CHAR(10), @dBegin, 108)
         END

         BEGIN TRAN
         SET @cSQL = --KH01
        'UPDATE PICKDETAIL WITH (ROWLOCK)
            SET Status = ''5'', EditDate = EditDate
         WHERE LOT = '''+@cLOT+'''
         AND   LOC = '''+@cLOC+'''
         AND   ID  = '''+@cID+'''
         AND   PICKDETAIL.Status < ''4''
         AND   ShipFlag = ''P'''

         UPDATE PICKDETAIL WITH (ROWLOCK)
            SET Status = '5', EditDate = EditDate
         WHERE LOT = @cLOT
         AND   LOC = @cLOC
         AND   ID  = @cID
         AND   PICKDETAIL.Status < '4'
         AND   ShipFlag = 'P'

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      END TRY
      BEGIN CATCH
         SET @n_Err        = ERROR_NUMBER()
         SET @c_ErrMsg     = ERROR_MESSAGE();
         SET @nErrSeverity = ERROR_SEVERITY();
         SET @nErrState    = ERROR_STATE();
      END CATCH


      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg='NSQL72806: Update Failed On Table PICKDETAIL. ('+@cModule+')' + ' ( SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         ROLLBACK TRAN
         --BREAK
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         COMMIT TRAN
         IF @b_debug = 1   -- KHLim01
         BEGIN
            PRINT 'Updated PickDetail with LOT ' + @cLOT + ' LOC ' + @cLOC + ' ID: '+ @cID + ' Start at ' + CONVERT(CHAR(10), @dBegin, 108) + ' End at ' + CONVERT(CHAR(10), Getdate(), 108)
         END
      END

      IF OBJECT_ID('ALERT','u') IS NOT NULL  --KH01
      BEGIN
         IF @cValue = '1' OR @n_err <> 0     --KH02
         BEGIN
            EXECUTE nspg_getkey 'LogEvent', 18, @c_AlertKey OUTPUT, '', '', ''
            INSERT ALERT(AlertKey,ModuleName,AlertMessage,Severity ,NotifyId,Status,ResolveDate,Resolution,Storerkey,Qty   ,  Lot,  Loc,  ID) --, UCCNo
            VALUES   (@c_AlertKey,@cModule  ,@c_ErrMsg ,@nErrSeverity,@cHost,@n_err,@dBegin    ,@cSQL   ,@cStorerKey,@n_cnt,@cLot,@cLoc,@cID)--,@c_PickDetailKey
         END
      END

      FETCH NEXT FROM CUR_Confirmed_PickDetail INTO @cLOT, @cLOC, @cID
      SELECT @f_status = @@FETCH_STATUS
   END -- While PickDetail Key

   CLOSE CUR_Confirmed_PickDetail
   DEALLOCATE CUR_Confirmed_PickDetail

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, @cModule
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
      RETURN
   END
END

GO