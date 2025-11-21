SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_Putaway_PendingMoveIn                                 */  
/* Copyright      : IDS                                                       */  
/*                                                                            */  
/* Purpose: Update LotxLocxID.PendingMoveIn                                   */  
/*          Update RFPutaway, to lock / unlock location                       */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author   Purposes                                          */  
/* 2012-11-21 1.0  Ung      SOS257047 Created                                 */  
/* 2014-04-09 1.1  TLTING   Deadlock issue                                    */  
/* 2015-01-05 1.2  Ung      SOS328774 Unlock by QTY                           */  
/* 2015-03-26 1.3  Ung      SOS337296 Add TaskDetaiKey, Func, PABookingKey    */  
/*                          Fix book by ID with LoseID                        */  
/* 2015-08-26 1.4  Ung      SOS346283 Return @cErrMsg                         */  
/* 2017-06-23 1.5  Ung      WMS-1986 MoveQTYAlloc for Exceed                  */  
/* 2017-09-11 1.6  NJOW01   WMS-3178 Cater for empty toid booking for task    */  
/*                          and fix unblock                                   */  
/* 2018-07-25 1.7  NJOW02   Fix - check if toid is empty get fromid           */  
/* 2019-07-25 1.8  Ung      LWP-2 Performance tuning                          */  
/* 2019-10-30 1.9  James    WMS-10316 Add MoveQTYPick (james01)               */  
/* 2020-03-09 2.0  Ung      INC1066142 Fix trigger ErrMsg not output          */  
/* 2020-08-07 2.1  James    WMS-14152 Add MoveQTYReplen (james02)             */  
/* 2021-10-26 2.2  CheeMun  JSM-28849 Fix Dynamic SQL Syntax error            */  
/* 2021-03-24 2.3  Chermaine WMS-16328 Add RowRef                             */  
/*                          Add QTYPrinted                                    */  
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_Putaway_PendingMoveIn] (  
   @cUserName        NVARCHAR( 10),  
   @cType            NVARCHAR( 10),      -- LOCK / UNLOCK  
   @cFromLOC         NVARCHAR( 10),  
   @cFromID          NVARCHAR( 18),  
   @cSuggestedLOC    NVARCHAR( 10),  
   @cStorerKey       NVARCHAR( 15),  
   @nErrNo           INT           OUTPUT,  
   @cErrMsg          NVARCHAR( 20) OUTPUT,   
   @cSKU             NVARCHAR( 20) = '',  
   @nPutawayQTY      INT           = 0,  
   @cUCCNo           NVARCHAR( 20) = '',   
   @cFromLOT         NVARCHAR( 10) = '',   
   @cToID            NVARCHAR( 18) = '',   
   @cTaskDetailKey   NVARCHAR(10) = '',   
   @nFunc            INT = 0,   
   @nPABookingKey    INT = 0       OUTPUT,   
   @cMoveQTYAlloc    NVARCHAR(1) = NULL,   -- For Exceed only  
   @cMoveQTYPick     NVARCHAR(1) = NULL,     
   @cMoveQTYReplen   NVARCHAR(1) = NULL,   
   @nRowRef          INT         = 0,   
   @nQTYPrinted      INT         = 0  
) AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   SET @cErrMsg = ''   
  
   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_Putaway_PendingMoveIn -- For rollback or commit only our own transaction  
  
   DECLARE @curPending CURSOR  
   DECLARE @cLOT NVARCHAR( 10)  
   DECLARE @cLOC NVARCHAR( 10)  
   DECLARE @cID  NVARCHAR( 18)  
   DECLARE @nQTY INT  
   DECLARE @nRF_QTY INT  
   DECLARE @nLLI_QTY INT  
   DECLARE @cLLI_SKU NVARCHAR( 20)  
   DECLARE @cLLI_StorerKey NVARCHAR( 15)  
   -- DECLARE @nRowRef INT      -- tlting     
   DECLARE @nDelRFPutaway INT  
   DECLARE @nBal INT  
   DECLARE @cLoseID NCHAR(1) --NJOW01  
   DECLARE @cSQL NVARCHAR( MAX)  
   DECLARE @cSQLParam NVARCHAR( MAX)  
        
   IF @nPutawayQTY = 0  
      SET @nPutawayQTY = NULL  
     
   --NJOW01     
   SELECT @cLoseID = LoseID  
   FROM LOC (NOLOCK)  
   WHERE Loc = @cSuggestedLOC     
  
   IF @cType = 'LOCK'  
   BEGIN  
      IF @cMoveQTYAlloc IS NULL  
         SET @cMoveQTYAlloc = rdt.RDTGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)  
  
      IF @cMoveQTYPick IS NULL  
         SET @cMoveQTYPick = rdt.RDTGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)  
  
      IF @cMoveQTYReplen IS NULL  
         SET @cMoveQTYReplen = rdt.RDTGetConfig( @nFunc, 'MoveQTYReplen', @cStorerKey)  
  
      /*  
      SET @curPending = CURSOR FOR  
         SELECT   
            LLI.StorerKey,   
            LLI.SKU,   
            LLI.LOT,   
            --CASE -- WHEN LOC.LoseID = '1' THEN ''   
            --     WHEN @cToID <> '' THEN @cToID  
            --     ELSE @cFromID   
            --END,   
            CASE WHEN ISNULL(@cTaskDetailKey,'') <> '' AND @cLoseId = '1' THEN ''  --NJOW01                   
                 WHEN ISNULL(@cTaskDetailKey,'') <> '' AND @cLoseId <> '1' THEN   
                    CASE WHEN ISNULL(@cToID,'') <> '' THEN @cToID ELSE @cFromID END --NJOW02  
                 WHEN @cToID <> '' THEN @cToID    
                 ELSE @cFromID   
            END,       
            CASE WHEN @cMoveQTYAlloc = '1'  
                 THEN (LLI.QTY - LLI.QTYPicked)  
                 ELSE (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
            END  
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)  
         WHERE LLI.StorerKey = CASE WHEN @cStorerKey = '' THEN StorerKey ELSE @cStorerKey END  
            AND LLI.SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END  
            AND LLI.LOT = CASE WHEN @cFromLOT = '' THEN LOT ELSE @cFromLOT END  
            AND LLI.LOC = @cFromLOC  
            AND LLI.ID  = @cFromID  
            AND CASE WHEN @cMoveQTYAlloc = '1'  
                     THEN (LLI.QTY - LLI.QTYPicked)  
                     ELSE (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))  
                END > 0  
         ORDER BY LLI.LOT  
      */  
        
      SET @cSQL =   
         ' SET @curPending = CURSOR FOR ' +   
            ' SELECT ' +   
               ' LLI.StorerKey, ' +   
               ' LLI.SKU, ' +   
               ' LLI.LOT, ' +   
               ' CASE WHEN ISNULL(@cTaskDetailKey,'''') <> '''' AND @cLoseId = ''1'' THEN ''''  ' +   
                    ' WHEN ISNULL(@cTaskDetailKey,'''') <> '''' AND @cLoseId <> ''1'' THEN ' +   
                       ' CASE WHEN ISNULL(@cToID,'''') <> '''' THEN @cToID ELSE @cFromID END ' +   
                    ' WHEN @cToID <> '''' THEN @cToID ' +   
                    ' ELSE @cFromID ' +   
               ' END, ' +   
               ' ( LLI.QTY ' +   
               CASE WHEN @cMoveQTYAlloc = '1' THEN '' ELSE ' - LLI.QTYAllocated ' END +   
               CASE WHEN @cMoveQTYPick = '1' THEN '' ELSE ' - LLI.QTYPicked ' END +   
               CASE WHEN @cMoveQTYReplen = '1' THEN '' ELSE ' - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' END +  
               ' ) ' +   
            ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +   
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC) ' +   
            ' WHERE LLI.LOC = @cFromLOC ' +   
               ' AND LLI.ID = @cFromID '  
        
      -- Filter   
      IF @cStorerKey <> '' SET @cSQL = @cSQL + ' AND LLI.StorerKey = @cStorerKey '  
      IF @cSKU       <> '' SET @cSQL = @cSQL + ' AND LLI.SKU = @cSKU '  
      IF @cFromLOT   <> '' SET @cSQL = @cSQL + ' AND LLI.LOT = @cFromLOT '  
  
      SET @cSQL = @cSQL + ' AND LLI.QTY ' +   
         CASE WHEN @cMoveQTYAlloc = '1' THEN '' ELSE ' - LLI.QTYAllocated  ' END +      --JSM-28849  
         CASE WHEN @cMoveQTYPick = '1' THEN '' ELSE ' - LLI.QTYPicked  ' END +          --JSM-28849  
         CASE WHEN @cMoveQTYReplen = '1' THEN '' ELSE ' - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' END +  
         '  > 0'  
           
      -- Sorting  
      SET @cSQL = @cSQL + ' ORDER BY LLI.LOT '  
  
        
      -- Open cursor  
      SET @cSQL = @cSQL + ' OPEN @curPending '  
  
      SET @cSQLParam =   
         ' @cTaskDetailKey NVARCHAR( 10), ' +   
         ' @cLoseId        NVARCHAR( 1),  ' +   
         ' @cFromID        NVARCHAR( 18), ' +   
         ' @cToID          NVARCHAR( 18), ' +     
         ' @cFromLOC       NVARCHAR( 10), ' +   
         ' @cStorerKey     NVARCHAR( 15), ' +   
         ' @cSKU           NVARCHAR( 20), ' +   
         ' @cFromLOT       NVARCHAR( 10), ' +   
         ' @curPending     CURSOR OUTPUT  ' 
		 
	
      EXEC sp_executeSQL @cSQL, @cSQLParam   
         ,@cTaskDetailKey = @cTaskDetailKey  
         ,@cLoseId        = @cLoseId  
         ,@cFromID        = @cFromID  
         ,@cToID          = @cToID  
         ,@cFromLOC       = @cFromLOC  
         ,@cStorerKey     = @cStorerKey  
         ,@cSKU           = @cSKU  
         ,@cFromLOT       = @cFromLOT  
         ,@curPending     = @curPending OUTPUT  

         print @cSQL
      -- OPEN @curPending  
      FETCH NEXT FROM @curPending INTO @cLLI_StorerKey, @cLLI_SKU, @cLOT, @cID, @nLLI_QTY  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         print @cLLI_StorerKey+','+@cLLI_SKU+','+@cLOT+','+@cID+','+convert(varchar(15),@nLLI_QTY)
         -- Calc PendingMoveIn  
         IF @nPutawayQTY IS NULL  
            SET @nQTY = @nLLI_QTY  
         ELSE IF @nPutawayQTY > @nLLI_QTY  
            SET @nQTY = @nLLI_QTY  
         ELSE  
            SET @nQTY = @nPutawayQTY  
  
         -- Lock location  
         INSERT INTO dbo.RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID, TaskDetailKey, Func, PABookingKey, QTYPrinted)  
         VALUES (@cLLI_StorerKey, @cLLI_SKU, @cLOT, @cFromLOC, @cFromID, @cSuggestedLOC, @cID, @cUserName, @nQTY, @cUCCNo, @cTaskDetailKey, @nFunc, @nPABookingKey, @nQTYPrinted)  
         SET @nErrNo = @@ERROR  
         IF @nErrNo <> 0  
         BEGIN  

            -- SET @nErrNo = 78101  
            -- SET @cErrMsg = '78101 UPD RPA FAIL'  
           GOTO RollbackTran  
         END  

  
         -- Get and update PABookingKey  
         IF @nPABookingKey = 0  
         BEGIN  
            SET @nPABookingKey = SCOPE_IDENTITY()  
            UPDATE dbo.RFPutaway SET  
               PABookingKey = @nPABookingKey  
            WHERE RowRef = @nPABookingKey  
            IF @@ERROR <> 0  
               GOTO RollbackTran  
         END  
  
         -- Create ToID if not exist  
         IF @cID <> ''  
         BEGIN  
            IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @cID)  
            BEGIN  
               INSERT INTO ID (ID) VALUES (@cID)  
               IF @@ERROR <> 0  
               BEGIN  
                 SET @nErrNo = 78106  
                 SET @cErrMsg = '78106 INS ID FAIL'  
                 GOTO RollbackTran  
               END  
            END  
         END  
           
         -- Update PendingMoveIn  
         IF EXISTS (SELECT 1   
            FROM dbo.LOTxLOCxID WITH (NOLOCK)  
            WHERE LOT = @cLOT  
               AND LOC = @cSuggestedLOC  
               AND ID = @cID)  
         BEGIN  
            UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET   
               PendingMoveIn = CASE WHEN PendingMoveIn >= 0 THEN PendingMoveIn + @nQTY ELSE 0 END  
            WHERE LOT = @cLOT  
               AND LOC = @cSuggestedLoc  
               AND ID  = @cID  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 78102  
               SET @cErrMsg = '78102 UPD LLI FAIL'  
               GOTO RollbackTran  
            END  
         END  
         ELSE  
         BEGIN  
            INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)  
            VALUES (@cLOT, @cSuggestedLOC, @cID, @cLLI_StorerKey, @cLLI_SKU, @nQTY)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 78103  
 SET @cErrMsg = '78103 UPD LLI FAIL'  
               GOTO RollbackTran  
            END  
         END  
  
         IF @nPutawayQTY IS NOT NULL  
         BEGIN  
            SET @nPutawayQTY = @nPutawayQTY - @nQTY  
            IF @nPutawayQTY = 0  
               BREAK  
         END  
           
         FETCH NEXT FROM @curPending INTO @cLLI_StorerKey, @cLLI_SKU, @cLOT, @cID, @nLLI_QTY  
      END  
   END  
  
   IF @cType = 'UNLOCK'  
   BEGIN  
      IF ISNULL( @cUserName     , '') = '' AND  
         ISNULL( @cSuggestedLOC , '') = '' AND  
         ISNULL( @cFromID       , '') = '' AND  
         ISNULL( @cUCCNo        , '') = '' AND  
         ISNULL( @cSKU          , '') = '' AND  
         ISNULL( @cTaskDetailKey, '') = '' AND  
         ISNULL( @nPABookingKey , '') = 0  AND  
         ISNULL( @nRowRef       , '') = 0    
      BEGIN  
         SET @nErrNo = 78107  
         SET @cErrMsg = '78107 DEL ALL REC!!!'  
         GOTO RollBackTran  
      END  
        
      IF @nPutawayQTY IS NOT NULL  
         SET @nBal = @nPutawayQTY  
        
      IF @nPABookingKey <> 0  
      BEGIN  
         SET @curPending = CURSOR FOR  
            SELECT LOT, SuggestedLOC, ID, QTY, RowRef  
            FROM dbo.RFPutaway WITH (NOLOCK)  
            WHERE PABookingKey = @nPABookingKey  
         OPEN @curPending  
      END  
      ELSE IF @nRowRef <> 0  
      BEGIN  
         SET @curPending = CURSOR FOR  
            SELECT LOT, SuggestedLOC, ID, QTY, RowRef  
            FROM dbo.RFPutaway WITH (NOLOCK)  
            WHERE RowRef = @nRowRef  
         OPEN @curPending  
      END  
      ELSE  
      BEGIN  
         /*  
         SET @curPending = CURSOR FOR  
            SELECT LOT, SuggestedLOC, ID, QTY, RowRef  
            FROM dbo.RFPutaway WITH (NOLOCK)  
            WHERE  ptcid         = CASE WHEN @cUserName = ''      THEN ptcid         ELSE @cUserName      END  
               AND SuggestedLOC  = CASE WHEN @cSuggestedLOC = ''  THEN SuggestedLOC  ELSE @cSuggestedLOC  END  
               AND (FromID       = CASE WHEN @cFromID = ''        THEN FromID        ELSE @cFromID        END   
                OR  ID           = CASE WHEN @cFromID = ''        THEN ID            ELSE @cFromID        END)  
               AND CaseID        = CASE WHEN @cUCCNo = ''         THEN CaseID        ELSE @cUCCNo         END  
               AND SKU           = CASE WHEN @cSKU = ''           THEN SKU           ELSE @cSKU           END  
               AND TaskDetailKey = CASE WHEN @cTaskDetailKey = '' THEN TaskDetailKey ELSE @cTaskDetailKey END  
         */  
         SET @cSQL =   
            ' SET @curPending = CURSOR FOR ' +   
               ' SELECT LOT, SuggestedLOC, ID, QTY, RowRef ' +   
               ' FROM dbo.RFPutaway WITH (NOLOCK) '  
           
         -- Filter  
         DECLARE @cWhere NVARCHAR( MAX)  
         SET @cWhere = ''  
         IF @cUserName      <> '' SET @cWhere = @cWhere + ' AND ptcid = @cUserName '  
         IF @cSuggestedLOC  <> '' SET @cWhere = @cWhere + ' AND SuggestedLOC = @cSuggestedLOC '  
         IF @cFromID        <> '' SET @cWhere = @cWhere + ' AND (FromID = @cFromID OR ID = @cFromID) '  
         IF @cUCCNo         <> '' SET @cWhere = @cWhere + ' AND CaseID = @cUCCNo '  
         IF @cSKU           <> '' SET @cWhere = @cWhere + ' AND SKU = @cSKU '  
         IF @cTaskDetailKey <> '' SET @cWhere = @cWhere + ' AND TaskDetailKey = @cTaskDetailKey '  
         IF @cWhere <> ''  
            SET @cSQL = @cSQL + ' WHERE ' + SUBSTRING( @cWhere, 6, LEN( @cWhere))  
  print @csql
         -- Open cursor  
         SET @cSQL = @cSQL + ' OPEN @curPending '  
  
         SET @cSQLParam =   
            ' @cUserName      NVARCHAR( 10), ' +   
            ' @cSuggestedLOC  NVARCHAR( 10), ' +   
            ' @cFromID        NVARCHAR( 18), ' +   
            ' @cUCCNo         NVARCHAR( 20), ' +   
            ' @cSKU           NVARCHAR( 20), ' +   
            ' @cTaskDetailKey NVARCHAR( 10), ' +   
            ' @curPending     CURSOR OUTPUT  '  
           
         EXEC sp_executeSQL @cSQL, @cSQLParam   
            ,@cUserName      = @cUserName  
            ,@cSuggestedLOC  = @cSuggestedLOC  
            ,@cFromID        = @cFromID  
            ,@cUCCNo         = cUCCNo  
            ,@cSKU           = @cSKU  
            ,@cTaskDetailKey = @cTaskDetailKey  
            ,@curPending     = @curPending OUTPUT  
      END  
        
      -- OPEN @curPending  
      FETCH NEXT FROM @curPending INTO @cLOT, @cLOC, @cID, @nRF_QTY, @nRowRef  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF @nPutawayQTY IS NULL  
         BEGIN  
            SET @nDelRFPutaway = 1 -- Yes  
            SET @nQTY = @nRF_QTY --NJOW01  
         END  
         ELSE  
         BEGIN  
            -- Unlock by QTY, calc delete or update RFPutaway  
            IF @nRF_QTY <= @nBal  
            BEGIN  
               SET @nDelRFPutaway = 1 -- Yes  
               SET @nQTY = @nRF_QTY  
               SET @nBal = @nBal - @nRF_QTY  
            END  
            ELSE  
            BEGIN  
               SET @nDelRFPutaway = 0 -- No  
               SET @nQTY = @nBal  
               SET @nBal = 0  
            END  
         END  
           PRINT @nqty
         IF EXISTS (SELECT 1   
            FROM dbo.LOTxLOCxID WITH (NOLOCK)  
            WHERE LOT = @cLOT  
            AND LOC = @cLOC  
            AND ID = @cID)  
         BEGIN  
            UPDATE dbo.LotxLocxID WITH (ROWLOCK) SET   
               PendingMoveIn = CASE WHEN PendingMoveIn - @nQTY >= 0 THEN PendingMoveIn - @nQTY ELSE 0 END  
            WHERE Lot = @cLOT  
               AND Loc = @cLOC  
               AND ID  = @cID  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 78104  
               SET @cErrMsg = '78104 UPD LLI FAIL'  
               GOTO RollBackTran  
            END  
         END  
           
         IF @nDelRFPutaway = 1  
         BEGIN  
            DELETE dbo.RFPutaway WITH (ROWLOCK)  
            WHERE  RowRef = @nRowRef  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 78105  
               SET @cErrMsg = '78105 DEL RPA FAIL'  
               GOTO RollBackTran  
            END           
         END  
         ELSE  
         BEGIN  
            UPDATE dbo.RFPutaway SET   
               QTY = QTY - @nQTY  
            WHERE RowRef = @nRowRef  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 78106  
               SET @cErrMsg = '78106 UPD RPA FAIL'  
               GOTO RollBackTran  
            END  
         END   
  
         -- Unlock by QTY and no balance  
         IF @nPutawayQTY IS NOT NULL   
            IF @nBal = 0  
               BREAK  
  
         FETCH NEXT FROM @curPending INTO @cLOT, @cLOC, @cID, @nRF_QTY, @nRowRef  
      END  
   END  
  
   COMMIT TRAN rdt_Putaway_PendingMoveIn -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
BEGIN  
   ROLLBACK TRAN rdt_Putaway_PendingMoveIn -- Only rollback change made here  
     
   -- Get ErrMsg, when trigger only output ErrNo  
   IF @nErrNo > 0 AND @cErrMsg = ''  
   BEGIN  
      DECLARE @n_IsRDT INT  
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT  
      IF @n_IsRDT = 1  
      BEGIN  
         DECLARE @cLangCode NVARCHAR(3)  
         SELECT TOP 1 @cLangCode = Lang_code FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
      END  
   END  
END  
  
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO