SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_973ExtUpd01                                     */
/* Purpose: To insert closed tote no into serial no table               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-08-05 1.0  James      SOS348965. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_973ExtUpd01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nAfterStep      INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFromTote       NVARCHAR( 20), 
   @cToTote         NVARCHAR( 20), 
   @cSKU            NVARCHAR( 20), 
   @nQtyMV          INT, 
   @cConsoOption    NVARCHAR( 1), 
   @nErrNo          INT            OUTPUT, 
   @cErrMsg         NVARCHAR( 20)  OUTPUT  
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount        INT

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_973ExtUpd01

   IF LEN( RTRIM( @cToTote)) <> 10 AND LEN( RTRIM( @cFromTote)) <> 8
      GOTO Quit

   IF NOT EXISTS ( SELECT 1 FROM dbo.SerialNo WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   SerialNo = @cToTote) AND ISNULL( @cToTote, '') <> ''
   BEGIN
      INSERT INTO dbo.SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty) VALUES
      (@cToTote, '', '', @cStorerKey, '', @cToTote, 0)

      IF @@ERROR <> 0
         GOTO RollBackTran
   END
               
   GOTO Quit

   RollBackTran:
   ROLLBACK TRAN rdt_973ExtUpd01
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_973ExtUpd01

GO