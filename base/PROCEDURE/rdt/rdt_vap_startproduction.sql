SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_VAP_StartProduction                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: INSERT/UPDATE WORKORDER & WORKSTATION_LOG table             */
/*                                                                      */
/* Called from: rdtfnc_VAP_StartProduction                              */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2016-05-12  1.0  James       SOS369251 - Created                     */
/* 2021-05-13  1.1  James       WMS-16844 Add IQC workflow (james01)    */
/*                              Add update WorkOrder.ExternStatus       */
/************************************************************************/

CREATE PROC [RDT].[rdt_VAP_StartProduction] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @nInputKey        INT, 
   @cLangCode        NVARCHAR( 3),  
   @cStorerkey       NVARCHAR( 15), 
   @cWorkStation     NVARCHAR( 20),
   @cJobKey          NVARCHAR( 10),
   @cWorkOrderKey    NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @nNoOfUser        INT,
   @cOption          NVARCHAR( 1), 
   @cReasonCode      NVARCHAR( 10), 
   @cWorkOrderType   NVARCHAR( 10),
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT   
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount        INT,
           @cUserName         NVARCHAR( 18), 
           @cCustomerRefNo    NVARCHAR( 10),
           @cFacility         NVARCHAR( 5), 
           @cJobStatus        NVARCHAR( 1), 
           @cStatus           NVARCHAR( 1), 
           @nCaseCnt          INT,
           @bSuccess          INT, 
           @nQtyCompleted     INT,
           @nQtyJob           INT,
           @cUDF01            NVARCHAR( 18),
           @cUDF03            NVARCHAR( 20)       

   SELECT @cFacility = Facility,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF ISNULL( @cJobKey, '') = ''
      SELECT TOP 1 @cJobKey = JobKey
      FROM dbo.WORKORDERJOB WITH (NOLOCK) 
      WHERE WorkStation = @cWorkStation
      AND   WorkOrderKey = @cWorkOrderKey
      AND   JobStatus < '9'
   
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_VAP_StartProduction

   IF @nStep = 3
   BEGIN
      IF @cWorkOrderType = 'KIT'
         SELECT @cCustomerRefNo = CustomerRefNo, 
                @cUDF01 = USRDEF1
         FROM dbo.Kit WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   KITKey = @cWorkOrderKey
         AND   [Status] < '9'
      ELSE
         SELECT @cCustomerRefNo = QC_Key, 
                @cUDF03 = UserDefine03
         FROM dbo.InventoryQC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   Refno = @cWorkOrderKey
         AND   FinalizeFlag = 'Y'

      -- 1st time start, insert new record
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.WorkOrderJob WITH (NOLOCK) 
                      WHERE WorkStation = @cWorkStation
                      AND   WorkOrderKey = @cWorkOrderKey
                      AND   JobStatus < '9')
      BEGIN
         SELECT @nCaseCnt = CaseCnt
         FROM dbo.Pack Pack WITH (NOLOCK)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON Pack.PackKey = SKU.PackKey
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         EXECUTE nspg_getkey
            @KeyName       = 'JOBKEY' ,
            @fieldlength   = 10,    
            @keystring     = @cJobKey     Output,
            @b_success     = @bSuccess    Output,
            @n_err         = @nErrNo      Output,
            @c_errmsg      = @cErrMsg     Output,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @nErrNo <> 0 OR @bSuccess <> 1
         BEGIN
            SET @nErrNo = 100654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey fail'
            GOTO RollBackTran
         END
            
         INSERT INTO dbo.WorkOrderJob 
         (JobKey, Facility, Storerkey, WorkOrderKey, WorkOrderName, 
          Sequence, QtyRemaining, WorkStation, NoOfAssignedWorker, 
          AddWho, AddDate, EditWho, EditDate, 
          QtyJob, QtyCompleted, JobStatus, UOMQtyJob, QtyReleased, 
          Start_Production, End_Production, InLOC, OutLOC, TrafficCop, STDTime)
          VALUES 
          (@cJobKey, @cFacility, @cStorerKey, @cWorkOrderKey, @cCustomerRefNo, 
          '1', @nQty, @cWorkStation, @nNoOfUser, 
          @cUserName, GETDATE(), @cUserName, GETDATE(), 
          @nQty, 0, '1', @nCaseCnt, @nQty, 
          GETDATE(), NULL, '', '', NULL, CASE WHEN @cWorkOrderType = 'KIT' THEN @cUDF01 ELSE 0 END)
          
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Create job err'
            GOTO RollBackTran
         END

         -- Update workstation reason
         UPDATE dbo.WorkStation WITH (ROWLOCK) SET 
            NoOfAssignedWorker = @nNoOfUser,
            ReasonCode = '',
            EditWho = @cUserName,
            EditDate = GETDATE(),
            STATUS = '1', 
            StartDownTime = GETDATE(), 
            WorkOrderKey = @cWorkOrderKey, 
            JobKey = @cJobKey
         WHERE WorkStation = @cWorkStation

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100666
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Start job fail'
            GOTO RollbackTran
         END
               
         -- Insert record to WORKSTATION_Log table
         INSERT INTO WorkStation_LOG 
            (Facility, WorkZone, WorkStation, WorkMethod, 
            Descr, NoOfAssignedWorker, Status, ReasonCode, 
            SubReasonCode, StartDownTime, EndDownTime, LogWho, LogDate,
            JobKey, WorkOrderKey)
          SELECT Facility, WorkZone, WorkStation, WorkMethod, 
            Descr, NoOfAssignedWorker, '1' AS Status, '' AS ReasonCode, 
            SubReasonCode, GETDATE() AS StartDownTime, EndDownTime,
            @cUserName AS LogWho, GETDATE() AS LogDate,
            @cJobKey, @cWorkOrderKey
         FROM dbo.WorkStation WITH (NOLOCK)
         WHERE WorkStation = @cWorkStation

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 100656
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins WKLOG fail'
            GOTO RollbackTran
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)
                     WHERE ExternWorkOrderKey = @cWorkOrderKey)
         BEGIN
            UPDATE dbo.WorkOrder SET 
               ExternStatus = '3', 
               EditWho = @cUserName, 
               EditDate = GETDATE()
            WHERE  ExternWorkOrderKey = @cWorkOrderKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100667
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD WORKORDER Er'
               GOTO RollbackTran
            END
         END
      END
      ELSE  -- Job exists
      BEGIN
         SELECT @cJobStatus = JobStatus
         FROM dbo.WorkOrderJob WITH (NOLOCK) 
         WHERE WorkStation = @cWorkStation
         AND   WorkOrderKey = @cWorkOrderKey
         AND   JobKey = @cJobKey
         AND   JobStatus < '9'         

         SELECT @nQtyCompleted = ISNULL( SUM( QtyCompleted), 0), 
                @nQtyJob = ISNULL( SUM( QtyJob), 0), 
                @cJobStatus = JobStatus
         FROM dbo.WorkOrderJob WITH (NOLOCK) 
         WHERE WorkStation = @cWorkStation
         AND   WorkOrderKey = @cWorkOrderKey
         AND   JobKey = @cJobKey
         AND   JobStatus < '9'
         GROUP BY JobStatus

         -- Job status = 1 only can pause/end job
         IF @cJobStatus = '1'
         BEGIN
            -- End the job
            IF @cOption = '2'
            BEGIN
               UPDATE dbo.WorkOrderJob WITH (ROWLOCK) SET 
                  QtyCompleted = QtyCompleted + @nQty,
                  QtyRemaining = QtyRemaining - @nQty, 
                  End_Production = GETDATE(),
                  JobStatus = '9',
                  EditWho = @cUserName,
                  EditDate = GETDATE()
               WHERE WorkStation = @cWorkStation
               AND   WorkOrderKey = @cWorkOrderKey
               AND   JobKey = @cJobKey
               AND   JobStatus < '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'End job fail'
                  GOTO RollbackTran
               END

               -- Insert record to WORKSTATION_Log table
               INSERT INTO WorkStation_LOG 
                  (Facility, WorkZone, WorkStation, WorkMethod, 
                  Descr, NoOfAssignedWorker, Status, ReasonCode, 
                  SubReasonCode, StartDownTime, EndDownTime, LogWho, LogDate,
                  JobKey, WorkOrderKey)
                SELECT Facility, WorkZone, WorkStation, WorkMethod, 
                  Descr, NoOfAssignedWorker, '9' AS Status, '' AS ReasonCode, 
                  SubReasonCode, StartDownTime, GETDATE() AS EndDownTime,
                  @cUserName AS LogWho, GETDATE() AS LogDate,
                  @cJobKey, @cWorkOrderKey
               FROM dbo.WorkStation WITH (NOLOCK)
               WHERE WorkStation = @cWorkStation

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100658
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins WKLOG fail'
                  GOTO RollbackTran
               END            

               IF EXISTS ( SELECT 1 FROM dbo.WorkOrder WITH (NOLOCK)
                           WHERE ExternWorkOrderKey = @cWorkOrderKey)
               BEGIN
                  UPDATE dbo.WorkOrder SET 
                     ExternStatus = '5', 
                     EditWho = @cUserName, 
                     EditDate = GETDATE()
                  WHERE  ExternWorkOrderKey = @cWorkOrderKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 100667
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD WORKORDER Er'
                     GOTO RollbackTran
                  END
               END
            END

            -- Pause the job
            IF @cOption = '3'
            BEGIN
               UPDATE dbo.WorkOrderJob WITH (ROWLOCK) SET 
                  QtyCompleted = QtyCompleted + @nQty,
                  QtyRemaining = QtyRemaining - @nQty, 
                  JobStatus = '5',
                  EditWho = @cUserName,
                  EditDate = GETDATE()
               WHERE WorkStation = @cWorkStation
               AND   WorkOrderKey = @cWorkOrderKey
               AND   JobKey = @cJobKey
               AND   JobStatus = '1'
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100662
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pause job fail'
                  GOTO RollbackTran
               END
               
               -- Update workstation reason
               UPDATE dbo.WorkStation WITH (ROWLOCK) SET 
                  ReasonCode = @cReasonCode,
                  EditWho = @cUserName,
                  EditDate = GETDATE(),
                  STATUS = '3', 
                  WorkOrderKey = @cWorkOrderKey, 
                  JobKey = @cJobKey
               WHERE WorkStation = @cWorkStation

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100660
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Start job fail'
                  GOTO RollbackTran
               END

               -- Insert record to WORKSTATION_Log table
               INSERT INTO WorkStation_LOG 
                  (Facility, WorkZone, WorkStation, WorkMethod, 
                  Descr, NoOfAssignedWorker, Status, ReasonCode, 
                  SubReasonCode, StartDownTime, EndDownTime, LogWho, LogDate,
                  JobKey, WorkOrderKey)
                SELECT Facility, WorkZone, WorkStation, WorkMethod, 
                  Descr, NoOfAssignedWorker, '5' AS Status, ReasonCode, 
                  SubReasonCode, StartDownTime, EndDownTime,
                  @cUserName AS LogWho, GETDATE() AS LogDate,
                  @cJobKey, @cWorkOrderKey
               FROM dbo.WorkStation WITH (NOLOCK)
               WHERE WorkStation = @cWorkStation

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 100661
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins WKLOG fail'
                  GOTO RollbackTran
               END            
            END   -- @cOption = '3'
         END

         -- Job status = 5 only can activate
         IF @cJobStatus = '5'
         BEGIN
            -- Restart stopped job
            UPDATE dbo.WorkOrderJob WITH (ROWLOCK) SET 
               JobStatus = '1',
               NoOfAssignedWorker = @nNoOfUser,
               EditWho = @cUserName,
               EditDate = GETDATE()
            WHERE WorkStation = @cWorkStation
            AND   WorkOrderKey = @cWorkOrderKey
            AND   JobKey = @cJobKey
            AND   JobStatus = '5'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100663
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Start job fail'
               GOTO RollbackTran
            END
            
            -- Update workstation reason
            UPDATE dbo.WorkStation WITH (ROWLOCK) SET 
               ReasonCode = '',
               NoOfAssignedWorker = @nNoOfUser,
               EditWho = @cUserName,
               EditDate = GETDATE(), 
               STATUS = '3', 
               WorkOrderKey = @cWorkOrderKey, 
               JobKey = @cJobKey
            WHERE WorkStation = @cWorkStation

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Start job fail'
               GOTO RollbackTran
            END

            -- Insert record to WORKSTATION_Log table
            INSERT INTO WorkStation_LOG 
               (Facility, WorkZone, WorkStation, WorkMethod, 
               Descr, NoOfAssignedWorker, Status, ReasonCode, 
               SubReasonCode, StartDownTime, EndDownTime, LogWho, LogDate,
               JobKey, WorkOrderKey)
             SELECT Facility, WorkZone, WorkStation, WorkMethod, 
               Descr, NoOfAssignedWorker, '1' AS Status, '' AS ReasonCode, 
               SubReasonCode, StartDownTime, EndDownTime,
               @cUserName AS LogWho, GETDATE() AS LogDate,
               @cJobKey, @cWorkOrderKey
            FROM dbo.WorkStation WITH (NOLOCK)
            WHERE WorkStation = @cWorkStation

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 100665
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins WKLOG fail'
               GOTO RollbackTran
            END            
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_VAP_StartProduction

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_VAP_StartProduction

END

GO