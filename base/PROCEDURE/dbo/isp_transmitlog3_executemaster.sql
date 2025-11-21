SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Transmitlog3_ExecuteMaster                     */
/* Creation Date: 21 Aug 2014                                           */
/* Copyright: LFL                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver      Purposes                              */
/************************************************************************/

CREATE PROC [dbo].[isp_Transmitlog3_ExecuteMaster](
    @cTableName      NVARCHAR(30)
   ,@cKey3           NVARCHAR(20)
   ,@bDebug          INT = 0   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE
      @cExpSP           NVARCHAR(250),
      @cSQL             NVARCHAR(1000),
      @cSQLParam        NVARCHAR(1000),
      @cTransmitlogKey  NVARCHAR(10),
      @cKey1            NVARCHAR(10),
      @cKey2            NVARCHAR(5),
      @cTransmitBatch   NVARCHAR(30),
      @bSuccess         INT,
      @nErr             INT,
      @cErrMsg          NVARCHAR(250)

   SELECT @cExpSP = Long
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME  = 'TLOG3ExtSP'
     AND Code      = @cTableName
     AND StorerKey = @cKey3

   IF @bDebug = 1
      PRINT @cExpSP

   IF ISNULL(@cExpSP, '') <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExpSP AND type = 'P')
   BEGIN
      IF @bDebug = 1
         PRINT 'Start >> ' + @cTableName + ', ' + @cKey3 

      /*********************************************/
      /* Std - Update Transmitflag to '1' (Start)  */
      /*********************************************/

      BEGIN TRAN

      UPDATE dbo.TRANSMITLOG3 with (ROWLOCK)
      SET transmitflag   = '1'
      WHERE tablename    = @cTableName
      AND   key3         = @cKey3
      AND   transmitflag = '0'

      IF @@error <> 0
      BEGIN
         UPDATE dbo.TRANSMITLOG3 with (ROWLOCK)
         SET transmitflag   = '5'
         WHERE tablename    = @cTableName
         AND   key3         = @cKey3
         AND   transmitflag = '0'
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      /*********************************************/
      /* Std - Update Transmitflag to '1' (End)    */
      /*********************************************/

      DECLARE C_TransmitLog3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TransmitLogKey, Key1, Key2, TransmitBatch
      FROM dbo.TransmitLog3 WITH (NOLOCK)
      WHERE TableName = @cTableName
        AND Key3 = @cKey3
        AND TransmitFlag = '1'

      OPEN C_TransmitLog3
      FETCH NEXT FROM C_TransmitLog3 INTO @cTransmitLogKey, @cKey1, @cKey2, @cTransmitBatch

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @bSuccess=1, @nErr=0, @cErrMsg=''
         IF @bDebug = 1
            PRINT @cTableName + ', ' + @cTransmitLogKey + ',' + @cKey1 + ', ' + @cKey2 + ', ' + @cKey3 + ', ' + @cTransmitBatch

         SET @cSQL = 'EXEC ' + RTRIM( @cExpSP) +
            ' @cTransmitlogKey, @cTableName, @cKey1, @cKey2, @cKey3, @cTransmitBatch, ' +
            ' @bSuccess OUTPUT, @nErr OUTPUT, @cErrMsg OUTPUT'

         SET @cSQLParam =
            '@cTransmitlogKey  NVARCHAR(10), ' +
            '@cTableName       NVARCHAR(30), ' +
            '@cKey1            NVARCHAR(10), ' +
            '@cKey2            NVARCHAR(5),  ' +
            '@cKey3            NVARCHAR(20), ' +
            '@cTransmitBatch   NVARCHAR(30), ' +
            '@bSuccess         INT           OUTPUT, ' +
            '@nErr             INT           OUTPUT, ' +
            '@cErrMsg          NVARCHAR(250) OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                            @cTransmitlogKey, @cTableName, @cKey1, @cKey2, @cKey3, @cTransmitBatch,
                            @bSuccess OUTPUT, @nErr OUTPUT, @cErrMsg OUTPUT

         IF @@ERROR <> 0
         BEGIN
            SET @bSuccess = 0
            SET @nErr = 10000
            SET @cErrMsg = 'Failed to Exec ' + @cExpSP
         END

         IF @bDebug = 1
            PRINT CAST(@bSuccess AS NVARCHAR) + ', ' + CAST(@nErr AS NVARCHAR) + ', ' + @cErrMsg

         /*********************************************/
         /* Std - Update Transmitflag to '9' (Start)  */
         /*********************************************/

         BEGIN TRAN

         IF @nErr <> 0
         BEGIN
            UPDATE dbo.TRANSMITLOG3 with (ROWLOCK)
            SET transmitflag   = '5'
            WHERE tablename    = @cTableName
            AND   key1         = @cKey1
            AND   key2         = ''
            AND   key3         = @cKey3
            AND   transmitflag = '1'
         END
         ELSE
         BEGIN
            UPDATE dbo.TRANSMITLOG3 with (ROWLOCK)
            SET transmitflag   = '9'
            WHERE tablename    = @cTableName
            AND   key1         = @cKey1
            AND   key2         = ''
            AND   key3         = @cKey3
            AND   transmitflag = '1'
         END

         COMMIT TRAN

         /*********************************************/
         /* Std - Update Transmitflag to '9' (End)    */
         /*********************************************/

         FETCH NEXT FROM C_TransmitLog3 INTO @cTransmitLogKey, @cKey1, @cKey2, @cTransmitBatch
      END
      CLOSE C_TransmitLog3
      DEALLOCATE C_TransmitLog3

      /*********************************************/
      /* Std - Update Transmitflag to '9' (Start)  */
      /*********************************************/

      BEGIN TRAN

      IF @nErr <> 0
      BEGIN
         UPDATE dbo.TRANSMITLOG3 with (ROWLOCK)
         SET transmitflag   = '5'
         WHERE tablename    = @cTableName
         AND   key3         = @cKey3
         AND   transmitflag = '1'
      END
      ELSE
      BEGIN
         UPDATE dbo.TRANSMITLOG3 with (ROWLOCK)
         SET transmitflag   = '9'
         WHERE tablename    = @cTableName
         AND   key3         = @cKey3
         AND   transmitflag = '1'
      END

      COMMIT TRAN

      /*********************************************/
      /* Std - Update Transmitflag to '9' (End)    */
      /*********************************************/

      IF @bDebug = 1
         PRINT 'End   >> ' + @cTableName + ', ' + @cKey3

   END -- IF ISNULL(@cExpSP, '') <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExpSP AND type = 'P')

END -- Procedure

GO