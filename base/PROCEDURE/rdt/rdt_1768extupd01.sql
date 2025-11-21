SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1768ExtUpd01                                    */
/* Purpose: Update all ccdetail finalizeflag = Y when finish loc        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-08-01 1.0  James      WMS-23133. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1768ExtUpd01] (
   @nMobile         INT,   
   @nFunc           INT,   
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cTaskDetailKey  NVARCHAR( 10), 
   @cCCKey          NVARCHAR( 10), 
   @cCCDetailKey    NVARCHAR( 10), 
   @cLoc            NVARCHAR( 10), 
   @cID             NVARCHAR( 18), 
   @cSKU            NVARCHAR( 20), 
   @nActQTY          INT, 
   @cOptions        NVARCHAR( 1), 
   @cLottable01     NVARCHAR( 18), 
   @cLottable02     NVARCHAR( 18), 
   @cLottable03     NVARCHAR( 18), 
   @dLottable04     DATETIME, 
   @dLottable05     DATETIME, 
   @cLottable06     NVARCHAR( 30), 
   @cLottable07     NVARCHAR( 30), 
   @cLottable08     NVARCHAR( 30), 
   @cLottable09     NVARCHAR( 30), 
   @cLottable10     NVARCHAR( 30), 
   @cLottable11     NVARCHAR( 30), 
   @cLottable12     NVARCHAR( 30), 
   @dLottable13     DATETIME, 
   @dLottable14     DATETIME, 
   @dLottable15     DATETIME, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @curUpdCCD      CURSOR
   DECLARE @cUserName      NVARCHAR( 18)
   
   SELECT @cUserName = UserName 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1768ExtUpd01 -- For rollback or commit only our own transaction

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	IF @cOptions <> '2'
      	   GOTO RollBackTran
      	   
      	SET @curUpdCCD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	SELECT CCDetailKey
      	FROM dbo.CCDetail WITH (NOLOCK)
      	WHERE CCSheetNo = @cTaskDetailKey
      	AND   FinalizeFlag <> 'Y'  -- TMCC only 1 count 
      	ORDER BY 1
      	OPEN @curUpdCCD
      	FETCH NEXT FROM @curUpdCCD INTO @cCCDetailKey
      	WHILE @@FETCH_STATUS = 0
      	BEGIN
      		UPDATE dbo.CCDetail SET 
      		   FinalizeFlag = 'Y',
      		   EditWho = @cUserName,
      		   EditDate = GETDATE()
      		WHERE CCDetailKey = @cCCDetailKey
      		
      		IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Finalize Err'
               GOTO RollBackTran
            END
      		   
      		FETCH NEXT FROM @curUpdCCD INTO @cCCDetailKey
      	END
      END
   END

   GOTO CommitTrans

   RollBackTran:
         ROLLBACK TRAN rdt_1768ExtUpd01

   CommitTrans:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO