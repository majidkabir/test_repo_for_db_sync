SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: lsp_SOCancelOrderDetails                           */
/* Creation Date: 2024-08-22                                            */
/* Copyright: LFL                                                       */
/* Written by: PPA371                                                   */
/*                                                                      */
/* Purpose: UWP-20104 - To cancel multiple order details                */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 0.1                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/************************************************************************/
CREATE     PROC [WM].[lsp_SOCancelOrderDetails]
      @c_Orderkey             NVARCHAR(10)
   ,  @c_OrderLineNumber      nvarchar(5)
   ,  @b_Success              INT = 1           OUTPUT
   ,  @n_err                  INT = 0           OUTPUT
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'
   ,  @c_UserName             NVARCHAR(128) = ''
   ,  @n_ErrGroupKey          INT          = 0  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_StartTCnt      INT = @@TRANCOUNT
         ,  @n_Continue       INT = 1
         ,  @c_TableName      NVARCHAR(50)   = 'OrderDetail'
         ,  @c_SourceType     NVARCHAR(50)   = 'lsp_SOCancelOrderDetails'
         ,  @c_Refkey1        NVARCHAR(20)   = ''
         ,  @c_Refkey2        NVARCHAR(20)   = ''
         ,  @c_Refkey3        NVARCHAR(20)   = ''
         ,  @c_WriteType      NVARCHAR(50)   = ''
         ,  @n_LogWarningNo   INT            = 0
         ,  @c_CancelReasonEnabled NVARCHAR(3)
         ,  @c_StorerKey         NVARCHAR(15)
         ,  @c_CancelReasonCode  NVARCHAR(60)  = ''
         ,  @c_SOCancReasonCode  NVARCHAR(60)  = ''
         ,  @c_status            NVARCHAR(10)
         ,  @c_statusOH            NVARCHAR(10)

			,  @sql                 NVARCHAR(MAX) = ''
         ,  @c_orderlineNo       NVARCHAR(5)   = ''

         ,  @CUR_ERRLIST      CURSOR
         ,  @CUR_OD           CURSOR                                                --2024-09-09
   DECLARE  @t_WMSErrorList   TABLE
         (  RowID             INT            IDENTITY(1,1)
         ,  TableName         NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')
         )

   SET @b_Success = 1
   SET @n_Err     = 0

   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser]
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END

   SET @n_WarningNo = 0
   SET @n_ErrGroupKey = 0
   BEGIN TRAN
   BEGIN TRY

      SELECT @c_StorerKey=StorerKey, @c_SOCancReasonCode = ISNULL(cancelreasoncode,''), @c_statusOH=Status FROM ORDERS WITH (NOLOCK) WHERE OrderKey=@c_Orderkey
      SELECT @c_CancelReasonEnabled=ReasonCodeReqForSOCancel FROM StorerSODefault WITH (NOLOCK)  WHERE StorerKey = @c_storerKey

      IF (@c_statusOH='CANC')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 562607
            SET @c_ErrMsg= 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Order has been cancelled #:' + @c_Orderkey + '. (lsp_SOCancelOrderDetails)'
                              + ' |' + @c_Orderkey

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_Orderkey,@c_orderlineNo, '', 'ERROR', 0, @n_err, @c_errmsg)
            GOTO EXIT_SP
         END


      IF OBJECT_ID('tempdb..#OrderLineNumbers','u') IS NOT NULL
      BEGIN
         DROP TABLE #OrderLineNumbers;
      END

      IF OBJECT_ID('tempdb..#OrderDetail','u') IS NOT NULL
      BEGIN
         DROP TABLE #OrderDetail;
      END

      CREATE TABLE #OrderDetail(Orderkey NVARCHAR(10), OrderLineNumber NVARCHAR(5)
                              , CancelReasonCode NVARCHAR(60), [Status] NVARCHAR(10))

		CREATE TABLE #OrderLineNumbers(OrderLineNumber NVARCHAR(5), cancelreasoncode NVARCHAR(60), [Status] NVARCHAR(10))
      SET @sql = N'INSERT INTO #OrderLineNumbers '
               + ' SELECT OrderLineNumber, cancelreasoncode,Status '
               + ' FROM ORDERDETAIL (NOLOCK) where OrderKey=@c_Orderkey'

      IF (@c_OrderLineNumber <>'')
         SET @sql = @sql + N' AND orderlinenumber = @c_orderlinenumber '

      EXEC sp_executesql @sql
         , N'@c_orderlinenumber NVARCHAR(20), @c_Orderkey NVARCHAR(10)'
         , @c_orderlinenumber
         , @c_Orderkey

      SET @CUR_OD = CURSOR LOCAL FAST_FORWARD READ_ONLY
      FOR
         SELECT OrderLineNumber , CancelReasonCode , Status
         FROM #OrderLineNumbers
         ORDER BY OrderLineNumber

      OPEN @CUR_OD
      FETCH NEXT FROM @CUR_OD INTO @c_orderlineNo
                                 , @c_CancelReasonCode
                                 , @c_status
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
      BEGIN
         IF @c_CancelReasonEnabled = 'Yes' AND (ISNULL(@c_CancelReasonCode,'')='')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 562601
            SET @c_ErrMsg= 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Please select the cancel reason code for Line number #:' + @c_orderlineNo + '. (lsp_SOCancelOrderDetails)'
                              + ' |' + @c_orderlineNo

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_Orderkey,@c_orderlineNo, '', 'ERROR', 0, @n_err, @c_errmsg)
            GOTO EXIT_SP
         END

         IF EXISTS (select 1 from PICKDETAIL WITH (NOLOCK) where OrderKey=@c_Orderkey and OrderLineNumber=@c_orderlineNo)
         BEGIN
            SET @n_continue = 3
            SET @n_err = 562602
            SET @c_ErrMsg='NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Order detail is not in normal status for Line number #:' + @c_orderlineNo + '. (lsp_SOCancelOrderDetails)'
                           + ' |' + @c_orderlineNo

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_Orderkey,@c_orderlineNo, '', 'ERROR', 0, @n_err, @c_errmsg)
            GOTO EXIT_SP
         END

         IF (@c_status='CANC' AND @c_OrderLineNumber<>'')
         BEGIN
            SET @n_continue = 3
            SET @n_err = 562603
            SET @c_ErrMsg='NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Order details had been cancelled for Line number #:' + @c_orderlineNo + '. (lsp_SOCancelOrderDetails)'
                           + ' |' + @c_orderlineNo

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_Orderkey,@c_orderlineNo, '', 'ERROR', 0, @n_err, @c_errmsg)
            GOTO EXIT_SP
         END

         IF @n_continue = 1 AND @c_status <> 'CANC'
         BEGIN
            UPDATE #OrderLineNumbers SET [Status] = 'CANC'
            WHERE OrderLineNumber = @c_orderlineNo
         END

         FETCH NEXT FROM @CUR_OD INTO @c_orderlineNo
                                    , @c_CancelReasonCode
                                    , @c_status
      END
      CLOSE @CUR_OD
      DEALLOCATE @CUR_OD
      --DROP TABLE #OrderLineNumbers


     IF (@n_Continue=1)
      BEGIN
         IF @c_CancelReasonEnabled = 'Yes' AND @c_SOCancReasonCode = ''
         BEGIN
            INSERT INTO #OrderDetail
            SELECT od.Orderkey, od.OrderLineNumber, od.CancelReasonCode
                  , ISNULL(tod.[Status],od.[Status])
            FROM ORDERDETAIL od (NOLOCK)
            LEFT OUTER JOIN #OrderLineNumbers tod ON tod.OrderLineNumber = od.OrderLineNumber
            WHERE Orderkey = @c_Orderkey

            IF EXISTS (SELECT 1
                      FROM #OrderDetail WITH (NOLOCK)
                      WHERE Orderkey = @c_Orderkey
                      GROUP BY Orderkey
                      HAVING COUNT(1) = SUM(CASE WHEN [Status] = 'CANC' THEN 1 ELSE 0 END)
                     )
            BEGIN
               SELECT TOP 1 @c_SOCancReasonCode = CancelReasonCode
               FROM #OrderDetail (NOLOCK)
               WHERE [Status] = 'CANC'
               ORDER BY OrderLinenumber

               IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
                              WHERE ListName = 'OHCANC'
                              AND Code = @c_SOCancReasonCode
                              AND Storerkey = @c_StorerKey
                              )
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 562604
                  SET @c_ErrMsg ='NSQL' + CONVERT(CHAR(6), @n_err)
                                + ': Cancel reason code mismatch'
                                + '. Please select another cancel reason code for'
                                + ' order:' + @c_Orderkey + '. (lsp_SOCancelOrderDetails)'
                                + ' |' + @c_Orderkey

                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
                  VALUES (@c_TableName, @c_SourceType, @c_Orderkey,@c_orderlineNo, '', 'ERROR', 0, @n_err, @c_errmsg)
                  GOTO EXIT_SP
               END

               UPDATE ORDERS WITH (ROWLOCK)
                  SET CancelReasonCode = @c_SOCancReasonCode
                     ,TrafficCop = NULL
               WHERE Orderkey = @c_Orderkey
               AND (CancelReasonCode = '' OR CancelReasonCode IS NULL)

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 562605
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': UPDATE Orderdetail fail. (lsp_SOCancelOrderDetails)'
                                 + '(' + @c_ErrMsg + ')'

                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
                  VALUES (@c_TableName, @c_SourceType, @c_Orderkey, @c_OrderLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)
               END
            END
         END
      END


      IF @n_Continue = 1
      BEGIN
         SET @sql = N'UPDATE ORDERDETAIL WITH (ROWLOCK)'
                  + ' SET Status=''CANC'''
                  + ' WHERE OrderKey=@c_Orderkey'

			IF(@c_OrderLineNumber<>'')
            SET @sql = @sql + N' AND orderlinenumber = @c_orderlinenumber '

         EXEC sp_executesql @sql
         , N'@c_orderlinenumber NVARCHAR(20), @c_Orderkey NVARCHAR(10)'
         , @c_orderlinenumber
         , @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 562606
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': UPDATE Orderdetail fail. (lsp_SOCancelOrderDetails)'
                           + '(' + @c_ErrMsg + ')'

            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
            VALUES (@c_TableName, @c_SourceType, @c_Orderkey, @c_OrderLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)
         END
      END

      IF @n_continue = 1
      BEGIN
         SET @c_errmsg = 'Order detail is cancelled for Line number: '+@c_OrderLineNumber+'.'
         IF(@c_OrderLineNumber='')
         BEGIN
            SET @c_errmsg = 'Order details are cancelled for Order key: '+@c_Orderkey+'.'
         END

         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
         VALUES (@c_TableName, @c_SourceType, @c_Orderkey, @c_OrderLineNumber, '', 'MESSAGE', 0, @n_err, @c_errmsg)
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()

      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)
      VALUES (@c_TableName, @c_SourceType, @c_Orderkey, @c_OrderLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)

      GOTO EXIT_SP
   END CATCH

EXIT_SP:
 IF OBJECT_ID('tempdb..#OrderLineNumbers','u') IS NOT NULL
   BEGIN
      DROP TABLE #OrderLineNumbers;
   END

   IF OBJECT_ID('tempdb..#OrderDetail','u') IS NOT NULL
   BEGIN
      DROP TABLE #OrderDetail;
   END

   IF (XACT_STATE()) = -1
   BEGIN
      SET @n_Continue=3
      ROLLBACK TRAN
   END


   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_SOCancelOrderDetails'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END


   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName
         ,  twl.SourceType
         ,  twl.Refkey1
         ,  twl.Refkey2
         ,  twl.Refkey3
         ,  twl.WriteType
         ,  twl.LogWarningNo
         ,  twl.ErrCode
         ,  twl.Errmsg
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID

   OPEN @CUR_ERRLIST

   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                     , @c_SourceType
                                     , @c_Refkey1
                                     , @c_Refkey2
                                     , @c_Refkey3
                                     , @c_WriteType
                                     , @n_LogWarningNo
                                     , @n_Err
                                     , @c_Errmsg

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List]
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_err
      ,  @c_errmsg2     = @c_errmsg
      ,  @b_Success     = @b_Success
      ,  @n_err         = @n_err
      ,  @c_errmsg      = @c_errmsg

      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName
                                        , @c_SourceType
                                        , @c_Refkey1
                                        , @c_Refkey2
                                        , @c_Refkey3
                                        , @c_WriteType
                                        , @n_LogWarningNo
                                        , @n_Err
                                        , @c_Errmsg
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   REVERT
END
GO