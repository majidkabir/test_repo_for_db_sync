SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_LottableFormat_1841CheckNonBlank                      */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Check lottable received                                           */  
/*                                                                            */  
/* Date        Author    Ver.  Purposes                                       */  
/* 14-12-2020  James     1.0   WMS-11430 Created                              */  
/* 15-04-2021  Chermaine 1.1   WMS-16643 Add validation (cc01)                */
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_1841CheckNonBlank]    
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
   
   --INSERT INTO traceInfo (TraceName,timein,col1,col2)
   --   VALUES ('ccnikeph1841A',GETDATE(),@cLottableValue ,@cLottable)
  
   DECLARE @nExist INT = 0  
   DECLARE 
   	@cLottableVal01 NVARCHAR( 60),@cLottableVal06 NVARCHAR( 60),@cLottableVal11 NVARCHAR( 60),
   	@cLottableVal02 NVARCHAR( 60),@cLottableVal07 NVARCHAR( 60),@cLottableVal12 NVARCHAR( 60),
   	@cLottableVal03 NVARCHAR( 60),@cLottableVal08 NVARCHAR( 60),@dLottableVal13 DATETIME,
   	@dLottableVal04 DATETIME     ,@cLottableVal09 NVARCHAR( 60),@dLottableVal14 DATETIME,
   	@dLottableVal05 DATETIME     ,@cLottableVal10 NVARCHAR( 60),@dLottableVal15 DATETIME
     
   IF @nFunc = 1841  
   BEGIN       
      -- Get lottable  
      IF @nLottableNo =  1 SELECT @cLottable = @cLottableValue, @cLottableVal01 = @cLottableValue ELSE   
      IF @nLottableNo =  2 SELECT @cLottable = @cLottableValue, @cLottableVal02 = @cLottableValue ELSE   
      IF @nLottableNo =  3 SELECT @cLottable = @cLottableValue, @cLottableVal03 = @cLottableValue ELSE
      IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal04 = rdt.rdtFormatDate( @cLottableValue) ELSE   
      IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal05 = rdt.rdtFormatDate( @cLottableValue) ELSE    
      IF @nLottableNo =  6 SELECT @cLottable = @cLottableValue, @cLottableVal06 = @cLottableValue ELSE
      IF @nLottableNo =  7 SELECT @cLottable = @cLottableValue, @cLottableVal07 = @cLottableValue ELSE
      IF @nLottableNo =  8 SELECT @cLottable = @cLottableValue, @cLottableVal08 = @cLottableValue ELSE
      IF @nLottableNo =  9 SELECT @cLottable = @cLottableValue, @cLottableVal09 = @cLottableValue ELSE
      IF @nLottableNo = 10 SELECT @cLottable = @cLottableValue, @cLottableVal10 = @cLottableValue ELSE
      IF @nLottableNo = 11 SELECT @cLottable = @cLottableValue, @cLottableVal11 = @cLottableValue ELSE  
      IF @nLottableNo = 12 SELECT @cLottable = @cLottableValue, @cLottableVal12 = @cLottableValue ELSE 
      IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal13 = rdt.rdtFormatDate( @cLottableValue) ELSE  
      IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal14 = rdt.rdtFormatDate( @cLottableValue) ELSE   
      IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @cLottableValue),@dLottableVal15 = rdt.rdtFormatDate( @cLottableValue)     
      
          
      DECLARE @cReceiptKey NVARCHAR(10)
      SELECT @cReceiptKey = V_ReceiptKey FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
      
      -- Check blank  
      IF @cLottable = ''  
      BEGIN  
         SET @nErrNo = 155801  
         SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --NeedLottable99  
         GOTO Quit  
      END  
  
      -- Check date  
      IF @nLottableNo IN (4, 5, 13, 14, 15) -- Date fields  
      BEGIN  
         -- Check valid date  
         IF @cLottable <> '' AND rdt.rdtIsValidDate( @cLottable) = 0  
         BEGIN  
            SET @nErrNo = 155802  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date  
            GOTO Quit  
         END  
      END  
      
      -- (cc01)     
      -- Check value exist in code lookup  
      IF @nLottableNo =  1 
      BEGIN 
      	SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottableVal01 AND StorerKey = @cStorerKey AND Code2 = @nLottableNo 
      	
      	IF @nExist = 0  
         BEGIN  
            SET @nErrNo = 155803 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot01  
            GOTO Quit  
         END
      END    
      

      IF @nLottableNo =  2 
      BEGIN 
      	SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottableVal02 AND StorerKey = @cStorerKey AND Code2 = @nLottableNo
      	
      	IF @nExist = 0  
         BEGIN  
            SET @nErrNo = 155804 
            SET @cErrMsg = @cLottableVal02--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot02  
            GOTO Quit  
         END 
      END     
      
      --IF @nLottableNo =  10 
      --BEGIN 
      --	SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottableVal10 AND StorerKey = @cStorerKey AND Code2 = @nLottableNo
      	
      --	IF @nExist = 0  
      --   BEGIN  
      --      SET @nErrNo = 155814 
      --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot10  
      --      GOTO Quit  
      --   END 
      --END     
      
      IF @nLottableNo =  12 
      BEGIN 
      	SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottableVal12 AND StorerKey = @cStorerKey AND Code2 = @nLottableNo
      	
      	IF @nExist = 0  
         BEGIN  
            SET @nErrNo = 155813 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot12  
            GOTO Quit  
         END  
      END     

      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND Lottable01 <> '' HAVING COUNT(DISTINCT(Lottable01)) > 1)
      BEGIN
         SET @nErrNo = 155805  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot01 
         GOTO Quit 
      END

      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND Lottable03 <> '' HAVING COUNT(DISTINCT(Lottable03)) > 1)  
      BEGIN
         SET @nErrNo = 155806  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot03
         GOTO Quit 
      END
      
      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND Lottable06 <> '' HAVING COUNT(DISTINCT(Lottable06)) > 1)  
      BEGIN
         SET @nErrNo = 155807  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot06
         GOTO Quit 
      END
      
      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND Lottable09 <> '' HAVING COUNT(DISTINCT(Lottable09)) > 1)  
      BEGIN
         SET @nErrNo = 155808  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot09
         GOTO Quit 
      END
      
      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND Lottable12 <> '' HAVING COUNT(DISTINCT(Lottable12)) > 1)  
      BEGIN
         SET @nErrNo = 155809  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot12
         GOTO Quit 
      END
      
      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND ISNULL(Lottable13,'') <> '' HAVING COUNT(DISTINCT(Lottable13)) > 1)  
      BEGIN
         SET @nErrNo = 155810  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot13
         GOTO Quit 
      END
      
      IF EXISTS(SELECT TOP 1 1 FROM ReceiptDetail RD (NOLOCK) WHERE RD.ReceiptKey = @cReceiptKey AND ISNULL(Lottable14,'') <> '' HAVING COUNT(DISTINCT(Lottable14)) > 1)  
      BEGIN
         SET @nErrNo = 155811  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultipleLot14
         GOTO Quit 
      END
      
      IF EXISTS(SELECT TOP 1 1 FROM((
      	               SELECT 
      	                  ReceiptKey,ReceiptLineNumber,StorerKey,Lottable10,SUM(BeforeReceivedQty)AS ReceivedQty 
      	               FROM ReceiptDetail RD(NOLOCK)   
      	               WHERE RD.ReceiptKey=@cReceiptKey   
      	               GROUP BY ReceiptKey,ReceiptLineNumber,StorerKey,Lottable10)AS RD1   
      	               FULL OUTER JOIN (SELECT 
      	                                 RD2.ReceiptKey,RD2.ReceiptLineNumber,RD2.StorerKey,UCCNo,SUM(QTY)AS UCCQty 
      	                                FROM ReceiptDetail RD2 (NOLOCK)  
      	                                JOIN UCC (NOLOCK) 
      	                                ON (RD2.ReceiptKey=UCC.ReceiptKey AND RD2.ReceiptLineNumber=UCC.ReceiptLineNumber AND RD2.StorerKey=UCC.StorerKey)   
      	                                WHERE RD2.ReceiptKey=@cReceiptKey  
      	                                GROUP BY RD2.ReceiptKey,RD2.ReceiptLineNumber,RD2.StorerKey,UCCNo)AS RD2   ON (RD2.ReceiptKey=RD1.ReceiptKey AND RD2.ReceiptLineNumber=RD1.ReceiptLineNumber   AND RD2.StorerKey=RD1.StorerKey AND RD2.UCCNo=RD1.Lottable10))  
                GROUP BY UCCNo   HAVING SUM(ISNULL(RD1.ReceivedQty,0))<>SUM(ISNULL(RD2.UCCQty,0)))      
      BEGIN
         SET @nErrNo = 155812  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RecQty<>UccQty
         GOTO Quit 
      END
   END  
Quit:  
     
END


GO