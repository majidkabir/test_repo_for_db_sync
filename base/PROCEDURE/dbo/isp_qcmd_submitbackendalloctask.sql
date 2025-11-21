SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_QCmd_SubmitBackendAllocTask                    */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 2017-10-19   Shong   1.1   Fix Infinite Loop                         */
/* 2017-10-30   Shong   1.2   Change Sorting order by Priority (SWT01)  */
/*                            Do not allow to allocate same SKU at      */
/*                            time                                      */
/* 2018-09-29   TLTING  1.3   Remove #tmp and remove row lock           */
/* 2018-10-18   SHONG   1.4   Revise Priority                           */
/* 2019-05-16   SHONG   1.5   Bug Fixing                                */
/* 06-May-2020  Shong   1.6   Addding Priority to Q-Cmd Task (SWT02)    */
/* 15-Jun-2022  SYCHUA  1.7   JSM-74630 - Align Datastream name (SY01)  */
/************************************************************************/
CREATE PROC [dbo].[isp_QCmd_SubmitBackendAllocTask] (
     @bSuccess      INT = 1            OUTPUT
   , @nErr          INT = ''           OUTPUT
   , @cErrMsg       NVARCHAR(250) = '' OUTPUT
   , @bDebug        INT = 0
   , @nMaxQCmdTask  INT = 6000
   , @nMaxRunningDuration INT = 5
   , @bForceOriginalPeriority INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @cStorerKey NVARCHAR(15)
           ,@cFacility NVARCHAR(5)
           ,@nSuccess INT
           ,@cErrorMsg NVARCHAR(256)
           ,@cSQLSelect NVARCHAR(MAX)
           ,@cSQLCondition NVARCHAR(MAX)
           ,@cBatchNo NVARCHAR(10)
           ,@nWherePosition INT
           ,@nGroupByPosition INT
           ,@cSQLParms NVARCHAR(1000)
           ,@nAllocBatchNo BIGINT
           ,@nOrderCnt INT
           ,@nErrNo INT
           ,@cSKU NVARCHAR(20)
           ,@nPrevAllocBatchNo BIGINT
           ,@dOrderAddDate DATETIME
           ,@cCommand NVARCHAR(2014)
           ,@cAllocBatchNo NVARCHAR(10)
           ,@cAllocStrategy NVARCHAR(200)
           ,@nNextAllocBatchNo BIGINT
           ,@nBL_Priority INT=0
           ,@nTaskSeqNo INT=0
           ,@nRowID INT=0
           ,@nSafetyAllocOrders INT=0
           ,@nTaskPriority INT=0
           ,@nRevisePriority INT=0
           ,@nAllocatedOrders INT=0
           ,@nSubmmittedTask INT=0
           ,@nPriorityMaxTasks INT=0
           ,@nContinue INT=1
           ,@nBatchNo INT=1
           ,@nPercentage INT=0
           ,@nBatchRetry INT=0
           ,@nStartTranCount INT=0
           ,@c_NoTask CHAR(1)='N'
           ,@d_StartTime DATETIME
           ,@nMaxPriority INT=0
           ,@nNonAllocatedOrders INT = 0
           ,@nOverAllPct INT = 0
           ,@nRowID_NoStock BIGINT

    DECLARE @c_APP_DB_Name         NVARCHAR(20)=''
           ,@c_DataStream  VARCHAR(10)=''
           ,@n_ThreadPerAcct       INT=0
           ,@n_ThreadPerStream     INT=0
           ,@n_MilisecondDelay     INT=0
           ,@c_IP                  NVARCHAR(20)=''
           ,@c_PORT                NVARCHAR(5)=''
           ,@c_PORT2               NVARCHAR(5)=''
           ,@c_IniFilePath         NVARCHAR(200)=''
           ,@c_CmdType             NVARCHAR(10)=''
           ,@c_TaskType            NVARCHAR(1)=''
           ,@n_Priority            INT = 0 -- (SWT02)

    SELECT @c_APP_DB_Name = APP_DB_Name
          ,@c_DataStream          = DataStream
          ,@n_ThreadPerAcct       = ThreadPerAcct
          ,@n_ThreadPerStream     = ThreadPerStream
          ,@n_MilisecondDelay     = MilisecondDelay
          ,@c_IP                  = IP
          ,@c_PORT                = PORT
          ,@c_IniFilePath         = IniFilePath
          ,@c_CmdType             = CmdType
          ,@c_TaskType            = TaskType
          ,@n_Priority            = ISNULL([Priority],0) -- (SWT01)
    FROM   QCmd_TransmitlogConfig WITH (NOLOCK)
    WHERE  TableName              = 'BACKENDALLOC'
           AND [App_Name]         = 'WMS'
           AND StorerKey          = 'ALL'

    IF @c_IP=''
    BEGIN
        SET @nContinue = 3
        SET @nErr = 60205
        SET @cErrMsg = 'Q-Commander TCP Socket not setup!'
        GOTO EXIT_SP
    END

    -- Load Balancing
    SET @c_PORT2 = ''
    SELECT @c_PORT2 = PORT
    FROM   QCmd_TransmitlogConfig WITH (NOLOCK)
    WHERE  TableName              = 'BACKENDALLOC2'
           AND [App_Name]         = 'WMS'
           AND StorerKey          = 'ALL'

   DECLARE @n_Port1_Tasks INT = 0,
           @n_Port2_Tasks INT = 0

   SELECT @n_Port1_Tasks = COUNT(*)
   FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
   WHERE tqt.DataStream = 'BckEndAllo'
   AND tqt.[Status] IN ('0','1')
   AND tqt.Port = @c_PORT

   IF @c_PORT2 <> ''
   BEGIN
      SELECT @n_Port2_Tasks = COUNT(*)
      FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
      WHERE tqt.DataStream = 'BckEndAllo'
      AND tqt.[Status] IN ('0','1')
      AND tqt.Port = @c_PORT2
   END
   ELSE
      SET @n_Port2_Tasks = 0

   IF @n_Port2_Tasks < 10 AND @c_PORT2 <> ''
   BEGIN
    SET @c_PORT = @c_PORT2
   END

   DECLARE @t_TaskPriority TABLE
      (
    Facility          NVARCHAR(5) NOT NULL,
    StorerKey         NVARCHAR(15) NOT NULL,
    Origin_Priority   INT,
    Revise_Priority   INT,
    SafetyAllocOrders INT,
    AllocBatchNo      BIGINT
    PRIMARY KEY CLUSTERED (StorerKey, Facility )
      )

   DECLARE @t_BatchJob TABLE (
      SKU           NVARCHAR(20),
      AllocBatchNo  BIGINT,
      RowID         BIGINT,
      StrategyKey   NVARCHAR(10) )

   SET @nStartTranCount = @@TRANCOUNT
   SET @d_StartTime     = GETDATE()

   -- Resubmit job if pending for 20 minutes
   IF EXISTS(SELECT 1
             FROM AutoAllocBatchJob AAB WITH (NOLOCK)
             LEFT OUTER JOIN TCPSocket_QueueTask AS tqt WITH(NOLOCK)
                  --ON  tqt.DataStream='BckEndAlloc'  --SY01
                  ON  tqt.DataStream='BckEndAllo'     --SY01
                  AND tqt.TransmitLogKey = CAST(AAB.RowID AS VARCHAR(10))
             WHERE AAB.[Status] = '1'
             AND tqt.ID IS NULL)
   BEGIN
      DECLARE CUR_RESUBMIT CURSOR LOCAL FAST_FORWARD READ_ONLY
      FOR SELECT RowID
       FROM AutoAllocBatchJob AAB WITH (NOLOCK)
       LEFT OUTER JOIN TCPSocket_QueueTask AS tqt WITH(NOLOCK)
          --ON  tqt.DataStream='BckEndAlloc'  --SY01
          ON  tqt.DataStream='BckEndAllo'     --SY01
          AND tqt.TransmitLogKey = CAST(AAB.RowID AS VARCHAR(10))
       WHERE AAB.[Status] = '1'
       AND tqt.ID IS NULL

      OPEN CUR_RESUBMIT

      FETCH FROM CUR_RESUBMIT INTO @nRowID

      WHILE @@FETCH_STATUS=0
      BEGIN
          BEGIN TRAN;

          EXEC isp_UpdateAutoAllocBatchJobStatus
               @n_JobRowId=@nRowID
              ,@c_Status='0'
              ,@n_Err=@nErr OUTPUT
              ,@c_ErrMsg=@cErrMsg OUTPUT

          IF @@ERROR<>0
          BEGIN
              ROLLBACK TRAN;
          END
          ELSE
              COMMIT TRAN;

          FETCH FROM CUR_RESUBMIT INTO @nRowID
      END

      CLOSE CUR_RESUBMIT
      DEALLOCATE CUR_RESUBMIT
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   CALCULATE_PRIORITY:
   DELETE FROM  @t_TaskPriority

   DECLARE CUR_FACILITY_STORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT aabj.Facility, aabj.Storerkey, aabj.Priority, MIN(aabj.AllocBatchNo)
   FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)
   WHERE aabj.[Status]='0'
   GROUP BY aabj.Facility, aabj.Storerkey, aabj.Priority
   ORDER BY aabj.Priority

   OPEN CUR_FACILITY_STORER

   FETCH FROM CUR_FACILITY_STORER INTO @cFacility, @cStorerkey, @nBL_Priority, @nAllocBatchNo

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @nTaskPriority = @nBL_Priority
      SET @nSafetyAllocOrders = 5000

      SELECT @nSafetyAllocOrders = CASE WHEN ISNULL(c.Short, '') = '' AND ISNUMERIC(c.Short) <> 1
                                        THEN 5000
                                        ELSE CAST(c.Short as INT)
                                   END
          ,@nTaskPriority = CASE WHEN ISNULL(c.long, '') = '' AND ISNUMERIC(c.long) <> 1
                                        THEN @nBL_Priority
                                        ELSE CAST(c.long as INT)
                                   END
      FROM CODELKUP AS c WITH(NOLOCK)
      WHERE c.LISTNAME='AUTOALLOC'
        AND c.Notes = @cFacility
        AND c.Storerkey = @cStorerKey

      SET @nAllocatedOrders = 0
      SET @nNonAllocatedOrders = 0

      IF @bForceOriginalPeriority = 1
      BEGIN
       SET @nRevisePriority = @nBL_Priority
      END
      ELSE
      BEGIN
         SELECT @nAllocatedOrders = SUM(CASE WHEN ORDERS.[STATUS] = '2' THEN 1 ELSE 0 END),
                @nNonAllocatedOrders = SUM(CASE WHEN ORDERS.[STATUS] = '0' THEN 1 ELSE 0 END)
         FROM   ORDERS WITH (NOLOCK)
         WHERE  StorerKey = @cStorerKey
         AND    Facility  = @cFacility
         AND    [Status]  IN ('2','0')
         AND NOT EXISTS (SELECT 1 FROM LoadPlanDetail AS lpd WITH(NOLOCK)
                         WHERE lpd.OrderKey = ORDERS.OrderKey)
         --AND   (LoadKey = '' OR LoadKey IS NULL)

         IF @nNonAllocatedOrders > 0
         BEGIN
          SET @nOverAllPct = FLOOR( ((@nAllocatedOrders * 1.00) / @nNonAllocatedOrders) * 100)
         END
         ELSE
         BEGIN
          SET @nOverAllPct = 0
         END

         IF @nAllocatedOrders < @nSafetyAllocOrders AND @nSafetyAllocOrders > 0
         BEGIN
           SET @nPercentage = FLOOR( ((@nAllocatedOrders * 1.00) / @nSafetyAllocOrders) * 100)

           IF @nPercentage > @nOverAllPct
           BEGIN
              SELECT @nRevisePriority = CASE
                                    WHEN @nPercentage BETWEEN  0 AND 25 THEN 1
                                    WHEN @nPercentage BETWEEN 26 AND 50 THEN 2
                                    WHEN @nPercentage BETWEEN 51 AND 75 THEN 3
                                    ELSE 4
                                  END
           END
           ELSE
           BEGIN
              SELECT @nRevisePriority = CASE
                                    WHEN @nOverAllPct BETWEEN  0 AND 25 THEN 1
                                    WHEN @nOverAllPct BETWEEN 26 AND 50 THEN 2
                                    WHEN @nOverAllPct BETWEEN 51 AND 75 THEN 3
                                    ELSE 4
                                  END

           END
         END
         ELSE IF @nSafetyAllocOrders = 0
         BEGIN
          SET @nRevisePriority =  @nTaskPriority
         END
         ELSE
         BEGIN
          SET @nRevisePriority = 4
         END
      END


      IF NOT EXISTS (SELECT 1 FROM @t_TaskPriority
                     WHERE Facility = @cFacility AND StorerKey = @cStorerKey)
      BEGIN
         INSERT INTO @t_TaskPriority
         ( Facility, StorerKey, Origin_Priority, Revise_Priority, SafetyAllocOrders, AllocBatchNo )
         VALUES
         ( @cFacility, @cStorerKey, @nTaskPriority, @nRevisePriority, @nSafetyAllocOrders, @nAllocBatchNo )

      END
      ELSE
      BEGIN

         UPDATE @t_TaskPriority
            SET Revise_Priority = @nRevisePriority
         WHERE Facility = @cFacility
         AND   StorerKey = @cStorerKey

      END

      FETCH FROM CUR_FACILITY_STORER INTO @cFacility, @cStorerkey, @nBL_Priority, @nAllocBatchNo
   END -- While CUR_FACILITY_STORER
   CLOSE CUR_FACILITY_STORER
   DEALLOCATE CUR_FACILITY_STORER

   IF @bDebug=1
   BEGIN
      SELECT * FROM @t_TaskPriority
      ORDER BY Revise_Priority
   END

   IF @bDebug=1
    PRINT '>>> @nMaxQCmdTask: ' + CAST(@nMaxQCmdTask AS VARCHAR(10))

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

   --SET @nSubmmittedTask = 0

   --SELECT @nSubmmittedTask = COUNT(*)
   --FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)
   --WHERE aabj.[Status] = '1'

   WHILE 1=1
   BEGIN
      IF @c_NoTask = 'Y'
      BEGIN
         BREAK
      END
      ELSE
      BEGIN
         SET @c_NoTask = 'Y'
      END

      SET @nRevisePriority = 1
      SET @nMaxPriority = 0
      SELECT TOP 1
            @nMaxPriority = Revise_Priority
      FROM @t_TaskPriority
      ORDER BY Revise_Priority DESC

      IF @bDebug = 1
      BEGIN
         PRINT ''
         PRINT '>>> Max Priority: ' + CAST(@nMaxPriority AS VARCHAR(10))
      END

      WHILE @nRevisePriority <= @nMaxPriority
      BEGIN
          IF @bDebug = 1
          BEGIN
             PRINT ''
             PRINT '>>> Priority: ' + CAST(@nRevisePriority AS VARCHAR(10))
          END

          SET @nPriorityMaxTasks = CASE @nRevisePriority
                                     WHEN 1 THEN 30
                                     WHEN 2 THEN 15
                                     WHEN 3 THEN 5
                                     ELSE 2
                                   END

          DECLARE CUR_PRIORITY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT ttp.Facility, ttp.StorerKey
          FROM @t_TaskPriority AS ttp
          LEFT OUTER JOIN AutoAllocBatchJob AAB WITH (NOLOCK) ON AAB.Facility = ttp.Facility AND AAB.StorerKey = ttp.StorerKey
                AND AAB.[Status] = '1'
          WHERE ttp.Revise_Priority = @nRevisePriority
          GROUP BY ttp.Facility, ttp.StorerKey, ttp.AllocBatchNo
          ORDER BY SUM(CASE WHEN AAB.RowID IS NOT NULL THEN 1 ELSE 0 END), ttp.AllocBatchNo

          OPEN CUR_PRIORITY

          FETCH NEXT FROM CUR_PRIORITY INTO @cFacility, @cStorerKey
          WHILE @@FETCH_STATUS=0
          BEGIN
             IF @bDebug = 1
             BEGIN
                PRINT ''
                PRINT '>>> @cStorerKey: ' + @cStorerKey
                PRINT '>>> @cFacility: ' + @cFacility
             END

             SET @nAllocBatchNo = 0
             SET @nRowID = 0
             SET @cSKU = ''
             SET @nSubmmittedTask = 0

             -- (SWT01) Do not submit task for same SKU if it's not complete
             WHILE @nSubmmittedTask <= @nPriorityMaxTasks
             BEGIN
              DELETE FROM @t_BatchJob

               INSERT INTO @t_BatchJob
                SELECT TOP 200
                    AAB.SKU,
                    AAB.AllocBatchNo,
                    AAB.RowID,
                    AAB.StrategyKey
                FROM  AutoAllocBatchJob AAB WITH (NOLOCK)
                WHERE AAB.[Status]='0'
                AND   AAB.Facility = @cFacility
                AND   AAB.Storerkey = @cStorerKey
                ORDER BY AAB.RowID
               IF @@ROWCOUNT = 0
                 BREAK

               WHILE 1=1
               BEGIN
                  SET @nRowID = 0

                   SELECT TOP 1
                       @cSKU = SKU,
                      @nAllocBatchNo = AllocBatchNo,
                       @nRowID = RowID,
                       @cAllocStrategy = StrategyKey
                   FROM  @t_BatchJob
                   WHERE  RowID > @nRowID
                   ORDER BY RowID

                   IF @@ROWCOUNT > 0 AND @nRowID > 0
                   BEGIN
                    IF @bDebug = 1
                    BEGIN
                     PRINT ''
                        PRINT '>>> @nRowID: ' + CAST(@nRowID AS VARCHAR(10))
                    END

                     --DECLARE @n_AllocRowID bigint

                     --DECLARE CUR_ALLOCATING CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     --SELECT RowID
                     --FROM AutoAllocBatchJob AAB2 WITH (NOLOCK)
                     --WHERE AAB2.[Status] IN ('1')
                     --AND   AAB2.Storerkey = @cStorerKey
                     --AND   AAB2.Facility=@cFacility
                     --AND   AAB2.SKU = @cSKU

                     --OPEN CUR_ALLOCATING

                     --FETCH FROM CUR_ALLOCATING INTO @n_AllocRowID

                     --WHILE @@FETCH_STATUS = 0
                     --BEGIN
                     -- IF NOT EXISTS ( SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
                     --                    WHERE tqt.DataStream='BckEndAllo'
                     --                    AND tqt.TransmitLogKey = CAST(@n_AllocRowID AS VARCHAR(20))
                     --                    AND tqt.[Status] IN ('0','1') )
                     --   BEGIN
                     --    UPDATE AutoAllocBatchJob
                     --       SET [Status] = '0'
                     --    WHERE RowID = @n_AllocRowID
                     --   END
                     --   ELSE
                     --   BEGIN
                     --     IF @bDebug = 1
                     --     BEGIN
                     --        PRINT '-- SKU: ' + @cSKU + ' Is Allocating, Choose Next SKU'
                     --     END

                     --      CLOSE CUR_ALLOCATING
                     --      DEALLOCATE CUR_ALLOCATING
                     --      GOTO CONTINUE_NEXT
                     --   END

                     -- FETCH FROM CUR_ALLOCATING INTO @n_AllocRowID
                     --END
                     --CLOSE CUR_ALLOCATING
                     --DEALLOCATE CUR_ALLOCATING

                      SET @c_NoTask = 'N'

                      BEGIN TRAN;

                      SET @nBatchRetry = 0

                      SET @cAllocBatchNo = CAST(@nAllocBatchNo AS VARCHAR(10))

                      IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                                JOIN  LOC AS l WITH(NOLOCK) ON l.Loc = SKUxLOC.Loc
                                WHERE SKUxLOC.StorerKey = @cStorerKey
                                AND   SKUxLOC.Sku = @cSKU
                                AND   l.Facility = @cFacility
                                AND   l.[Status] <> 'HOLD'
                                AND   l.LocationFlag NOT IN ('HOLD','DAMAGE')
                                GROUP BY SKUxLOC.StorerKey, SKUxLOC.Sku
                                HAVING  SUM(SKUxLOC.QTY - SKUxLOC.QtyAllocated - SKUxLOC.QTYPicked ) > 0)
                      BEGIN
                         SET @cCommand = N'EXEC [dbo].[isp_BatchSKUProcessing]' +
                                           N'  @n_AllocBatchNo = ' + @cAllocBatchNo +
                                           N', @c_Facility = ''' + @cFacility + ''' ' +
                                           N', @c_StorerKey = ''' + @cStorerKey + ''' ' +
                                           N', @c_SKU = ''' + @cSKU + ''' ' +
                                           N', @c_Strategy = ''' + @cAllocStrategy + ''' ' +
                                           N', @b_Success = 1 ' +
                                           N', @n_Err = 0 ' +
                                   N', @c_ErrMsg = '''' ' +
                                           N', @b_debug = 0 ' +
                                           N', @n_JobRowId = ' + CAST(@nRowID AS VARCHAR(10))

                         IF @bDebug = 1
                         BEGIN
                            PRINT '>>> @nAllocBatchNo:   ' + CAST(@nAllocBatchNo AS VARCHAR(10))
                            PRINT '  > @cCommand : ' + @cCommand
                            -- PRINT ''
                         END

                         BEGIN TRY
                         EXEC isp_QCmd_SubmitTaskToQCommander
                                 @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others
                               , @cStorerKey        = @cStorerKey
                               , @cDataStream       = 'BckEndAllo'
                               , @cCmdType          = 'SQL'
                               , @cCommand          = @cCommand
                               , @cTransmitlogKey   = @nRowID
                               , @nThreadPerAcct    = @n_ThreadPerAcct
                               , @nThreadPerStream  = @n_ThreadPerStream
                               , @nMilisecondDelay  = @n_MilisecondDelay
                               , @nSeq              = 1
                               , @cIP               = @c_IP
                               , @cPORT             = @c_PORT
                               , @cIniFilePath      = @c_IniFilePath
                               , @cAPPDBName        = @c_APP_DB_Name
                               , @bSuccess          = @bSuccess OUTPUT
                               , @nErr              = @nErr OUTPUT
                               , @cErrMsg           = @cErrMsg OUTPUT
                               , @nPriority         = @n_Priority -- (SWT02)

                         IF @nErr <> 0 AND ISNULL(@cErrMsg,'') <> ''
                         BEGIN
                            PRINT @cErrMsg

                            GOTO EXIT_SP
                         END
                         ELSE
                         BEGIN
                            BEGIN TRAN;

                            UPDATE [dbo].[AutoAllocBatchJob]
                               SET [Status] = '1', EditDate = GETDATE()
                            WHERE RowID = @nRowID
                            IF @@ERROR <> 0
                            BEGIN
                              ROLLBACK TRAN;
                              GOTO EXIT_SP
                            END
                            ELSE
                              COMMIT TRAN;


                            SELECT @nSubmmittedTask = @nSubmmittedTask + 1

                            IF @bDebug = 1
                            BEGIN
                              PRINT '>>> @nSubmmittedTask: ' + CAST(@nSubmmittedTask AS VARCHAR(10))  + ' - ' + CONVERT(VARCHAR(20), GETDATE(), 114)
                            END

                         END
                         END TRY
                         BEGIN CATCH
                            SET @cErrMsg = ERROR_MESSAGE()
                            PRINT @cErrMsg

                          GOTO EXIT_SP
                         END CATCH
                      END -- IF Stock Available
                      ELSE
                      BEGIN
                         BEGIN TRAN;
                         -- Update status to 6 to indicate "No Stock"
                      IF @bDebug = 1
                       BEGIN
                          PRINT '-- SKU: ' + @cSKU + ' Out of Stock'
                       END

                      EXEC isp_UpdateAutoAllocBatchJobStatus
                           @n_JobRowId = @nRowID,
                           @c_Status = '6',
                           @n_Err    = @nErr    OUTPUT,
                           @c_ErrMsg = @cErrMsg OUTPUT

                         IF @@ERROR <> 0
                         BEGIN
                            ROLLBACK TRAN;
                            GOTO EXIT_SP
                         END
                         ELSE
                            COMMIT TRAN;

                         -- Update the rest of the jobs for similar SKU with no stock
                         IF EXISTS(SELECT 1 FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)
                                   WHERE aabj.Storerkey = @cStorerKey
                                   AND   aabj.SKU = @cSKU
                                   AND   aabj.[Status] = '0')
                         BEGIN
                           DECLARE CUR_NOSTOCK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                           SELECT RowID
                           FROM  AutoAllocBatchJob AS aabj WITH(NOLOCK)
                            WHERE aabj.Storerkey = @cStorerKey
                            AND   aabj.SKU = @cSKU
                            AND   aabj.[Status] = '0'
                            AND   aabj.Facility = @cFacility
                           ORDER BY aabj.RowID

                           OPEN CUR_NOSTOCK

                           FETCH FROM CUR_NOSTOCK INTO @nRowID_NoStock

                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                            EXEC isp_UpdateAutoAllocBatchJobStatus
                                 @n_JobRowId = @nRowID_NoStock,
                                 @c_Status = '6',
                                 @n_Err    = @nErr    OUTPUT,
                                 @c_ErrMsg = @cErrMsg OUTPUT

                             FETCH FROM CUR_NOSTOCK INTO @nRowID_NoStock
                           END

                           CLOSE CUR_NOSTOCK
                           DEALLOCATE CUR_NOSTOCK
                         END -- Update the rest of the jobs for similar SKU with no stock
                      END  --  Stock Not Available

                      WHILE @@TRANCOUNT > 0
                         COMMIT TRAN;

                      CONTINUE_NEXT:

                      DELETE @t_BatchJob
                      WHERE RowID = @nRowID

                   END  -- IF @@ROWCOUNT > 0
                   ELSE
                   BEGIN
                    -- No more records in temp table
                    BREAK
                   END

               END -- WHILE 1=1

             END -- WHILE @nSubmmittedTask <= @nPriorityMaxTasks
             FETCH NEXT FROM CUR_PRIORITY INTO @cFacility, @cStorerKey
          END
          CLOSE CUR_PRIORITY
          DEALLOCATE CUR_PRIORITY

          SET @nRevisePriority = @nRevisePriority + 1
       END  -- WHILE Revise_Priority Loop

      IF NOT EXISTS (SELECT 1 FROM AutoAllocBatchJob AS aabj WITH(NOLOCK) WHERE aabj.[Status]='0')
         BREAK

      SET @nSubmmittedTask = 0

      SELECT @nSubmmittedTask = COUNT(*)
      FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
      WHERE tqt.DataStream='BckEndAllo'

      IF @bDebug = 1
      BEGIN
       PRINT '>>> @nSubmmittedTask 2: ' + CAST(@nSubmmittedTask AS VARCHAR(10))  + ' - ' + CONVERT(VARCHAR(20), GETDATE(), 114)
      END

      IF @nSubmmittedTask >= @nMaxQCmdTask OR DATEDIFF(minute, @d_StartTime, GETDATE()) > @nMaxRunningDuration
      BEGIN
         IF @bDebug = 1
         BEGIN
          PRINT '>>> Break! Task exceed Max QCmd Task ' +  CAST(@nMaxQCmdTask AS VARCHAR(10))
         END
       BREAK
      END

      DELETE TP
      FROM @t_TaskPriority TP
      WHERE NOT EXISTS (SELECT 1 FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)
                        WHERE aabj.[Status]='0'
                        AND aabj.Storerkey = TP.StorerKey
                        AND aabj.Facility = TP.Facility)

      IF NOT EXISTS (SELECT 1 FROM @t_TaskPriority)
         BREAK

   END -- WHILE 1=1

   EXIT_SP:
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

   WHILE @@TRANCOUNT < @nStartTranCount
      BEGIN TRAN;

   IF @nContinue = 3
   BEGIN
    SET @bSuccess = 0
   END
END -- procedure

GO