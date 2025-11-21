SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1776ExtUpd01                                    */
/* Purpose: To insert closed tote no into serial no table               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-07-31 1.0  James      SOS348965. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1776ExtUpd01] (
   @nMobile                INT, 
   @nFunc                  INT, 
   @cLangCode              NVARCHAR( 3), 
   @cUserName              NVARCHAR( 18), 
   @cFacility              NVARCHAR( 5), 
   @cStorerKey             NVARCHAR( 15), 
   @nStep                  INT, 
   @cDropID                NVARCHAR( 20), 
   @cOption                NVARCHAR(  1), 
   @cNewToteNo             NVARCHAR( 20), 
   @cNewToteScn            NVARCHAR(  1) OUTPUT, 
   @cDeviceProfileLogKey   NVARCHAR( 10) OUTPUT, 
   @nErrNo                 INT           OUTPUT, 
   @cErrMsg                NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nTranCount        INT, 
           @cOrderKey         NVARCHAR( 10), 
           @cOrderLineNumber  NVARCHAR( 5), 
           @cProductInfo      NVARCHAR( 18), 
           @cPattern          NVARCHAR( 50)  
           

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1776ExtUpd01

   IF NOT EXISTS ( SELECT 1 FROM dbo.SerialNo WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   SerialNo = @cDropID) AND ISNULL( @cDropID, '') <> ''
   BEGIN
      INSERT INTO dbo.SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty) VALUES
      (@cDropID, '', '', @cStorerKey, '', @cDropID, 0)

      IF @@ERROR <> 0
         GOTO RollBackTran
   END
               
   GOTO Quit
   

   RollBackTran:
   ROLLBACK TRAN rdt_1776ExtUpd01
   
QUIT:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1776ExtUpd01

GO