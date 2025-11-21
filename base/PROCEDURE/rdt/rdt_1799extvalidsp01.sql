SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1799ExtValidSP01                                */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-08-03 1.0  ChewKP     WMS-5857 Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1799ExtValidSP01] (  
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
)  
AS  

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 839  
BEGIN  
    DECLARE @c_authority    NVARCHAR(1) 
           ,@cWCS           NVARCHAR(1) 
           ,@cFacility      NVARCHAR(5) 
           ,@bSuccess       INT
           ,@cPutawayZone   NVARCHAR(10) 
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cWCS            = ''
    
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
    

    IF @nStep = 1 
    BEGIN
       IF @nInputKey = 1 -- ENTER
       BEGIN
          IF ISNULL(@cWCS,'')  = '' 
          BEGIN
            SET @nErrNo = 127403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WCSNotTurnOn
            GOTO QUIT
          END
          
          IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                         WHERE Loc = @cToLoc
                         AND Facility = @cFacility)
          BEGIN
            SET @nErrNo = 127401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToLoc
            GOTO QUIT
          END

          SELECT @cPutawayZone = PutawayZone
          FROM dbo.Loc WITH (NOLOCK) 
          WHERE Loc = @cToLoc
          AND Facility = @cFacility
          
                         
          IF ISNULL(@cPutawayZone , '' ) = ''
          BEGIN
            SET @nErrNo = 127402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PAZoneNotSetup
            GOTO QUIT
          END
          
          IF NOT EXISTS ( SELECT 1 FROM dbo.CodeLKup WITH (NOLOCK) 
                          WHERE ListName = 'WCSSTATION'
                          AND StorerKey = @cStorerKey
                          AND Code = @cPutawayZone)
          BEGIN                
            SET @nErrNo = 127404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPAZone
            GOTO QUIT
          END
          
          
       END
    END
   
END  
  
QUIT:  

 

GO