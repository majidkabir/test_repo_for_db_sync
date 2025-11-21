SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_JobCapture_Confirm                                    */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author    Purposes                                         */
/* 30-08-2018 1.0  Ung       WMS-6051 Created                                 */
/* 13-02-2019 1.1  James     WMS-7795 Add capture reference (james01)         */
/* 11-04-2019 1.2  James     WMS-8603 Add rdtstdeventlog.status = '3'         */
/*                           when capture UDF (james02)                       */
/* 02-07-2019 1.3  James     WMS-9493 Enhance UDF insert (james03)            */
/* 16-08-2019 1.4  James     WMS-10170 Check duplicate records (james04)      */
/* 04-03-2021 1.5  LZG       INC1440390 - Fixed bug (ZG01)                    */
/* 10-09-2020 1.6  YeeKung   WMS-15084 Change username and loc length         */
/*                             (yeekung01)                                    */
/* 24-09-2019 1.7  James     INC0844782-Bug fix on UDF insert (james05)       */
/* 23-08-2021 1.8  Ung       WMS-18427                                        */
/*                           Add QTY UOM                                      */
/*                           Add CaptureQTY = M                               */ 
/*                           Add CaptureData = M                              */ 
/*                           Add Confirm end job to all scenario              */
/*                           Change CaptureData = 1, confirm end job flow     */
/*                           Clean up source                                  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_JobCapture_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cType         NVARCHAR( 10),       -- START/DATA/END
   @cUserID       NVARCHAR( 30) = '',  
   @cJobType      NVARCHAR( 20) = '',
   @cLOC          NVARCHAR( 30) = '',  
   @cQTY          NVARCHAR( 5)  = '',
   @cStart        NVARCHAR( 10) = '' OUTPUT,
   @cEnd          NVARCHAR( 10) = '' OUTPUT,
   @cDuration     NVARCHAR( 5)  = '' OUTPUT,
   @nErrNo        INT           = '' OUTPUT,
   @cErrMsg       NVARCHAR( 20) = '' OUTPUT,
   @cRef01        NVARCHAR( 60) = '',
   @cRef02        NVARCHAR( 60) = '',
   @cRef03        NVARCHAR( 60) = '',
   @cRef04        NVARCHAR( 60) = '',
   @cRef05        NVARCHAR( 60) = ''

) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @nRowCount   INT
   DECLARE @nRowRef     INT
   DECLARE @dStart      DATETIME
   DECLARE @dEnd        DATETIME
   DECLARE @nMinutes    INT
   DECLARE @cCaptureQTY NVARCHAR( 1)
   DECLARE @cCaptureData NVARCHAR( 1)

   IF @cType = 'START'
   BEGIN
      -- Check job already open
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtWATLog WITH (NOLOCK)
         WHERE Module = 'JOBCAPTURE'
            AND UserName = @cUserID
            AND StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND Status = '0')
      BEGIN
         SET @nErrNo = 128551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StartJob Exist
         GOTO Quit
      END

      SET @dStart = GETDATE()

      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_JobCapture_Confirm -- For rollback or commit only our own transaction

      INSERT INTO rdt.rdtWATLog 
         (Module, UserName, TaskCode, Location, StartDate, EndDate, Status, StorerKey, Facility)
      VALUES 
         ('JOBCAPTURE', @cUserID, @cJobType, @cLOC, @dStart, @dStart, '0', @cStorerKey, @cFacility)
      SELECT @nRowRef = SCOPE_IDENTITY(), @nErrNo = @@ERROR
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 128552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS WATLogFail

         ROLLBACK TRAN rdt_JobCapture_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END
      
      UPDATE rdt.rdtWATLog SET
         GroupKey = @nRowRef
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 128553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WATLogFail

         ROLLBACK TRAN rdt_JobCapture_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END
      
      COMMIT TRAN rdt_JobCapture_Confirm
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @dtEventDateTime = @dStart,
         @cActionType     = '3',
         @cUserID         = @cUserID,
         @nMobileNo       = @nMobile,
         @nFunctionID     = @nFunc,
         @cFacility       = @cFacility,
         @cStorerKey      = @cStorerkey,
         @cRefNo1         = @nRowRef,
         @cRefNo2         = @cJobType,
         @cLocation       = @cLOC,
         @cStatus         = '0'

      -- DD HH:MMAM
      SET @cStart = SUBSTRING( CONVERT( NVARCHAR(30), @dStart, 0), 5, 2) + ' ' + RIGHT( CONVERT( NVARCHAR(20), @dStart, 0), 7)
      SET @cEnd = ''
      SET @cDuration = ''
   END

   ELSE IF @cType = 'DATA'
   BEGIN
      DECLARE @cField01    NVARCHAR( 60)
      DECLARE @cField02    NVARCHAR( 60)
      DECLARE @cField03    NVARCHAR( 60)
      DECLARE @cField04    NVARCHAR( 60)
      DECLARE @cField05    NVARCHAR( 60)
      DECLARE @cField      NVARCHAR( 60)
      DECLARE @cHearderQTY NVARCHAR( 5)
      DECLARE @n           INT
      DECLARE @cSQL        NVARCHAR( MAX)
      DECLARE @cSQLParam   NVARCHAR( MAX)

      -- Get start job
      SELECT
         @nRowRef = RowRef,
         @dStart = StartDate, 
         @cHearderQTY = QTY
      FROM rdt.rdtWATLog WITH (NOLOCK)
      WHERE Module = 'JOBCAPTURE'
         AND UserName = @cUserID
         AND StorerKey = @cStorerKey
         AND Facility = @cFacility
         AND TaskCode = @cJobType
         AND Status = '0'

      SET @nRowCount = @@ROWCOUNT
      
      -- Check start job
      IF @nRowCount <> 1
      BEGIN
         SET @nErrNo = 128554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StartJob error
         GOTO Quit
      END

      -- Check duplicate data (in the group)
      IF EXISTS( SELECT TOP 1 1
         FROM rdt.rdtWATLog WITH (NOLOCK)
         WHERE Module = 'JOBCAPTURE'
            AND UserName = @cUserID
            AND StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND TaskCode = @cJobType
            AND Status = '3'
            AND UDF01 = @cRef01
            AND UDF02 = @cRef02
            AND UDF03 = @cRef03
            AND UDF04 = @cRef04
            AND UDF05 = @cRef05
            AND GroupKey = @nRowRef)
      BEGIN
         SET @nErrNo = 128555
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate Data
         GOTO Quit
      END
      
      -- Get job type
      SELECT 
         @cCaptureQTY = UDF02
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'JOBCapType'
         AND Code = @cJobType
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
         
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_JobCapture_Confirm -- For rollback or commit only our own transaction

      -- Update QTY to header
      IF @cCaptureQTY = '1'
      BEGIN
         -- Header QTY not updated
         IF @cHearderQTY <> @cQTY
         BEGIN
            UPDATE rdt.rdtWATLog SET
               QTY = @cQTY
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 128560
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WATLogFail

               ROLLBACK TRAN rdt_JobCapture_Confirm
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END
         END
         
         -- QTY not save to detail
         SET @cQTY = '0'
      END
      
      DECLARE @dJobDate DATETIME
      SET @dJobDate = GETDATE()
      
      -- Capture data
      INSERT INTO rdt.rdtWATLog 
         (Module, UserName, TaskCode, StartDate, EndDate, Status, StorerKey, Facility,
          QTY, UDF01, UDF02, UDF03, UDF04, UDF05, GroupKey)
      VALUES 
         ('JOBCAPTURE', @cUserID, @cJobType, @dJobDate, @dJobDate, '3', @cStorerKey, @cFacility,
          @cQTY, @cRef01, @cRef02, @cRef03, @cRef04, @cRef05, @nRowRef)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 128556
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS WATLogFail

         ROLLBACK TRAN rdt_JobCapture_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END

      COMMIT TRAN rdt_JobCapture_Confirm
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Get data column
      SELECT 
         @cField01 = UDF01,
         @cField02 = UDF02,
         @cField03 = UDF03,
         @cField04 = UDF04,
         @cField05 = UDF05
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'JOBCapCol'
         AND Code = @cJobType
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility

      SET @n = 1
      SET @cSQL = ''

      WHILE @n < 6
      BEGIN
         IF @n = 1 SET @cField = @cField01
         IF @n = 2 SET @cField = @cField02
         IF @n = 3 SET @cField = @cField03
         IF @n = 4 SET @cField = @cField04
         IF @n = 5 SET @cField = @cField05

         IF @cField <> ''
            SET @cSQL = @cSQL + ', @c' + @cField + ' = @cRef0' + CAST( @n AS NCHAR(1))

         SET @n = @n + 1
         SET @cField = ''
      END

      SET @cSQL = '
        EXEC RDT.rdt_STD_EventLog
            @dtEventDateTime = @dJobDate,
            @cActionType     = ''3'',
            @cUserID         = @cUserID,
            @nMobileNo       = @nMobile,
            @nFunctionID     = @nFunc,
            @cFacility       = @cFacility,
            @cStorerKey      = @cStorerkey,
            @cRefNo1         = @nRowRef,
            @cRefNo2         = @cJobType,
            @cLocation       = @cLOC,
            @nQTY            = @cQTY, 
            @cStatus         = ''3'' ' + @cSQL

      SET @cSQLParam = 
         '@dJobDate        DATETIME,      ' +
         '@cUserID         NVARCHAR( 15), ' +
         '@nMobile         INT,           ' +
         '@nFunc           INT,           ' +
         '@cFacility       NVARCHAR( 5),  ' +
         '@cStorerkey      NVARCHAR( 15), ' +
         '@nRowRef         INT,           ' +
         '@cJobType        NVARCHAR( 20), ' +
         '@cLOC            NVARCHAR( 10), ' + 
         '@cQTY            NVARCHAR( 5),  ' +
         '@cRef01          NVARCHAR( 60), ' +
         '@cRef02          NVARCHAR( 60), ' +
         '@cRef03          NVARCHAR( 60), ' +
         '@cRef04          NVARCHAR( 60), ' +
         '@cRef05          NVARCHAR( 60)  '

      EXEC sp_ExecuteSql @cSQL, @cSQLParam
         ,@dJobDate
         ,@cUserID
         ,@nMobile
         ,@nFunc
         ,@cFacility
         ,@cStorerkey
         ,@nRowRef
         ,@cJobType
         ,@cLOC
         ,@cQTY
         ,@cRef01
         ,@cRef02
         ,@cRef03
         ,@cRef04
         ,@cRef05

      -- DD HH:MM APM
      SET @cStart = SUBSTRING( CONVERT( NVARCHAR(30), @dStart, 0), 5, 2) + ' ' + RIGHT( CONVERT( NVARCHAR(20), @dStart, 0), 7)
      SET @cEnd = ''
      SET @cDuration = ''
   END

   ELSE IF @cType = 'END'
   BEGIN
      -- Get job info
      SELECT
         @nRowRef = RowRef,
         @dStart = StartDate
      FROM rdt.rdtWATLog WITH (NOLOCK)
      WHERE Module = 'JOBCAPTURE'
         AND UserName = @cUserID
         AND StorerKey = @cStorerKey
         AND Facility = @cFacility
         AND TaskCode = @cJobType
         AND Status = '0'

      SET @nRowCount = @@ROWCOUNT 

      -- Check missing job start
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 128557
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No start JOB
         GOTO Quit
      END

      -- Check multiple job start
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 128558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi StartJOB
         GOTO Quit
      END

      -- Get job type
      SELECT 
         @cCaptureQTY = UDF02,
         @cCaptureData = UDF03
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'JOBCapType'
         AND Code = @cJobType
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
      
      SET @dEnd = GETDATE()

      -- Job that capture data (multiple records)
      IF @cCaptureData IN ('1', 'M')
      BEGIN
         DECLARE @nGroupKey INT
         SET @nGroupKey = @nRowRef
         
         -- Handling transaction
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_JobCapture_Confirm -- For rollback or commit only our own transaction
         
         DECLARE @nRec INT
         DECLARE @curWATlog CURSOR
         SET @curWATlog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM rdt.rdtWATLog WITH (NOLOCK)
            WHERE Module = 'JOBCAPTURE'
               AND UserName = @cUserID
               AND StorerKey = @cStorerKey
               AND Facility = @cFacility
               AND TaskCode = @cJobType
               AND Status IN ('0', '3') -- 0=Open(header), 3=In-progress(detail)
               AND GroupKey = @nGroupKey
         OPEN @curWATlog
         FETCH NEXT FROM @curWATlog INTO @nRec
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE rdt.rdtWATLog SET
               Status = '9',
               QTY = CASE WHEN @nRec = @nGroupKey AND @cCaptureQTY = '1' THEN @cQTY ELSE QTY END, -- Only for header
               EndDate = CASE WHEN @nRec = @nGroupKey THEN @dEnd ELSE EndDate END, -- Only for header
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE RowRef = @nRec
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 128559
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WATLogFail
               
               ROLLBACK TRAN rdt_JobCapture_Confirm
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END

            FETCH NEXT FROM @curWATlog INTO @nRec
         END
         
         COMMIT TRAN rdt_JobCapture_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END
      
      ELSE -- Job that not capture data (only 1 record)
      BEGIN
         UPDATE rdt.rdtWATLog SET
            Status = '9',
            QTY = CASE WHEN @cCaptureQTY = '1' THEN @cQTY ELSE QTY END,
            EndDate = @dEnd,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 128560
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD WATLogFail
            GOTO Quit
         END
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @dtEventDateTime = @dEnd,
         @cActionType     = '3',
         @cUserID         = @cUserID,
         @nMobileNo       = @nMobile,
         @nFunctionID     = @nFunc,
         @cFacility       = @cFacility,
         @cStorerKey      = @cStorerkey,
         @cRefNo1         = @nRowRef,
         @cRefNo2         = @cJobType,
         @cLocation       = @cLOC,
         @nQTY            = @cQTY,
         @cStatus         = '9'
         
      -- DD HH:MMAM
      SET @cStart = SUBSTRING( CONVERT( NVARCHAR(30), @dStart, 0), 5, 2) + ' ' + RIGHT( CONVERT( NVARCHAR(20), @dStart, 0), 7)
      SET @cEnd = SUBSTRING( CONVERT( NVARCHAR(30), @dEnd, 0), 5, 2) + ' ' + RIGHT( CONVERT( NVARCHAR(20), @dEnd, 0), 7)

      SELECT @nMinutes = DATEDIFF( mi, @dStart, @dEnd)

      -- HH:MM
      IF @nMinutes > 5999 -- 99h:59m = (24*60)+59 = 5999 mins 
         SET @cDuration = '*'
      ELSE
         SET @cDuration = RIGHT( '0' + CAST( @nMinutes / 60 AS NVARCHAR(2)), 2) + ':' +  -- HH
                          RIGHT( '0' + CAST( @nMinutes % 60 AS NVARCHAR(2)), 2)          -- MM
   END

Quit:

END

GO