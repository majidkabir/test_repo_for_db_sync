SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Store procedure: rdt_1856ExtUpd01                                    */        
/* Copyright      : IDS                                                 */        
/*                                                                      */        
/* Called from: rdtfnc_MbolCreation                                     */        
/*                                                                      */        
/* Purpose: Update MBOL.EXTERNMBOLKEY                                   */        
/*                                                                      */        
/* Modifications log:                                                   */        
/* Date        Rev  Author   Purposes                                   */        
/* 2023-03-27  1.0  James    WMS-22063. Created                         */      
/************************************************************************/        
        
CREATE   PROC [RDT].[rdt_1856ExtUpd01] (        
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cMBOLKey       NVARCHAR( 10),  
   @cOrderKey      NVARCHAR( 10),  
   @cLoadKey       NVARCHAR( 10),  
   @cRefNo1        NVARCHAR( 20),  
   @cRefNo2        NVARCHAR( 20),
   @cRefNo3        NVARCHAR( 20),
   @tExtValidate   VariableTable READONLY,   
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   
   DECLARE @cInField02     NVARCHAR( 60)
   DECLARE @nTranCount     INT
   
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1856ExtUpd01 -- For rollback or commit only our own transaction
                          --    
   IF @nStep = 4    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
      	IF EXISTS ( SELECT 1
      	            FROM dbo.MBOL WITH (NOLOCK)
      	            WHERE MbolKey = @cMBOLKey
      	            AND   ISNULL( ExternMbolKey, '') <> '')
            GOTO Quit

      	SELECT @cInField02 = I_Field02
      	FROM rdt.RDTMOBREC WITH (NOLOCK)
      	WHERE Mobile = @nMobile
      	
      	IF ISNULL( @cInField02, '') <> ''
         BEGIN    
            UPDATE dbo.MBOL SET 
               ExternMbolKey = LEFT( @cInField02, 30),
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE MbolKey = @cMBOLKey
            
            IF @@ERROR <> 0
            BEGIN    
               SET @nErrNo = 198351    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Update MBOL Err    
               GOTO Quit    
            END    
         END 
      END    
   END    
       
   COMMIT TRAN rdt_1856ExtUpd01 -- Only commit change made here
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1856ExtUpd01 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

END        

GO