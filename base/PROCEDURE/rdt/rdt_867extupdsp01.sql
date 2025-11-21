SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_867ExtUpdSP01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Pick By TrackNo Extended Update                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-09-03  1.0  ChewKP   SOS#351702 Created                         */   
/* 2015-12-08  2.5  ChewKP   SOS#358644 Revise Pickdetail Update Logic  */
/*                           (ChewKP01)                                 */ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_867ExtUpdSP01] (    
  @nMobile        INT,   
  @nFunc          INT,   
  @nStep          INT,    
  @cLangCode      NVARCHAR( 3),   
  @cUserName      NVARCHAR( 18),  
  @cFacility      NVARCHAR( 5),   
  @cStorerKey     NVARCHAR( 15),  
  @cOrderKey      NVARCHAR( 10),  
  @cSKU           NVARCHAR( 20),  
  @cTracKNo       NVARCHAR( 18),  
  @cSerialNo      NVARCHAR( 30),  
  @nErrNo         INT           OUTPUT,  
  @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
  
   DECLARE @nTranCount        INT  
          ,@cOrderLineNumber  NVARCHAR(5)
          ,@nQty              INT
          ,@cSerialNoKey      NVARCHAR(10)
          ,@bsuccess          INT
     
   SET @nErrNo    = 0    
   SET @cErrMsg   = ''   
   
   
       
     
   SET @nTranCount = @@TRANCOUNT  
     
   BEGIN TRAN  
   SAVE TRAN rdt_867ExtUpdSP01  
   
   IF @nFunc = 867 
   BEGIN


      IF @nStep = 3
      BEGIN
                  
         IF NOT EXISTS ( SELECT 1 FROM SerialNo WITH (NOLOCK)
                         WHERE StorerKEy = @cStorerKey
                         AND OrderKey = @cOrderKey
                         AND SKU = @cSKU
                         AND SerialNo = @cSerialNo )
         BEGIN
            
            EXECUTE dbo.nspg_GetKey
                               'SerialNo',
                               10 ,
                               @cSerialNoKey      OUTPUT,
                               @bsuccess          OUTPUT,
                               @nErrNo            OUTPUT,
                               @cErrMsg           OUTPUT
               
            IF @bsuccess <> 1
            BEGIN
                SET @nErrNo = 94151
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetKeyFail'
                GOTO RollBackTran
            END
            
            

            
            
            SELECT @cOrderLineNumber = PD.OrderLineNumber 
                  ,@nQty             = PD.Qty
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.StorerKey = @cStorerKey
            AND PD.OrderKey = @cOrderKey
            AND PD.SKU = @cSKU 
            AND PD.OrderLineNumber Not IN ( SELECT S.OrderLineNumber FROM 
                                            dbo.SerialNo S WITH (NOLOCK) 
                                            WHERE S.OrderKey = @cOrderKey
                                            AND S.OrderLineNumber = PD.OrderLineNUmber
                                            AND S.SKU = @cSKU  ) 
                                            
            
            
            INSERT INTO SerialNo (SerialNoKey, OrderKey, OrderLineNumber, StorerKey, SKU, SerialNo, Qty) 
            VALUES ( @cSerialNoKey, @cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU , @cSerialNo , 1 ) 

            
            IF @@ERROR <> 0 
            BEGIN 
                  SET @nErrNo = 94152
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsSerialNoFail
                  GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
                  SET @nErrNo = 94153
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SerialNoExist
                  GOTO RollBackTran
         END
  
      END
      
      -- (ChewKP01) 
      IF @nStep = 5
      BEGIN
         
         DELETE FROM dbo.SerialNo WITH (ROWLOCK)
         WHERE OrderKey = @cOrderKey
         AND StorerKey = @cStorerKey
         
         IF @@ERROR <> 0 
         BEGIN
                SET @nErrNo = 94154
                SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetKeyFail'
                GOTO RollBackTran
         END
         
      END
  
   END
   

   
   
  
   GOTO QUIT   
     
RollBackTran:  
   ROLLBACK TRAN rdt_867ExtUpdSP01 -- Only rollback change made here  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_867ExtUpdSP01  
   
  
END    

GO