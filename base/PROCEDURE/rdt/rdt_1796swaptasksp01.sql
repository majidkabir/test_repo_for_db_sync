SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1796SwapTaskSP01                                */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Swap Task Logic                                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 07-03-2017  1.1  ChewKP   WMS-1225 Add SwapTaskSP                    */
/* 08-11-2019  1.2  Ung      Fix SET option                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1796SwapTaskSP01] (
   @nMobile         INT,        
   @nFunc           INT,        
   @cLangCode       NVARCHAR( 3),   
   @nStep           INT,        
   @cStorerKey      NVARCHAR( 15),  
   @cFromLoc        NVARCHAR( 10),  
   @cFromID         NVARCHAR( 18),  
   @cListKey        NVARCHAR( 10),  
   @cUCC            NVARCHAR( 20),  
   @cTaskDetailKey  NVARCHAR( 10) OUTPUT,
   @cSuggToLOC      NVARCHAR( 10) OUTPUT,
   @nErrNo          INT OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
            @nTranCount          INT
           ,@b_success           INT
           ,@cUCCTaskDetailKey   NVARCHAR(10) 
           ,@cPAToLoc            NVARCHAR(10) 
           ,@cTDToLOC            NVARCHAR(10) 
           ,@cPAUCC              NVARCHAR(20) 
           ,@nPAQty              INT
           ,@nUCCQty             INT
           ,@nUCCRowRef          INT
           ,@nPARowRef           INT
           ,@cUCCLot             NVARCHAR(10)
           ,@cPALot              NVARCHAR(10) 
           ,@cUCCSKU             NVARCHAR(20) 
           ,@cPASKU              NVARCHAR(20) 
           ,@cPATaskDetailkey    NVARCHAR(10) 
           ,@cUserName           NVARCHAR(18) 
           

   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   --SET @cTaskDetailKey = '' 
   

   SET @nTranCount = @@TRANCOUNT
--
   BEGIN TRAN
   SAVE TRAN rdt_1796SwapTaskSP01


   IF @nFunc = 1796
   BEGIN
      IF @nStep = 3
      BEGIN
         --INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1, col2, Col3, Col4 , Col5 ) 
         --VALUES ( 'rdt_1796SwapTaskSP01' , GetdatE() , @cUCCTaskDetailKey, @cTDToLOC , @cFromLoc , @cUCC, @cFromID) 
         
         SELECT @cUserName = UserName 
         FROM rdt.rdtMobrec WITH (NOLOCK) 
         WHERE Mobile = @nMobile 
                 
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                     --AND ListKey = @cListKey
                     AND FromLoc = @cFromLoc
                     AND FromID = @cFromID
                     AND Status = '3' 
                     HAVING Count (TaskDetailKey) > 1 ) 
         BEGIN
            --SET @cSuggToLOC = ''
            
            SELECT 
               @cUCCTaskDetailKey = TaskDetailKey, 
               @cTDToLOC = ToLOC
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE FromLoc = @cFromLoc
               AND CaseID = @cUCC
               AND FromID = @cFromID
               AND Status = '3'
            
            SELECT TOP 1 
                @cPAToLOC = TD.ToLOC
               ,@cPATaskDetailkey = TD.TaskDetailKey
               ,@cPAUCC   = TD.CaseID
            FROM dbo.TaskDetail TD WITH (NOLOCK)
            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.LOC = TD.TOLOC
            WHERE TD.FromLoc = @cFromLoc
               AND TD.Status = '3'
               --AND TaskDetailKey = @cTaskDetailKey
               AND TD.FromID = @cFromID 
            Order by LOC.LOGICALLOCATION, TD.ToLoc

            IF ISNULL(@cTDToLOC,'') = '' 
            BEGIN 
                SET @nErrNo = 106558
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidUCC
                GOTO RollBackTran
            END
         
            --SELECT @cStorerKey '@cStorerKey', @cFromLOC '@cFromLOC', @cFromID '@cFromID', @cSuggToLoc '@cSuggToLoc' , @cPAToLoc '@cPAToLoc'  , @cUCC '@cUCC' , @cListKey '@cListKey' , @cTaskDetailKey '@cTaskDetailKey' , @cPAUCC '@cPAUCC', @cTDToLOC '@cTDToLOC'

            IF ISNULL(@cSuggToLoc,'')  <> ISNULL(@cTDToLOC ,'') 
            BEGIN
              SELECT @nUCCRowRef = RowRef
                    ,@nUCCQty = Qty 
                    ,@cUCCLot = Lot
                    ,@cUCCSKU = SKU 
              FROM dbo.RFPutaway WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND FromID = @cFromID
              AND CaseID = @cUCC 
              --AND FromLoc = @cFromLoc

           
              SELECT @nPARowRef = RowRef
                    ,@nPAQty = Qty 
                    ,@cPALot = Lot
                    ,@cPASKU = SKU 
              FROM dbo.RFPutaway WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND FromID = @cFromID
              AND CaseID = @cPAUCC
              --AND FromLoc = @cFromLoc

              
           
              UPDATE dbo.RFPutaway WITH (ROWLOCK) 
              SET SuggestedLoc = @cPAToLOC
              WHERE RowRef = @nUCCRowRef 
                      
              IF @@ERROR <> 0 
              BEGIN 
                SET @nErrNo = 106553
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRFPAFail
                GOTO RollBackTran
              END
           
              UPDATE dbo.RFPutaway WITH (ROWLOCK) 
              SET SuggestedLoc = @cTDToLOC
              WHERE RowRef = @nPARowRef 
                      
              IF @@ERROR <> 0 
              BEGIN 
                SET @nErrNo = 106554
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdRFPAFail
                GOTO RollBackTran
              END
           
           
              UPDATE dbo.LotxLocxID WITH (ROWLOCK) 
              SET PendingMoveIn = @nUCCQty 
                 ,Loc           = @cPAToLoc
                 ,Trafficcop    = NULL  
              WHERE StorerKey = @cStorerKey
              AND SKU = @cUCCSKU 
              AND ID = @cUCC
              AND LOT = @cUCCLot
              AND Loc = @cTDToLOC
              AND Qty = 0 
           
              IF @@ERROR <> 0 
              BEGIN 
                SET @nErrNo = 106555
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLLIFail
                GOTO RollBackTran
              END
           
              UPDATE dbo.LotxLocxID WITH (ROWLOCK) 
              SET PendingMoveIn = @nPAQty 
                 ,Loc           = @cTDToLoc
                 ,Trafficcop    = NULL  
              WHERE StorerKey = @cStorerKey
              AND SKU = @cPASKU 
              AND ID  = @cPAUCC
              AND LOT = @cPALot
              AND Loc = @cPAToLOC
              AND Qty = 0 
           
              IF @@ERROR <> 0 
              BEGIN 
                SET @nErrNo = 106556
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdLLIFail
                GOTO RollBackTran
              END
           
              
              UPDATE dbo.TaskDetail WITH (ROWLOCK) 
              SET ToLoc = @cTDToLOC 
                 , ToID = RIGHT(@cPAUCC,18) 
                 , CaseID = @cPAUCC
                 --, Status = '0' 
                 , TrafficCop = NULL
              WHERE StorerKey = @cStorerKey
              AND TaskDetailKey = @cPATaskDetailkey 
           
              IF @@ERROR <> 0 
              BEGIN
                SET @nErrNo = 106552
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                GOTO RollBackTran
              END   
                        

              UPDATE dbo.TaskDetail WITH (ROWLOCK) 
              SET ToLoc = @cPAToLoc 
                , ToID  = RIGHT(@cUCC ,18) 
                , CaseID = @cUCC
                --, Status = '3' 
                --, UserKey = @cUserName
                --, ListKey = @cListKey
                , TrafficCop = NULL
              WHERE StorerKey = @cStorerKey
              AND TaskDetailKey = @cUCCTaskDetailKey 
           
              IF @@ERROR <> 0 
              BEGIN
                SET @nErrNo = 106551
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
                GOTO RollBackTran
              END
              
           
            
              SET @cSuggToLoc = @cPAToLoc 
              SET @cTaskDetailKey = @cUCCTaskDetailKey

              
            END
            ELSE
            BEGIN
           
              

              SET @cTaskDetailKey = @cUCCTaskDetailKey 
              SET @cSuggToLoc = @cTDToLOC 
              GOTO QUIT
            
            END
         END
         ELSE
         BEGIN
            
            
            SELECT TOP 1 
                @cPAToLOC = ToLOC
               ,@cTaskDetailKey = TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE FromLoc = @cFromLoc
               AND Status = '3' --Fetch   
               AND CaseID = @cUCC
               AND FromID = @cFromID 
            Order by ToLoc

            IF ISNULL(@cPAToLoc,'')  = '' 
            BEGIN 
                SET @nErrNo = 106557
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidUCC
                GOTO RollBackTran
            END
         
            SET @cSuggToLoc = @cPAToLOC 
            GOTO QUIT
         END
         

      
      END
   END



   GOTO QUIT


   RollBackTran:
   ROLLBACK TRAN rdt_1796SwapTaskSP01

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN rdt_1796SwapTaskSP01


Fail:
END






GO