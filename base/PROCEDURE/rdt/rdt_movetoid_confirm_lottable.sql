SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_MoveToID_Confirm_lottable                       */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2021-12-28 1.0  YeeKung    JSM-42479. Created                        */     
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_MoveToID_Confirm_lottable] (    
   @nMobile    INT,    
   @nFunc      INT,     
   @cLangCode  NVARCHAR( 3),     
   @cType      NVARCHAR( 1),   --Y=Confirm, N=Undo    
   @cStorerKey NVARCHAR( 15),     
   @cToID      NVARCHAR( 18),     
   @cFromLOC   NVARCHAR( 10),     
   @cSKU       NVARCHAR( 20),     
   @cUCC       NVARCHAR( 20),    
   @nQTY       INT,    
   @cLottable01 NVARCHAR( 18), 
   @cLottable02 NVARCHAR( 18), 
   @cLottable03 NVARCHAR( 18), 
   @dLottable04 DATETIME,      
   @dLottable05 DATETIME,      
   @cLottable06 NVARCHAR( 30), 
   @cLottable07 NVARCHAR( 30), 
   @cLottable08 NVARCHAR( 30), 
   @cLottable09 NVARCHAR( 30), 
   @cLottable10 NVARCHAR( 30), 
   @cLottable11 NVARCHAR( 30), 
   @cLottable12 NVARCHAR( 30), 
   @dLottable13 DATETIME,      
   @dLottable14 DATETIME,      
   @dLottable15 DATETIME,      
   @nErrNo     INT       OUTPUT,     
   @cErrMsg    NVARCHAR( 20) OUTPUT    
)    
AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @cFacility NVARCHAR( 5)    
   DECLARE @cFromLOT  NVARCHAR( 10)    
   DECLARE @cFromID   NVARCHAR( 18)    
   DECLARE @nQTYAvail INT    
   DECLARE @nQTYMove  INT    
   DECLARE @nQTYBal   INT       
   DECLARE @curLLI    CURSOR    
   DECLARE @cLottableCode NVARCHAR(20)
   DECLARE @cWhere NVARCHAR (max)
   DECLARE @cSQL NVARCHAR(MAX)
   DECLARE @cSQLParam NVARCHAR(MAX)
    
   DECLARE @nTranCount INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_MoveToID_Confirm    


   -- Get SKU info
   SELECT
      @cLottableCode = LottableCode  
   FROM dbo.SKU S WITH (NOLOCK)
      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (S.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
   
   -- Get lottable filter  
   EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, 5, 1, @cFacility, @cStorerKey, @cLottableCode, 5, 'LA',   
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
      @cWhere   OUTPUT,  
      @nErrNo   OUTPUT,  
      @cErrMsg  OUTPUT  

   SET @cSQL =     
  ' SET @curLLI = CURSOR FOR '+
   ' SELECT LLI.LOT, LLI.LOC, ID, LLI.SKU, QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)     ' +    
   ' FROM dbo.LOTxLOCxID LLI(NOLOCK) ' +    
   ' JOIN dbo.LotAttribute LA (NOLOCK) ON (LLI.LOT = LA.LOT) ' +
   ' WHERE LLI.StorerKey = @cStorerKey ' +    
   ' AND   LLI.LOC = @cFromLOC ' +    
   ' AND   LLI.SKU = @cSKU ' +  
   ' AND   (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0 ' +
   ' AND   LLI.ID = CASE WHEN ISNULL( @cFromID, '''') = '''' THEN LLI.ID ELSE @cFromID END '   
   + CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END 
   + ' OPEN @curLLI'
      
   SET @cSQLParam =   
      ' @cStorerKey  NVARCHAR( 15), ' +   
      ' @cFromLOC    NVARCHAR( 10), ' +   
      ' @cFromID     NVARCHAR( 18), ' +   
      ' @cSKU        NVARCHAR( 20), ' +   
      ' @cLottable01 NVARCHAR( 18), ' +   
      ' @cLottable02 NVARCHAR( 18), ' +   
      ' @cLottable03 NVARCHAR( 18), ' +   
      ' @dLottable04 DATETIME,      ' +   
      ' @dLottable05 DATETIME,      ' +   
      ' @cLottable06 NVARCHAR( 30), ' +   
      ' @cLottable07 NVARCHAR( 30), ' +   
      ' @cLottable08 NVARCHAR( 30), ' +   
      ' @cLottable09 NVARCHAR( 30), ' +   
      ' @cLottable10 NVARCHAR( 30), ' +   
      ' @cLottable11 NVARCHAR( 30), ' +   
      ' @cLottable12 NVARCHAR( 30), ' +   
      ' @dLottable13 DATETIME,      ' +   
      ' @dLottable14 DATETIME,      ' +   
      ' @dLottable15 DATETIME,      ' +    
      ' @curLLI  CURSOR           OUTPUT '
 
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cStorerKey, @cFromLOC, @cFromID, @cSKU,   
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
      @curLLI  OUTPUT


   IF @cType = 'Y' -- Confirm    
   BEGIN    
      SET @nQTYBal = @nQTY    
   
      FETCH NEXT FROM @curLLI INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYAvail    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         -- Get facility    
         IF @cFacility = ''    
            SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC    
       
         -- Calc QTY    
         IF @nQTYAvail >= @nQTYBal    
            SET @nQTYMove = @nQTYBal    
         ELSE    
            SET @nQTYMove = @nQTYAvail    
                
         -- Increase LOTxLOCxID.QTYReplen    
         UPDATE dbo.LOTxLOCxID SET     
            QTYReplen = QTYReplen + @nQTYMove    
         WHERE LOT = @cFromLOT    
            AND LOC = @cFromLOC    
            AND ID = @cFromID    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 180451    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail    
            GOTO RollBackTran    
         END    
             
         IF ISNULL(@cUCC,'')  = ''     
         BEGIN    
            -- Update Log    
            IF EXISTS( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK)     
                       WHERE StorerKey = @cStorerKey    
                           AND ToID = @cToID    
                           AND FromLOT = @cFromLOT     
                           AND FromLOC = @cFromLOC     
                           AND FromID = @cFromID)    
            BEGIN    
               UPDATE rdt.rdtMoveToIDLog SET    
                  QTY = QTY + @nQTYMove    
               WHERE StorerKey = @cStorerKey    
                  AND ToID = @cToID    
                  AND FromLOT = @cFromLOT    
                  AND FromLOC = @cFromLOC    
                  AND FromID = @cFromID    
               IF @@ERROR <> 0    
   BEGIN    
                  SET @nErrNo = 180452    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail    
                  GOTO RollBackTran    
               END    
            END    
            ELSE    
            BEGIN    
               INSERT INTO rdt.rdtMoveToIDLog (StorerKey, ToID, FromLOT, FromLOC, FromID, SKU, QTY)    
               VALUES (@cStorerKey, @cToID, @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYMove )     
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 180453    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail    
                  GOTO RollBackTran    
               END    
            END    
         END    
         ELSE     
         BEGIN    
            INSERT INTO rdt.rdtMoveToIDLog (StorerKey, ToID, FromLOT, FromLOC, FromID, SKU, QTY, UCC)    
            VALUES (@cStorerKey, @cToID, @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYMove, @cUCC )     
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 180457    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail    
               GOTO RollBackTran    
            END    
         END    
     
         SET @nQTYBal = @nQTYBal - @nQTYMove    
         IF @nQTYBal = 0    
            BREAK    
       
         FETCH NEXT FROM @curLLI INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYAvail    
      END    
          
      -- Check QTY fully offset    
      IF @nQTYBal <> 0    
      BEGIN    
         SET @nErrNo = 180454    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotEnuf QTYAVL    
         GOTO RollBackTran    
      END    
   END    
       
    
   IF @cType = 'N' -- Undo    
   BEGIN    
      -- Loop rdtMoveToIDLog    
      SET @curLLI = CURSOR FOR     
         SELECT FromLOT, FromLOC, FromID, QTY    
         FROM rdt.rdtMoveToIDLog WITH (NOLOCK)     
         WHERE StorerKey = @cStorerKey    
            AND ToID = @cToID    
      OPEN @curLLI    
      FETCH NEXT FROM @curLLI INTO @cFromLOT, @cFromLOC, @cFromID, @nQTYMove    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         -- Reduce LOTxLOCxID.QTYReplen    
         UPDATE dbo.LOTxLOCxID SET     
            QTYReplen = CASE WHEN QTYReplen - @nQTYMove >= 0 THEN QTYReplen - @nQTYMove ELSE 0 END    
         WHERE LOT = @cFromLOT    
            AND LOC = @cFromLOC    
            AND ID = @cFromID    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 180455    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail    
            GOTO RollBackTran    
         END    
             
         -- Delete rdtMoveToIDLog    
         DELETE rdt.rdtMoveToIDLog    
         WHERE StorerKey = @cStorerKey    
            AND ToID = @cToID    
            AND FromLOT = @cFromLOT    
            AND FromLOC = @cFromLOC    
            AND FromID = @cFromID    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 180456    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail    
            GOTO RollBackTran    
         END    
             
         FETCH NEXT FROM @curLLI INTO @cFromLOT, @cFromLOC, @cFromID, @nQTYMove    
      END    
   END    
   GOTO Quit    
    
RollBackTran:    
      ROLLBACK TRAN rdt_MoveToID_Confirm    
Quit:             
   WHILE @@TRANCOUNT > @nTranCount    
      COMMIT TRAN 

GO