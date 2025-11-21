SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1766ExtUpd01                                    */
/* Purpose: Reverse the locked task status for CC task                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-11-02 1.0  James      WMS4083. Created                          */
/* 2019-04-29 1.1  James      WMS8136. Insert CCDetail record for empty */
/*                            loc (james01)                             */
/************************************************************************/

CREATE PROC [RDT].[rdt_1766ExtUpd01] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility       NVARCHAR( 15), 
   @cStorerKey      NVARCHAR( 15), 
   @cTaskdetailkey  NVARCHAR( 20), 
   @cFromLoc        NVARCHAR( 20), 
   @cID             NVARCHAR( 20), 
   @cPickMethod     NVARCHAR( 20), 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @nTranCount      INT,
           @cLocAisle       NVARCHAR( 10),
           @cTDKey2Unlock   NVARCHAR( 10),
           @cUserName       NVARCHAR( 18),
           @cCCKey          NVARCHAR( 10),
           @cCCSheetNo      NVARCHAR( 10),
           @cCCDetailKey    NVARCHAR( 10),
           @cExcludeQtyPicked NVARCHAR( 1),
           @bSuccess        INT,
           @nSystemQty      INT

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1766ExtUpd01 -- For rollback or commit only our own transaction  

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cCCKey   = SourceKey           
         FROM dbo.TaskDetail WITH (NOLOCK)                
         WHERE TaskDetailKey = @cTaskdetailkey  

         SET @cCCSheetNo = @cTaskdetailkey  
   
         EXECUTE nspg_getkey  
            @KeyName       = 'CCDetailKey'  
           ,@fieldlength   = 10  
           ,@keystring     = @cCCDetailKey  OUTPUT  
           ,@b_Success     = @bSuccess      OUTPUT  
           ,@n_err         = @nErrNo        OUTPUT  
           ,@c_errmsg      = @cErrMsg       OUTPUT  

         SELECT @cExcludeQtyPicked = ExcludeQtyPicked      
         FROM StockTakeSheetParameters (NOLOCK)  
         WHERE StockTakeKey = @cCCKey

         SELECT @nSystemQty = CASE WHEN @cExcludeQtyPicked = 'Y' 
                                   THEN ISNULL( SUM(LOTxLOCxID.qty-LOTxLOCxID.qtypicked), 0) 
                                   ELSE ISNULL( SUM(LOTxLOCxID.qty), 0) 
                              END 
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOC = @cFromLoc
         AND   ( ( ISNULL( @cID, '') = '') OR ( ID = @cID))

         INSERT INTO dbo.CCDetail 
         (CCKey, CCDetailKey, StorerKey, SKU, LOT, LOC, ID, Qty, CCSheetNo, Lottable01,  
          Lottable02, Lottable03, Lottable04, Lottable05, SystemQty, Status)  
         VALUES 
         (@cCCKey, @cCCDetailKey, @cStorerKey, '', '', @cFromLoc, @cID, 0, @cCCSheetNo,  
          '', '', '', NULL, NULL, @nSystemQty, '2') 

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 122903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins CCDetail Err'  
            GOTO RollBackTran
         END
      END
   END

   IF @nStep = 6
   BEGIN
      IF @nInputKey = 0
      BEGIN
         SELECT TOP 1 @cLocAisle = LocAisle
         FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( LOC.LOC = TD.FROMLOC)
         WHERE TD.TaskType = 'CC'
         AND   TD.UserKey = @cUserName
         AND   TD.Status = '3'
         AND   LOC.Facility = @cFacility
         ORDER BY 1

         DECLARE CUR_RELEASETASK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT TASKDETAILKEY
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.FromLOC = LOC.LOC
         WHERE TD.TaskType = 'CC'
         AND   TD.Status = '3'
         AND   LOC.LOCAisle = @cLocAisle
         AND   LOC.Facility = @cFacility
         OPEN CUR_RELEASETASK
         FETCH NEXT FROM CUR_RELEASETASK INTO @cTDKey2Unlock
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
               [Status] = '0',
               UserKey = '',
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = @cUserName
            WHERE TASKDETAILKEY = @cTDKey2Unlock

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 122902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'  
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_RELEASETASK INTO @cTDKey2Unlock
         END
         CLOSE CUR_RELEASETASK
         DEALLOCATE CUR_RELEASETASK
      END
   END

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cLocAisle = LocAisle
         FROM dbo.LOC LOC WITH (NOLOCK)
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( LOC.LOC = TD.FROMLOC)
         WHERE TD.TaskDetailKey = @cTaskdetailkey
         AND   LOC.Facility = @cFacility
         ORDER BY 1

         DECLARE CUR_RELEASETASK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT TASKDETAILKEY
         FROM dbo.TaskDetail TD WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.FromLOC = LOC.LOC
         WHERE TD.TaskType = 'CC'
         AND   TD.Status = '3'
         AND   LOC.LOCAisle = @cLocAisle
         AND   LOC.Facility = @cFacility
         OPEN CUR_RELEASETASK
         FETCH NEXT FROM CUR_RELEASETASK INTO @cTDKey2Unlock
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
               [Status] = '0',
               UserKey = '',
               TrafficCop = NULL,
               EditDate = GETDATE(),
               EditWho = @cUserName
            WHERE TASKDETAILKEY = @cTDKey2Unlock

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 122901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Setup CODEKLP'  
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_RELEASETASK INTO @cTDKey2Unlock
         END
         CLOSE CUR_RELEASETASK
         DEALLOCATE CUR_RELEASETASK
      END
   END

   GOTO CommitTrans
   
   RollBackTran:  
         ROLLBACK TRAN rdt_1766ExtUpd01  

   CommitTrans:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  


GO