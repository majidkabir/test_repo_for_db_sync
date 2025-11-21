SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1653ExtUpd01                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Insert into Transmitlog2 table                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-08-01  1.0  James    WMS-14248. Created                         */  
/* 2021-08-25  1.1  James    WMS-17773 Extend TrackNo to 40 chars       */
/* 2022-05-31  1.2  yeekung  WMS-18350. Add delete pickdetail           */  
/* 2022-09-15  1.3  James    WMS-20667 Add Lane (james01)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653ExtUpd01] (    
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
   SAVE TRAN rdt_1653ExtUpd01 -- For rollback or commit only our own transaction
   
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
               SET @nErrNo = 156452  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del ShtPickEr'  
               GOTO RollBackTran  
            END
            FETCH NEXT FROM CUR_PD INTO @cPickdetailkey 
         END
         CLOSE CUR_PD  
         DEALLOCATE CUR_PD 

         GOTO QUIT
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN

         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2 
            @c_TableName      = 'WSCRSOCLOSEMP', 
            @c_Key1           = @cMBOLKey, 
            @c_Key2           = '', 
            @c_Key3           = @cStorerkey, 
            @c_TransmitBatch  = '', 
            @b_Success        = @bSuccess   OUTPUT,    
            @n_err            = @nErrNo     OUTPUT,    
            @c_errmsg         = @cErrMsg    OUTPUT    

         IF @bSuccess <> 1    
         BEGIN
            SET @nErrNo = 156451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err
            GOTO Quit
         END
      END
      GOTO QUIT
   END
   
RollBackTran:
   Rollback tran
   
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_1653ExtUpd01
END    

GO