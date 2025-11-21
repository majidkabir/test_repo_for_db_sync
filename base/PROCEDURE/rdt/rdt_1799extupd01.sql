SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1799ExtUpd01                                          */
/* Purpose: TM Replen From, Extended Update for                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-08-03   ChewKP    1.0   WMS-5857 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1799ExtUpd01]
   @nMobile      INT,          
   @nFunc        INT,          
   @nStep        INT,          
   @nInputKey    INT,          
   @cLangCode    NVARCHAR( 3), 
   @cStorerkey   NVARCHAR( 15),
   @cToLoc       NVARCHAR( 10),
   @cLPNNo       NVARCHAR( 20),
   @cLPNNo1      NVARCHAR( 20),
   @cLPNNo2      NVARCHAR( 20),
   @cLPNNo3      NVARCHAR( 20),
   @cLPNNo4      NVARCHAR( 20),
   @cLPNNo5      NVARCHAR( 20),
   @cLPNNo6      NVARCHAR( 20),
   @cLPNNo7      NVARCHAR( 20),
   @nCartonCnt   INT,
   @cOption      NVARCHAR( 1), 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess   INT
   DECLARE @nTranCount  INT
   
   DECLARE @cFacility      NVARCHAR( 5)
          ,@cWCS           NVARCHAR(1)
          ,@cWCSSequence   NVARCHAR(2) 
          ,@cWCSOrderKey   NVARCHAR(20) 
          ,@cWCSKey        NVARCHAR(10) 
          ,@c_authority    NVARCHAR(1) 
          ,@cWCSStation    NVARCHAR(10)
          ,@cDeviceType    NVARCHAR(10)
          ,@cDeviceID      NVARCHAR(10)
          ,@nCount         INT
          ,@cPutawayZone   NVARCHAR(10) 
          ,@cWCSMessage    NVARCHAR(255) 
   
   SET @nTranCount = @@TRANCOUNT
  
   BEGIN TRAN
   SAVE TRAN rdt_1799ExtUpd01
         

   SET @nErrNo = 0 
   SET @cErrMsg = ''
   SET @cWCS = '0'
   SET @cDeviceType = 'WCS'
   SET @cDeviceID = 'WCS'
   
   -- TM Replen From
   IF @nFunc = 1799
   BEGIN
      SELECT @cFacility = Facility 
      FROM rdt.rdtmobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile 
      AND Func = @nFunc 
       
       -- GET WCS Config 
      EXECUTE nspGetRight 
               @cFacility,  -- facility
               @cStorerKey,  -- Storerkey
               null,         -- Sku
               'WCS',        -- Configkey
               @bSuccess     output,
               @c_authority  output, 
               @nErrNo       output,
               @cErrMsg      output

      IF @c_authority = '1' AND @bSuccess = 1
      BEGIN
         SET @cWCS = '1' 
      END 
      
      IF @nStep = 2 -- Option
      BEGIN
         -- Call to Sent Web Services
         --SELECT @cToLoc '@cToLoc' , @cTaskdetailKey '@cTaskdetailKey' 
         --IF @cOption = '1' 
         --BEGIN
         IF @cWCS = '1' 
         BEGIN
--            SET @nCount = 1
--            WHILE @nCartonCnt > 0
--            BEGIN
--               SET @cLPNNo = ''
--               SELECT @cLPNNo = CASE @nCount
--                                  WHEN 1 THEN @cLPNNo1 
--                                  WHEN 2 THEN @cLPNNo2 
--                                  WHEN 3 THEN @cLPNNo3 
--                                  WHEN 4 THEN @cLPNNo4 
--                                  WHEN 5 THEN @cLPNNo5 
--                                  WHEN 6 THEN @cLPNNo6 
--                                  WHEN 7 THEN @cLPNNo7 
--                               END

               EXECUTE dbo.nspg_GetKey
                 'WCSKey',
                 10 ,
                 @cWCSKey           OUTPUT,
                 @bSuccess          OUTPUT,
                 @nErrNo            OUTPUT,
                 @cErrMsg           OUTPUT
              
              IF @bSuccess <> 1
              BEGIN
                 SET @nErrNo = 127451
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                 GOTO RollBackTran
              END
           
              SELECT @cPutawayZone = PutawayZone 
              FROM dbo.Loc WITH (NOLOCK) 
              WHERE Facility = @cFacility 
              AND Loc = @cToLoc 
           
              SELECT @cWCSStation = Short                
              FROM dbo.Codelkup WITH (NOLOCK) 
              WHERE ListName = 'WCSSTATION'
              AND StorerKey = @cStorerKey
              AND Code = @cPutawayZone 
           
              --SET @cWCSSequence =  RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)
              SET @cWCSSequence = '01'
              SET @cWCSMessage = CHAR(2)  + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cLPNNo) + '|' + @cWCSKey + '|' + @cWCSStation + '|' + CHAR(3) 
           
              EXEC [RDT].[rdt_GenericSendMsg]
               @nMobile      = @nMobile      
              ,@nFunc        = @nFunc        
              ,@cLangCode    = @cLangCode    
              ,@nStep        = @nStep        
              ,@nInputKey    = @nInputKey    
              ,@cFacility    = @cFacility    
              ,@cStorerKey   = @cStorerKey   
              ,@cType        = @cDeviceType       
              ,@cDeviceID    = @cDeviceID
              ,@cMessage     = @cWCSMessage     
              ,@nErrNo       = @nErrNo       OUTPUT
              ,@cErrMsg      = @cErrMsg      OUTPUT  
            
              IF @nErrNo > 0 
              BEGIN
                   --SET @nErrNo = 127451
                   --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WCSSendingFail 
                   GOTO RollBackTran
              END

               --SET @nCount = @nCount + 1
               --SET @nCartonCnt = @nCartonCnt - 1
            --END
         
           

         END
         --END
      END

   
   END  
   

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1799ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO