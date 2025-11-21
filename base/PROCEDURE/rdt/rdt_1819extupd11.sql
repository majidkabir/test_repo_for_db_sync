SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd11                                    */
/* Copyright      : Maersk WMS                                          */
/*                                                                      */
/* Purpose: Unlock locations for all UCC                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-06-11   NLT013    1.0   FCR-267. Created                        */
/************************************************************************/

CREATE PROCEDURE rdt.rdt_1819ExtUpd11
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,           
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @nTranCount     INT
   DECLARE @nPABookingKey  INT

   -- Get Facility, Storer  
   SELECT @cFacility = Facility, 
      @cStorerKey = StorerKey
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile  
  
   SET @nTranCount = @@TRANCOUNT
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1819ExtUpd11 -- For rollback or commit only our own transaction

   -- Change ID  
   IF @nFunc = 1819  
   BEGIN  
      IF @nStep = 2 -- FromID  
      BEGIN  
         IF @nInputKey = 0 -- Esc  
         BEGIN  
            DECLARE CUR_RFPA CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT PABookingKey
            FROM dbo.RFPUTAWAY WITH(NOLOCK)
            WHERE Id = @cFromID
               AND StorerKey = @cStorerKey
               ORDER BY RowRef
         
            OPEN CUR_RFPA  
            FETCH NEXT FROM CUR_RFPA INTO @nPABookingKey

            WHILE @@FETCH_STATUS = 0
            BEGIN 
               EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                  ,'' --FromLOC
                  ,'' --FromID
                  ,'' --cSuggLOC
                  ,'' --Storer
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
                  ,@nPABookingKey = @nPABookingKey

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 216751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UnlockLocFail
                  GOTO RollBackTran
               END
               
               SET @nPABookingKey = ''

            FETCH NEXT FROM CUR_RFPA INTO @nPABookingKey
            END  

            CLOSE CUR_RFPA  
            DEALLOCATE CUR_RFPA
         END  
      END  
   END  

   COMMIT TRAN rdt_1819ExtUpd11

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd11 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO