SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_PMI_VALL03                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 17-08-2020   YeeKung   1.0   WMS-14415 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_PMI_VALL03]
   @nMobile          INT,    
   @nFunc            INT,    
   @cLangCode        NVARCHAR( 3),    
   @nInputKey        INT,    
   @cStorerKey       NVARCHAR( 15),    
   @cSKU             NVARCHAR( 20),    
   @cLottableCode    NVARCHAR( 30),     
   @nLottableNo      INT,    
   @cFormatSP        NVARCHAR( 50),     
   @cLottableValue   NVARCHAR( 60),     
   @cLottable        NVARCHAR( 60) OUTPUT,    
   @nErrNo           INT           OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT    
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF ISNULL(@cLottableValue,'')=''
   BEGIN
      SET @nErrNo = 157051                
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date                        
      GOTO Quit 
   END
   
   IF @cLottableValue NOT IN ('A','D','G')
   BEGIN
      SET @nErrNo = 157052               
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date                        
      GOTO Quit 
   END
END
QUIT:

GO