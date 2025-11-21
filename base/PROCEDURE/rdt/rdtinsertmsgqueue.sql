SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdtInsertMsgQueue                                   */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: XDock Sortation (SOS85928)                                  */  
/*                                                                      */  
/* Called from: 3                                                       */  
/*    1. From PowerBuilder                                              */  
/*    2. From scheduler                                                 */  
/*    3. From others stored procedures or triggers                      */  
/*    4. From interface program. DX, DTS                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2020-Jun-24 1.1  YeeKung  Add Input Username and pasword (yeekung01) */
/* 2022-Oct-03 1.2  YeeKung  Fix length params (yeekung02)              */
/************************************************************************/  
  
CREATE     PROC rdt.rdtInsertMsgQueue (  
   @nMobile    INT,  
   @nErrNo     INT            OUTPUT,  
   @cErrMsg    NVARCHAR( 1024) OUTPUT, -- screen limitation, 20 char max  
   @cLine01    NVARCHAR(125) = '',  
   @cLine02    NVARCHAR(125) = '',  
   @cLine03    NVARCHAR(125) = '',  
   @cLine04    NVARCHAR(125) = '',  
   @cLine05    NVARCHAR(125) = '',  
   @cLine06    NVARCHAR(125) = '',  
   @cLine07    NVARCHAR(125) = '',  
   @cLine08    NVARCHAR(125) = '',  
   @cLine09    NVARCHAR(125) = '',  
   @cLine10    NVARCHAR(125) = '',  
   @cLine11    NVARCHAR(125) = '',  
   @cLine12    NVARCHAR(125) = '',  
   @cLine13    NVARCHAR(125) = '',  
   @cLine14    NVARCHAR(125) = '',  
   @cLine15    NVARCHAR(125) = ''  ,
   @nDisplayMsg      INT = 1
)  
AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @cPosition NVARCHAR(20)='',
        @nFunc     NVARCHAR(20),
        @cStorerKey NVARCHAR(20),
        @cConfigkey NVARCHAR(30)='SecurityProtectedError'

SELECT @nFunc=FUNC,@cStorerKey=storerkey
FROM RDT.RDTMOBREC (NOLOCK)
WHERE mobile=@nMobile

SET @cConfigkey=@cConfigkey+'-'+ CAST(@nErrNo AS NVARCHAR(6)) --(yeekung02)

SET @cPosition = rdt.rdtGetConfig( @nFunc, @cConfigkey, @cStorerKey) 
  
IF ISNULL(@cPosition,'')<>'' AND @cPosition <>'0'
   SET @cLine14=@cPosition
  
INSERT INTO RDT.rdtMsgQueue  
           (Mobile  
           ,Line01           ,Line02           ,Line03  
           ,Line04           ,Line05           ,Line06  
           ,Line07           ,Line08           ,Line09  
           ,Line10           ,Line11           ,Line12  
           ,Line13           ,Line14           ,Line15
           ,DisplayMsg)  
     VALUES  
           (@nMobile,   
            @cLine01,         @cLine02,         @cLine03,               
            @cLine04,         @cLine05,         @cLine06,               
            @cLine07,         @cLine08,         @cLine09,               
            @cLine10,         @cLine11,         @cLine12,               
            @cLine13,         @cLine14,         @cLine15,
            @nDisplayMsg)   
  
SET @nErrNo = @@ERROR   
IF @nErrNo <> 0   
BEGIN  
   SET @cErrMsg = RTRIM(CAST(@nErrNo as NVARCHAR(8))) + ' - Insert rdtMsgQueue Failed!'   
END   
ELSE  
BEGIN  
   SET @nErrNo = 1   
END   

GO