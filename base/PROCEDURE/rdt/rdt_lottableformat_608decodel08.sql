SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_LottableFormat_608DecodeL08                           */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Check lottable received                                           */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 13-06-2022  yeekung   1.0   WMS-19962 Created                              */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_608DecodeL08]    
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
   
  
   DECLARE @nExist INT = 0  
   DECLARE @cLottableVal08 NVARCHAR( 60)
   DECLARE @nLenLot08      INT
     
   IF @nFunc = 608  
   BEGIN  

      SELECT @cLottableVal08=O_field02
      from rdt.rdtmobrec (nolock)
      where mobile=@nMobile

      IF @cLottable<>@cLottableVal08
      BEGIN  

         IF  ISNULL(@cLottableVal08,'') =''
         BEGIN
            SET @cLottable=@cLottableValue
         END
         ELSE
         BEGIN
            SET @cLottable= @cLottableVal08 + SUBSTRING (@cLottableValue,1,2)
         END
         SET @nErrNo = -1
         GOTO Quit  
      END  
  
   END  
Quit:  
     
END


GO