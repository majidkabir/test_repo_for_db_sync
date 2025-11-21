SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513ExtUpdSP01                                   */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-08-26   Ung       1.0   SOS#342416 Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtUpdSP01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelNo NVARCHAR(20) 
          ,@cLocationType NVARCHAR(10) 

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            
            SELECT @cLocationType = LocationType
            FROM dbo.Loc WITH (NOLOCK)
            WHERE Loc = @cToLOC
            
            IF @cLocationType = 'DYNPPICK'
            BEGIN
               SELECT @cLabelNo = V_String23
               FROM rdt.rdtMobrec WITH (NOLOCK)
               WHERE Mobile = @nMobile
               
               UPDATE dbo.UCC WITH (ROWLOCK)
               SET Status = '6'
               WHERE UCCNo = @cLabelNo
               AND StorerKey = @cStorerKey
               
               IF @@ERROR <> 0 
               BEGIN
                  SET @nErrNo = 93951    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdUCCFail    
                  GOTO Quit     
               END
            END
            
         END
      END
   END
END

Quit:

GO