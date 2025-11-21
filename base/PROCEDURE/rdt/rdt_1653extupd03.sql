SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1653ExtUpd03                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: update mbol.status                                          */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-03-09  1.0  yeekung  WMS-19130. Created                         */  
/* 2022-09-15  1.1  James    WMS-20667 Add Lane (james01)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtUpd03] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20),
   @cMBOLKey       NVARCHAR( 10),
   @cLane          NVARCHAR( 20),
   @tExtValidVar   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1653ExtUpd03 -- For rollback or commit only our own transaction

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         UPDATE mbol WITH (ROWLOCK)
         SET status='7'
         WHERE mbolkey=@cmbolkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 184101 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close MBOL Err
            GOTO Rollbacktran
         END
      END
   END
 
   COMMIT TRAN rdt_1653ExtUpd03

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_1653ExtUpd03 -- Only rollback change made here
Quit_UpdateMbol:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
Quit:    
END    

GO