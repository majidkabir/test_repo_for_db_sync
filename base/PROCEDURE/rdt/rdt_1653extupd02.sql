SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************************/    
/* Store procedure: rdt_1653ExtUpd02                                                */    
/* Copyright      : IDS                                                             */    
/*                                                                                  */    
/* Called from: rdtfnc_TrackNo_SortToPallet                                         */    
/*                                                                                  */    
/* Purpose: Insert into Transmitlog2 table                                          */    
/*                                                                                  */    
/* Modifications log:                                                               */    
/* Date        Rev  Author   Purposes                                               */    
/* 2021-08-05  1.0  James    WMS-17486. Created                                     */  
/* 2021-08-25  1.1  James    WMS-17773 Extend TrackNo to 40 chars                   */
/* 2021-11-15  1.2  James    WMS-18115 Delete rdtecomlog when                       */
/*                           close plt (james01)                                    */
/* 2022-09-15  1.3  James    WMS-20667 Add Lane (james01)                           */
/* 2022-10-26  1.4  James    WMS-19711 Delete short pick line (james02)             */
/* 2023-05-22  1.5  Ung      WMS-22554 Migrate to isp_Carrier_Middleware_Interface  */
/************************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1653ExtUpd02] (    
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
   
   DECLARE @bSuccess       INT
   DECLARE @nRowRef        INT
   DECLARE @cPickdetailkey NVARCHAR( 10)
   DECLARE @curDelPD       CURSOR
   DECLARE @nTranCount     INT
     
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_1653ExtUpd02  
   
   IF @nStep = 2  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SET @curDelPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
         SELECT PickDetailKey    
         FROM dbo.PickDetail WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
         AND   [Status] = '4'  
         OPEN @curDelPD    
         FETCH NEXT FROM @curDelPD INTO @cPickdetailkey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN   
            DELETE PickDetail 
            WHERE PickDetailKey = @cPickdetailkey  
  
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 173053    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Del ShtPickError'    
               GOTO RollBackTran    
            END  

            FETCH NEXT FROM @curDelPD INTO @cPickdetailkey   
         END  
      END  
   END  

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         /*
         -- Insert transmitlog2 here
         EXECUTE ispGenTransmitLog2 
            @c_TableName      = 'WSCRSOCLOSEILS', 
            @c_Key1           = @cMBOLKey, 
            @c_Key2           = '', 
            @c_Key3           = @cStorerkey, 
            @c_TransmitBatch  = '', 
            @b_Success        = @bSuccess   OUTPUT,    
            @n_err            = @nErrNo     OUTPUT,    
            @c_errmsg         = @cErrMsg    OUTPUT    

         IF @bSuccess <> 1    
         BEGIN
            SET @nErrNo = 173051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err
            GOTO RollBackTran
         END*/
         
         EXEC isp_Carrier_Middleware_Interface
             '' -- @cOrderKey
            ,@cMBOLKey
            ,@nFunc
            ,'' -- @nCartonNo
            ,@nStep
            ,@bSuccess  OUTPUT
            ,@nErrNo    OUTPUT
            ,@cErrMsg   OUTPUT
         IF @bSuccess = 0
         BEGIN
            SET @nErrNo = 173053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShipLabel fail
            GOTO RollBackTran
         END

         DECLARE @curDelEcomLog  CURSOR
         SET @curDelEcomLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef FROM rdt.rdtECOMMLog EL WITH (NOLOCK)
         WHERE EXISTS ( SELECT 1 FROM MBOLDETAIL MD WITH (NOLOCK) 
                        WHERE EL.Orderkey = MD.OrderKey 
                        AND   MD.MbolKey = @cMBOLKey)
         OPEN @curDelEcomLog
         FETCH NEXT FROM @curDelEcomLog INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtECOMMLOG WHERE RowRef = @nRowRef
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 173052  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcommFail'  
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM @curDelEcomLog INTO @nRowRef
         END

          
      END
   END
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_1653ExtUpd02  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
    
END    

GO