SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653ExtUpd04                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Insert into Transmitlog2 table                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2021-11-19  1.0  James    WMS-18350. Created                         */  
/* 2022-09-15  1.1  James    WMS-20667 Add Lane (james01)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtUpd04] (    
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
   DECLARE @nRowRef     INT
   DECLARE @nTranCount  INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1653ExtUpd04 -- For rollback or commit only our own transaction

   
   IF @nStep IN( 2,3)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         DECLARE @cPickdetailkey NVARCHAR(20)

         DECLARE CUR_PD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT pickdetailkey  
         FROM dbo.PickDetail WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
         AND   [Status] = '4'


         OPEN CUR_PD  
         FETCH NEXT FROM CUR_PD INTO @cPickdetailkey  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 
            
            DELETE PickDetail where pickdetailkey=@cPickdetailkey

              
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 183701  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --' Del ShtPickEr'  
               GOTO RollBackTran  
            END
            FETCH NEXT FROM CUR_PD INTO @cPickdetailkey 
         END
         CLOSE CUR_PD  
         DEALLOCATE CUR_PD 

      END
      GOTO QUIT
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2 
            @c_TableName      = 'WSLBLREQLOGMF', 
            @c_Key1           = @cMBOLKey, 
            @c_Key2           = '', 
            @c_Key3           = @cStorerkey, 
            @c_TransmitBatch  = '', 
            @b_Success        = @bSuccess   OUTPUT,    
            @n_err            = @nErrNo     OUTPUT,    
            @c_errmsg         = @cErrMsg    OUTPUT    

         IF @bSuccess <> 1    
            GOTO RollBackTran
      END
      GOTO QUIT
   END


RollBackTran:
   Rollback tran
   
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1653ExtUpd04
END    

GO