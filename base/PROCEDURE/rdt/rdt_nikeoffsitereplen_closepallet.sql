SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_NIKEOffSiteReplen_ClosePallet                         */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-04-26 1.0  Ung      WMS-22246 Created                                 */ 
/******************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_NIKEOffSiteReplen_ClosePallet] (
   @nMobile    INT, 
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @nStep      INT, 
   @nInputKey  INT, 
   @cFacility  NVARCHAR( 5),
   @cStorerKey NVARCHAR( 15),
   @cWaveKey   NVARCHAR( 10), 
   @cPickZone  NVARCHAR( 10), 
   @cToArea    NVARCHAR( 10), 
   @cDropID    NVARCHAR( 20), 
   @cUCCNo     NVARCHAR( 20), 
   @nErrNo     INT           OUTPUT, 
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTranCount     INT
   DECLARE @cUserName      NVARCHAR( 18) = SUSER_SNAME()
   DECLARE @cTaskDetailKey NVARCHAR(10)
   DECLARE @cListKey       NVARCHAR(10)

   -- Get task info
   SELECT TOP 1 
      @cTaskDetailKey = TaskDetailKey, 
      @cListKey = ListKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND TaskType = 'RPF'
      AND DropID = @cDropID
      AND Status = '5'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_NIKEOffSiteReplen

   -- Close pallet (TaskDetail to status 9, move inventory)
   EXEC rdt.rdt_656ClosePallet01 @nMobile, @nFunc, @cLangCode,
      @cUserName,
      @cListKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
   BEGIN
      ROLLBACK TRAN rdt_NIKEOffSiteReplen
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      GOTO Quit
   END

   EXEC rdt.rdt_1764ExtUpd17 @nMobile, 
      1764, -- @nFunc, 
      @cLangCode,
      6, -- @nStep, ToLOC
      @cTaskDetailKey,
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT, 
      @cDropID = @cDropID
   IF @nErrNo <> 0
   BEGIN
      ROLLBACK TRAN rdt_NIKEOffSiteReplen
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      GOTO Quit
   END

   COMMIT TRAN rdt_NIKEOffSiteReplen
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_NIKEOffSiteReplen -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END


GO