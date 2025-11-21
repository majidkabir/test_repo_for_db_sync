SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1815ExtPA02                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-08-03  1.0  Chermaine WMS-17638 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1815ExtPA02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cTaskDetailKey   NVARCHAR( 10),
   @cFromLOC         NVARCHAR( 10),
   @cFromID          NVARCHAR( 18),
   @cSuggLOC         NVARCHAR( 10)  OUTPUT,
   @cPickAndDropLOC  NVARCHAR( 10)  OUTPUT,
   @cFitCasesInAisle NVARCHAR( 1)   OUTPUT,
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
   
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount       INT
   DECLARE @cSQL             NVARCHAR( MAX)
   DECLARE @cSQLParam        NVARCHAR( MAX)
   
   DECLARE 
   	@cPAStrategyKey   NVARCHAR(20),
      @cPutawayZone     NVARCHAR(20),
      @cProductCategory NVARCHAR(5),
      @cToLoc           NVARCHAR(10),
      @cID              NVARCHAR(20),
      @cCode            NVARCHAR(10),
      @cFinalLoc        NVARCHAR(20),
      @cParam1          NVARCHAR(10),  
      @cParam2          NVARCHAR(20),
      @cParam3          NVARCHAR(20),
      @cParam4          NVARCHAR(20),
      @cParam5          NVARCHAR(20), 
      @cLocAisle        NVARCHAR(10),
      @cToLogicalLocation   NVARCHAR( 10),  
      @cLogicalLocation     NVARCHAR( 10),  
      @nPltCtnCount     INT,
      @nPltMaxCnt       INT,
      @nFullPlt         INT
   
   SET @cFinalLoc = ''
   SET @cPickAndDropLOC = ''  
   SET @cToLoc = ''
      
   SELECT 
      @cProductCategory = SKU.SKUGroup,--@cProductCategory = BUSR7,  
      @cPutawayZone = SKU.PutawayZone  
   FROM dbo.UCC UCC WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( UCC.Loc = LOC.Loc)  
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SKU.SKU = UCC.SKU AND SKU.storerKey = Ucc.StorerKey)
   WHERE UCC.Storerkey = @cStorerKey  
   AND   UCC.LOC = @cFromLOC  
   AND   UCC.ID = @cFromID  
   AND   UCC.Status = '1'  
   AND   LOC.Facility = @cFacility   

   SELECT @nPltMaxCnt = Short  
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'PAPltMxCnt'  
   AND   Code = @cProductCategory  
   AND   Storerkey = @cStorerKey 

   -- Get total carton on pallet  
   SELECT @nPltCtnCount = COUNT( DISTINCT UCCNo)  
   FROM dbo.UCC UCC WITH (NOLOCK)  
   JOIN dbo.LOC LOC WITH (NOLOCK) ON ( UCC.Loc = LOC.Loc)  
   WHERE UCC.Storerkey = @cStorerKey  
   AND   UCC.LOC = @cFromLOC  
   AND   UCC.ID = @cFromID  
   AND   UCC.Status = '1'  
   AND   LOC.Facility = @cFacility 

   -- Define full or loose pallet  
   IF @nPltCtnCount < @nPltMaxCnt  
   BEGIN  
      SET @nFullPlt = 0  
   END  
   ELSE  
      SET @nFullPlt = 1  

   -- Get product category from codelkup  
   SET @cCode = RTRIM( @cProductCategory) + CAST( @nFullPlt AS NVARCHAR( 1))
   
    -- Get putaway strategy    
   SET @cPAStrategyKey = ''    
   SELECT @cPAStrategyKey = Short     
   FROM CodeLKUP WITH (NOLOCK)    
   WHERE ListName = 'NKRDTExtPA'    
      AND StorerKey = @cStorerKey    
      AND Long = @cFacility    
      AND Code = @cCode    
      AND code2 = @cPutawayZone 

   -- Check blank putaway strategy    
   IF @cPAStrategyKey = ''    
   BEGIN    
      SET @nErrNo = 172801    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- StrategyNotSet    
      GOTO Quit    
   END    
    
   -- Check putaway strategy valid    
   IF NOT EXISTS( SELECT 1 FROM PutawayStrategy WITH (NOLOCK) WHERE PutawayStrategyKey = @cPAStrategyKey)    
   BEGIN    
      SET @nErrNo = 172802    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- BadStrategyKey    
      GOTO Quit    
   END 
   
   --Suggest LOC    
   EXEC @nErrNo = [dbo].[nspRDTPASTD]    
         @c_userid          = 'RDT'    
      , @c_storerkey       = @cStorerKey    
      , @c_lot             = ''    
      , @c_sku             = ''    
      , @c_id              = @cFromID    
      , @c_fromloc         = @cFromLOC    
      , @n_qty             = 0    
      , @c_uom             = '' -- not used    
      , @c_packkey         = '' -- optional, if pass-in SKU    
      , @n_putawaycapacity = 0    
      , @c_final_toloc     = @cFinalLoc         OUTPUT    
      , @c_PickAndDropLoc  = @cPickAndDropLOC   OUTPUT    
      , @c_FitCasesInAisle = @cFitCasesInAisle  OUTPUT    
      , @c_Param1          = @cParam1  
      , @c_Param2          = @cParam2  
      , @c_Param3          = @cParam3  
      , @c_Param4          = @cParam4  
      , @c_Param5          = @cParam5  
      , @c_PAStrategyKey   = @cPAStrategyKey   
      
   -- Check suggest loc
   IF @cFinalLoc = ''
   BEGIN
      SET @nErrNo = 172803
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC

      SET @nErrNo = -1
      GOTO Quit
   END
       
   SELECT @cLocAisle = LocAisle FROM Loc WITH (NOLOCK) WHERE Loc = @cFinalLoc
      
   SELECT @cToLoc=code
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'PND'  
   AND storerkey = @cStorerkey
   AND code2 = @cLocAisle  
   
   IF @cToLoc = ''
   BEGIN
      SET @nErrNo = 172805
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLoc
      SET @nErrNo = -1
      GOTO Quit
   END
            
   SELECT @cToLogicalLocation = LogicalLocation  
   FROM dbo.LOC WITH (NOLOCK)  
   WHERE LOC = @cFinalLoc  
  
   SELECT @cLogicalLocation = LogicalLocation  
   FROM dbo.LOC WITH (NOLOCK)  
   WHERE LOC = @cToLoc  
        
   -- Suggested location
   IF @cFinalLoc <> '' 
   BEGIN
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_TM_Assist_Putaway -- For rollback or commit only our own transaction

      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
         ,@cFromLOC
         ,@cFromID
         ,@cFinalLoc
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
         ,@cTaskDetailKey = @cTaskDetailKey
      IF @nErrNo <> 0
         GOTO RollBackTran

      -- Lock PND location

      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
         ,@cFromLOC
         ,@cFromID
         ,@cToLoc
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
         ,@cTaskDetailKey = @cTaskDetailKey
      IF @nErrNo <> 0
         GOTO RollBackTran
      
      -- Update TaskDetail
      IF @cFinalLoc <> ''   
      BEGIN
      	UPDATE TaskDetail WITH (ROWLOCK) SET    
             ToLOC      = @cToLoc 
            ,FinalLOC   = @cFinalLoc
            ,LogicalFromLoc = @cLogicalLocation
            ,LogicalToLoc = @cToLogicalLocation
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_SNAME()
            ,TrafficCop = NULL        
         WHERE TaskDetailKey = @cTaskDetailKey    
      

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 172804
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail
            GOTO RollBackTran
         END
         
         SET @cSuggLOC = @cToLoc
         SET @nErrNo = 1 --cos dun wan to perform 'lock' pendingMoveIn in rdt_TM_Assist_Putaway_GetSuggestLOC
      END 
         

      COMMIT TRAN rdtfnc_TM_Assist_Putaway -- Only commit change made here
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtfnc_TM_Assist_Putaway -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO