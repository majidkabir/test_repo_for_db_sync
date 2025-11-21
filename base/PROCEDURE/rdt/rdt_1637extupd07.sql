SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1637ExtUpd07                                    */  
/* Purpose: Update extra info into containerdetail upon close container */  
/*                                                                      */  
/* Called from: rdtfnc_Scan_To_Container                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-03-08 1.0  James      WMS-16476. Created                        */    
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1637ExtUpd07] (  
   @nMobile                   INT,             
   @nFunc                     INT,             
   @cLangCode                 NVARCHAR( 3),    
   @nStep                     INT,             
   @nInputKey                 INT,             
   @cStorerkey                NVARCHAR( 15),   
   @cContainerKey             NVARCHAR( 10),   
   @cMBOLKey                  NVARCHAR( 10),   
   @cSSCCNo                   NVARCHAR( 20),   
   @cPalletKey                NVARCHAR( 18),   
   @cTrackNo                  NVARCHAR( 20),   
   @cOption                   NVARCHAR( 1),   
   @nErrNo                    INT           OUTPUT,    
   @cErrMsg                   NVARCHAR( 20) OUTPUT     
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   
   DECLARE @curUpdMbol     CURSOR
   DECLARE @nTranCount     INT,  
           @cContainerNo   NVARCHAR(20),
           @cData1         NVARCHAR(60),
           @cData2         NVARCHAR(60),
           @cData3         NVARCHAR(60),
           @cData4         NVARCHAR(60),
           @cData5         NVARCHAR(60)

           
   SELECT @cContainerNo = V_String3,
          @cData1 = V_String42,
          @cData2 = V_String43,
          @cData3 = V_String44
   FROM RDT.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 6  
      BEGIN  
         SET @curUpdMbol = CURSOR FOR  
         SELECT DISTINCT MBOL.MbolKey
         FROM dbo.MBOL MBOL WITH (NOLOCK)
         WHERE MBOL.[Status] < '9'
         AND   EXISTS ( SELECT 1 FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)
                        WHERE MBOL.ExternMbolKey = CD.PalletKey
                        AND   CD.ContainerKey = @cContainerKey) 
         ORDER BY 1
         OPEN @curUpdMbol
         FETCH NEXT FROM @curUpdMbol INTO @cMBOLKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.MBOL SET 
               UserDefine05 = @cContainerKey, 
               Vessel = @cContainerNo, 
               Vehicle_Type = @cData1, -- Truck Type
               SealNo = @cData2,       -- Seal #
               Carrieragent = @cData3, -- Hauler
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE MbolKey = @cMBOLKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 164351     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd MBOL Fail  
               GOTO RollBackTran  
            END
            
            FETCH NEXT FROM @curUpdMbol INTO @cMBOLKey
         END
         
         UPDATE dbo.CONTAINERDETAIL SET 
            Userdefine01 = @cContainerNo, 
            Userdefine02 = @cData1,
            Userdefine03 = @cData2,
            Userdefine04 = @cData3, 
            TrafficCop = NULL,
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE ContainerKey = @cContainerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 164352     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ConDtl Fail 
            GOTO RollBackTran  
         END
      END         
   END  
  
   GOTO Quit  
     
   RollBackTran:    
         ROLLBACK TRAN rdt_1637ExtUpd07    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    

GO