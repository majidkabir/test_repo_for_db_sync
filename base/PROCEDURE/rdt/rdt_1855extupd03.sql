SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/***********************************************************************s****/
/* Store procedure: rdt_1855ExtUpd03                                       */
/* Copyright      : MAERSK                                                 */
/* Customer       : Granite                                                */
/*                                                                         */
/* Purpose: Send picked interface to WCS                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Ver.    Author  Purposes                                   */
/* 2024-11-09   1.0.0   NLT013  FCR-1755 Created                           */
/* 2024-12-26   1.0.1   JCH507  FCR-1755 Wrong position at st5 when short  */
/* 2025-01-15   1.0.2   NLT013  FCR-1755 Remove duplicate scanned tote     */
/* 2025-02-12   1.0.3   NLT013  FCR-1755 Wrong position issue              */
/***************************************************************************/
      
CREATE   PROCEDURE [rdt].[rdt_1855ExtUpd03]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10),
   @cCartId        NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cCartonId      NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cOption        NVARCHAR( 1),
   @tExtUpdate     VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
      @nTranCount                INT,
      @nRowCount                 INT,
      @nLoopIndex                INT,
      @cPickZone                 NVARCHAR( 10),
      @cPickConfirmStatus        NVARCHAR( 1),
      @cWaveKey                  NVARCHAR( 10),
      @cDropID                   NVARCHAR( 20),
      @cUserName                 NVARCHAR( 18),
      @nScannedToteQty           INT,
      @cMethod                   NVARCHAR( 5),
      @cCartonType               NVARCHAR( 10),
      @cCaseID                   NVARCHAR( 20),
      @cPosition                 NVARCHAR( 10),

      @bSuccess                  INT

   DECLARE @tDropIDList TABLE
   (
      id                INT IDENTITY(1,1),
      DropID            NVARCHAR(20),
      WaveKey           NVARCHAR(10)
   )
   
   SET @nErrNo = 0

   SELECT 
      @cUserName                    = UserName,
      @cPickZone                    = V_String24,
      @cMethod                      = V_String25
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get storer config  
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
   IF @cPickConfirmStatus = '0'  
      SET @cPickConfirmStatus = '5'  

   IF @nFunc = 1855
   BEGIN
      IF @nStep = 4
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cPickZone <> 'PICK'
            BEGIN
               SELECT @cCaseID = CaseID
               FROM dbo.TaskDetail WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND TaskDetailKey = @cTaskDetailKey

               SELECT TOP 1 @cPosition = StatusMsg
               FROM dbo.TaskDetail WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cCaseID
                  AND StatusMsg <> ''
                  AND TaskDetailKey <> @cTaskDetailKey

               SELECT @nRowCount = @@ROWCOUNT 
               IF @nRowCount > 0
               BEGIN
                  UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET StatusMsg = @cPosition
                  WHERE StorerKey = @cStorerKey
                     AND TaskDetailKey = @cTaskDetailKey
               END
               ELSE 
               BEGIN
                  SELECT @nScannedToteQty = COUNT(DISTINCT DropID)
                  FROM dbo.TaskDetail WITH(NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND GroupKey = @cGroupKey
                     AND Status = '5'
                     AND TaskType = 'ASTCPK'
                     AND DeviceID = @cCartId
                     AND UserKey = @cUserName

                  SELECT @cCartonType = UDF01
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE LISTNAME = 'TMPICKMTD'
                     AND Code = @cMethod
                     AND Storerkey = @cStorerKey

                  UPDATE dbo.TaskDetail WITH (ROWLOCK)
                  SET StatusMsg = ISNULL(TRY_CAST(@nScannedToteQty AS NVARCHAR(5)), '0') + '-' + ISNULL(@cCartonType, '')
                  WHERE StorerKey = @cStorerKey
                     AND TaskDetailKey = @cTaskDetailKey
               END
            END
         END
      END --step 4
      ELSE IF @nStep = 6 --v1.0.1 start
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cPickZone <> 'PICK'
            BEGIN
               IF @cOption = '1'
               BEGIN
                  SELECT @cCaseID = CaseID
                  FROM dbo.TaskDetail WITH(NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND TaskDetailKey = @cTaskDetailKey

                  SELECT TOP 1 @cPosition = StatusMsg
                  FROM dbo.TaskDetail WITH(NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND CaseID = ISNULL(@cCaseID, '-1')
                     AND StatusMsg <> ''
                     AND TaskDetailKey <> @cTaskDetailKey

                  SELECT @nRowCount = @@ROWCOUNT 
                  IF @nRowCount > 0
                  BEGIN
                     UPDATE dbo.TaskDetail WITH (ROWLOCK)
                     SET StatusMsg = @cPosition
                     WHERE StorerKey = @cStorerKey
                        AND TaskDetailKey = @cTaskDetailKey
                  END
                  ELSE
                  BEGIN
                     SELECT @nScannedToteQty = COUNT(DISTINCT DropID)
                     FROM dbo.TaskDetail WITH(NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND GroupKey = @cGroupKey
                        AND Status = '5'
                        AND TaskType = 'ASTCPK'
                        AND DeviceID = @cCartId
                        AND UserKey = @cUserName

                     SELECT @cCartonType = UDF01
                     FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'TMPICKMTD'
                        AND Code = @cMethod
                        AND Storerkey = @cStorerKey

                     UPDATE dbo.TaskDetail WITH (ROWLOCK)
                     SET StatusMsg = ISNULL(TRY_CAST(@nScannedToteQty AS NVARCHAR(5)), '0') + '-' + ISNULL(@cCartonType, '')
                     WHERE StorerKey = @cStorerKey
                        AND TaskDetailKey = @cTaskDetailKey
                  END
               END -- option 1
            END -- <> PICK
         END
      END --step 6 --v1.0.1 end
      ELSE IF @nStep = 7
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ISNULL(@cPickZone, '') = 'PICK'
               GOTO Quit

            INSERT INTO @tDropIDList(WaveKey, DropID)
            SELECT DISTINCT ISNULL(ORM.userdefine09, ''), PKD.DropID
            FROM dbo.TASKDETAIL TD WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PKD WITH(NOLOCK)
               ON TD.StorerKey = PKD.StorerKey
               AND TD.TaskDetailKey = PKD.TaskDetailKey
            INNER JOIN dbo.ORDERS ORM WITH(NOLOCK)
               ON ORM.StorerKey = PKD.StorerKey
               AND ORM.OrderKey = PKD.OrderKey
            WHERE TD.StorerKey = @cStorerKey
               AND TD.Groupkey = @cGroupKey   
               AND TD.DeviceID = @cCartID   
               AND TD.Status = '9'
               AND PKD.Status = @cPickConfirmStatus

            SELECT @nRowCount = @@ROWCOUNT
            IF @nRowCount = 0 
               GOTO Quit

            -- Handling transaction
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_1855ExtUpd03 -- For rollback or commit only our own transaction

            UPDATE PKD
            SET PKD.CaseID = ''
            FROM dbo.PickDetail PKD WITH(ROWLOCK)
            INNER JOIN dbo.TASKDETAIL TD WITH (NOLOCK)
               ON TD.StorerKey = PKD.StorerKey
               AND TD.TaskDetailKey = PKD.TaskDetailKey
            WHERE TD.StorerKey = @cStorerKey
               AND TD.Groupkey = @cGroupKey   
               AND TD.DeviceID = @cCartID   
               AND TD.Status = '9'
               AND PKD.Status = @cPickConfirmStatus

            SET @nLoopIndex = -1

            WHILE 1 = 1
            BEGIN
               SELECT TOP 1 
                  @cDropID = DropID,
                  @cWaveKey = WaveKey,
                  @nLoopIndex = id
               FROM @tDropIDList
               WHERE id > @nLoopIndex
               ORDER BY id

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
                  BREAK

               -- Insert transmitlog2 here
               EXECUTE ispGenTransmitLog2
                  @c_TableName      = 'WSCTOTALLOCLOG',
                  @c_Key1           = @cWaveKey,
                  @c_Key2           = @cDropID,
                  @c_Key3           = @cStorerkey,
                  @c_TransmitBatch  = '',
                  @b_Success        = @bSuccess   OUTPUT,
                  @n_err            = @nErrNo     OUTPUT,
                  @c_errmsg         = @cErrMsg    OUTPUT

               IF @bSuccess <> 1
               BEGIN    
                  SET @nErrNo = 230851
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTL2LogErr'
                  GOTO RollBackTran
               END    
            END

            COMMIT TRAN rdt_1855ExtUpd03
      
            GOTO Commit_Tran
      
            RollBackTran:
               ROLLBACK TRAN rdt_1855ExtUpd03 -- Only rollback change made here    
            Commit_Tran:
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                  COMMIT TRAN
               
            GOTO Quit
         END
      END
   END

   Quit:
   IF @nErrNo <> 0
      SET @nErrNo = -1
END

GO