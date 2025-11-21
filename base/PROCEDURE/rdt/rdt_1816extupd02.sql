SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1816ExtUpd02                                    */  
/* Copyright      : Maersk                                              */  
/* Customer       : Levis                                               */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.   Purposes                               */  
/* 2024-11-28   Dennis    1.0.0  FCR-1344 Created                       */  
/* 2024-12-18   NLT013    1.0.1  FCR-1344 Fixed some issues             */  
/* 2024-12-18   NLT013    1.0.2  FCR-1344 Unlock loc & set status3      */  
/* 2025-01-14   Dennis    1.0.3  FCR-1344 Transmitlog2 key2 = caseid    */  
/************************************************************************/  
  
CREATE   PROCEDURE rdt.rdt_1816ExtUpd02  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@nInputKey       INT  
   ,@cTaskdetailKey  NVARCHAR( 10)  
   ,@cFinalLOC       NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cFromLOC NVARCHAR(10)  
   DECLARE @cFromID  NVARCHAR(18)  
   DECLARE @cStorerKey  NVARCHAR(15)
   DECLARE @nTranCount INT,
   @nLoopIndex INT,
   @nRowCount  INT
   DECLARE @cListKey  NVARCHAR(15),
   @cCaseID    NVARCHAR(20),
   @nCaseCount     INT,
   @cUOM       NVARCHAR(20),
   @cACTCaseID NVARCHAR(20)

   DECLARE @tCases TABLE
   (
      ID    INT IDENTITY(1,1),
      CaseID NVARCHAR(20)
   )
   SET @nTranCount = @@TRANCOUNT  
     
   -- Get task info  
   SELECT   
      @cListKey = SourceKey,
      @cFromLOC = FromLOC,   
      @cFromID = FromID  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey

   SELECT @cStorerKey = StorerKey 
   FROM RDT.RDTMOBREC (NOLOCK) 
   WHERE Mobile = @nMobile

   -- TM assist NMV  
   IF @nFunc = 1816  
   BEGIN  
      IF @nStep = 1 -- FinalLOC  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            DECLARE
               @cUserDefine09 NVARCHAR(10),
               @bSuccess INT
  
            -- Get OrderKey  
            SELECT TOP 1
               @cUserDefine09 = ORDERS.UserDefine09
            FROM dbo.PickDetail PD WITH (NOLOCK)  
            INNER JOIN dbo.ORDERS WITH (NOLOCK) ON ( PD.StorerKey = ORDERS.StorerKey AND PD.OrderKey = ORDERS.OrderKey)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.ID = @cFromID
               AND PD.Status < '5'  

            -- Handling transaction  
            BEGIN TRAN  -- Begin our own transaction  
            SAVE TRAN rdt_1816ExtUpd02 -- For rollback or commit only our own transaction  

            -- Update PickDetail  
            UPDATE dbo.PickDetail WITH (ROWLOCK) 
            SET 
               Status = '3'
            WHERE StorerKey = @cStorerKey
               AND ID = @cFromID 
               AND Status = '0'

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 52255  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO RollbackTran  
            END

            IF EXISTS(SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'DICSEPKMTD' AND StorerKey = @cStorerKey AND Code = @cFinalLOC)
            BEGIN
               DELETE FROM @tCases
               INSERT INTO @tCases(CaseID)
               SELECT CaseID FROM dbo.TaskDetail WITH(NOLOCK) WHERE ListKey = @cListKey AND DropID = @cFromID AND Status = '9' AND QTY>0

               SET @nLoopIndex = -1
               WHILE 1 = 1
               BEGIN
                  SELECT TOP 1 
                     @cCaseID = CASEID,
                     @nLoopIndex = id
                  FROM @tCases
                  WHERE id > @nLoopIndex
                  ORDER BY id

                  SELECT @nRowCount = @@ROWCOUNT

                  IF @nRowCount = 0
                     BREAK

                  EXEC ispGenTransmitLog2
                  @c_TableName        = 'WSCTOTALLOCLOG'
                  ,@c_Key1             = @cUserDefine09
                  ,@c_Key2             = @cCaseID
                  ,@c_Key3             = @cStorerkey
                  ,@c_TransmitBatch    = ''
                  ,@b_Success          = @bSuccess   OUTPUT
                  ,@n_err              = @nErrNo     OUTPUT
                  ,@c_errmsg           = @cErrMsg    OUTPUT

                  IF @bSuccess <> 1
                  BEGIN
                     GOTO ROLLBACKTRAN
                  END

                  SET @nCaseCount = 0
                  SELECT @nCaseCount = COUNT(DISTINCT CASEID) FROM DBO.PICKDETAIL PD WITH(NOLOCK) WHERE PD.StorerKey=@cStorerKey AND PD.DropID = @cCaseID
                  IF @nCaseCount <> 1
                     CONTINUE

                  IF EXISTS(
                     SELECT 1 FROM dbo.PickDetail pd WITH(NOLOCK)
                     INNER JOIN dbo.ORDERS ord WITH(NOLOCK) ON ord.OrderKey = pd.OrderKey AND ord.StorerKey = pd.StorerKey
                     WHERE pd.StorerKey = @cStorerKey
                        AND pd.DropID = @cCaseID
                        AND pd.UOM = '2'
                        AND NOT EXISTS (SELECT 1 FROM dbo.WorkOrderDetail wod WITH(NOLOCK) WHERE wod.ExternWorkOrderKey = pd.OrderKey)
                        AND NOT EXISTS(SELECT 1 FROM dbo.codelkup cl WITH(NOLOCK) WHERE ord.ShipperKey = cl.short AND cl.listname = 'WSCourier' AND cl.code = 'ECL-1')
                  )
                  AND EXISTS (SELECT 1 FROM dbo.UCC WITH(NOLOCK) WHERE UCCNo = @cFromID AND StorerKey = @cStorerKey)
                  BEGIN
                     SELECT @cACTCaseID = CASEID FROM dbo.PICKDETAIL PD WITH(NOLOCK) WHERE pd.StorerKey = @cStorerKey AND pd.DropID = @cCaseID
                     --1. Login user's printer must = 'PANDA', then goes to ZPL print
                     EXEC rdt.rdt_LevisPrintCartonLabel
                        @nMobile       = @nMobile
                        ,@nFunc        = @nFunc
                        ,@cLangCode    = @cLangCode
                        ,@cStorerKey   = @cStorerKey
                        ,@nStep        = @nStep
                        ,@nInputKey    = @nInputKey
                        ,@cDropID      = @cACTCaseID
                        ,@cPrintType   = 'ZPL'
                        ,@nErrNo       = @nErrNo      OUTPUT
                        ,@cErrMsg      = @cErrMsg     OUTPUT

                     IF @nErrNo <> 0
                     BEGIN
                        GOTO ROLLBACKTRAN
                     END
                  END
               END
            END

            COMMIT TRAN rdt_1816ExtUpd02 -- Only commit change made here  
            GOTO Quit  
         END  
      END  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1816ExtUpd02 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO