SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/**************************************************************************/  
/* Store procedure: rdt_LottableProcess_RC01L01                            */  
/* Copyright      : LF                                                    */  
/*                                                                        */  
/* Purpose: validate L01                                                  */  
/*                                                                        */  
/*                                                                        */  
/* Date        Rev  Author      Purposes                                  */  
/* 2023-07-05 1.0  yeekung    wms-22977 Created                            */
/**************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_LottableProcess_RC01L01]  
    @nMobile          INT  
   ,@nFunc            INT  
   ,@cLangCode        NVARCHAR( 3)  
   ,@nInputKey        INT  
   ,@cStorerKey       NVARCHAR( 15)  
   ,@cSKU             NVARCHAR( 20)  
   ,@cLottableCode    NVARCHAR( 30)  
   ,@nLottableNo      INT  
   ,@cLottable        NVARCHAR( 30)  
   ,@cType            NVARCHAR( 10)  
   ,@cSourceKey       NVARCHAR( 15)  
   ,@cLottable01Value NVARCHAR( 18)  
   ,@cLottable02Value NVARCHAR( 18)  
   ,@cLottable03Value NVARCHAR( 18)  
   ,@dLottable04Value DATETIME  
   ,@dLottable05Value DATETIME  
   ,@cLottable06Value NVARCHAR( 30)  
   ,@cLottable07Value NVARCHAR( 30)  
   ,@cLottable08Value NVARCHAR( 30)  
   ,@cLottable09Value NVARCHAR( 30)  
   ,@cLottable10Value NVARCHAR( 30)  
   ,@cLottable11Value NVARCHAR( 30)  
   ,@cLottable12Value NVARCHAR( 30)  
   ,@dLottable13Value DATETIME  
   ,@dLottable14Value DATETIME  
   ,@dLottable15Value DATETIME  
   ,@cLottable01      NVARCHAR( 18) OUTPUT  
   ,@cLottable02      NVARCHAR( 18) OUTPUT  
   ,@cLottable03      NVARCHAR( 18) OUTPUT  
   ,@dLottable04      DATETIME      OUTPUT  
   ,@dLottable05      DATETIME      OUTPUT  
   ,@cLottable06      NVARCHAR( 30) OUTPUT  
   ,@cLottable07      NVARCHAR( 30) OUTPUT  
   ,@cLottable08      NVARCHAR( 30) OUTPUT  
   ,@cLottable09      NVARCHAR( 30) OUTPUT  
   ,@cLottable10      NVARCHAR( 30) OUTPUT  
   ,@cLottable11      NVARCHAR( 30) OUTPUT  
   ,@cLottable12      NVARCHAR( 30) OUTPUT  
   ,@dLottable13      DATETIME      OUTPUT  
   ,@dLottable14      DATETIME      OUTPUT  
   ,@dLottable15      DATETIME      OUTPUT  
   ,@nErrNo           INT           OUTPUT  
   ,@cErrMsg          NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cReceiptkey nvarchar(20)

   SELECT @cReceiptkey=V_receiptkey,
         @cLottable01 = V_ID
   FROM rdt.rdtmobrec (NOLOCK)
   where mobile=@nmobile
   and storerkey=@cstorerkey

    IF @cLottable01 <> @cLottable01Value
   BEGIN
      SET @nErrNo = 203701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidID
      GOTO QUIT
   END
  
   Quit:  
     
  
END -- End Procedure  
  


GO