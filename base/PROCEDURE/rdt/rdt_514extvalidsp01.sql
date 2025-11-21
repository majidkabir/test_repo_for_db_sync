SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_514ExtValidSP01                                 */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-01-07 1.0  ChewKP     SOS#330113 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_514ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cToID       NVARCHAR(18),   
   @cToLoc      NVARCHAR(10),   
   @cFromLoc    NVARCHAR(10),
   @cUCC        NVARCHAR(20), 
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 514  
BEGIN  
   
    
    DECLARE    @cID            NVARCHAR(18)
            ,  @cLoseID        NVARCHAR(1)
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cID             = ''
    SET @cLoseID         = ''
    
    
    SELECT @cID = ID 
    FROM dbo.UCC WITH (NOLOCK)
    WHERE StorerKey = @cStorerKey
    AND UCCNo = @cUCC
    
    SELECT @cLoseID = LoseID 
    FROM dbo.Loc WITH (NOLOCK)
    WHERE Loc = @cToLoc
    

    
    IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)
                WHERE ListName = 'HOLDID'
                AND StorerKey = @cStorerKey
                AND Code = ISNULL(RTRIM(@cID),'' ) ) 
    BEGIN   
          IF @cToID <> @cID 
          BEGIN
             SET @nErrNo = 92551
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCConHOLD'
             GOTO QUIT             
          END
          
          IF @cLoseID = '1'
          BEGIN
             SET @nErrNo = 92552
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCConHOLD'
             GOTO QUIT   
          END
    END
    
--    IF @cToID <> @cID 
--    BEGIN
--       SET @nErrNo = 92553
--       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCConHOLD'
--       GOTO QUIT             
--    END
--    
--    IF @cLoseID = '1'
--    BEGIN
--       SET @nErrNo = 92554
--       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCConHOLD'
--       GOTO QUIT   
--    END

    IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)
                WHERE ListName = 'HOLDID'
                AND StorerKey = @cStorerKey
                AND Code = ISNULL(RTRIM(@cToID),'' ) ) 
    BEGIN 
       
       IF @cToID <> @cID 
       BEGIN
          SET @nErrNo = 92553
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCConHOLD'
          GOTO QUIT             
       END
    
    END
END  
  
QUIT:  

 

GO