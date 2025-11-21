SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_LottableProcess_CheckValueInCodeLKUP                  */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check lottable received                                           */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 19-06-2019  Ung       1.0   WMS-9504 Created                               */
/* 21-08-2019  James     1.1   WMS-10217 Add retrieve default value (james01) */
/* 04-12-2020  Ung       1.2   WMS-14691 Fix default value                    */
/* 27-07-2022  Ung       1.3   Fix PRE should not prompt error                */
/* 24-08-2022  Ung       1.4   WMS-20493 Add overwrite default in PRE         */
/* 11-08-2023  yeekung   1.5   WMS-23200 Add allow blank (yeekung01)          */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableProcess_CheckValueInCodeLKUP]
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

   DECLARE @nExist INT = 0
   DECLARE @cLotAllowBlank NVARCHAR(20)


   SET @cLotAllowBlank = rdt.rdtGetConfig( @nFunc, 'LotAllowBlank', @cStorerKey)
   IF ISNULL(@cLotAllowBlank,'') = ''
      SET @cLotAllowBlank =0

   IF @cType = 'PRE'
   BEGIN
      -- IF @cLottable = '' -- Moved into T-SQL below, to support overwrite default
      BEGIN
         -- Get default
         IF @nLottableNo =  1 SELECT @cLottable01 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  2 SELECT @cLottable02 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  3 SELECT @cLottable03 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  4 SELECT @dLottable04 = rdt.rdtConvertToDate( Code) FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  5 SELECT @dLottable05 = rdt.rdtConvertToDate( Code) FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  6 SELECT @cLottable06 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  7 SELECT @cLottable07 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  8 SELECT @cLottable08 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo =  9 SELECT @cLottable09 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo = 10 SELECT @cLottable10 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo = 11 SELECT @cLottable11 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo = 12 SELECT @cLottable12 = Code                        FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo = 13 SELECT @dLottable13 = rdt.rdtConvertToDate( Code) FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo = 14 SELECT @dLottable14 = rdt.rdtConvertToDate( Code) FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) ELSE
         IF @nLottableNo = 15 SELECT @dLottable15 = rdt.rdtConvertToDate( Code) FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND StorerKey = @cStorerKey AND Code2 = @nLottableNo AND ((Short LIKE '%D%' AND @cLottable = '') OR (Short LIKE '%OD%')) 
      END
   END
   ELSE
   BEGIN
      



      -- Check lottable
      IF @nLottableNo =  1 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable01Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable01Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  2 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable02Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable02Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  3 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable03Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable03Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  4 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@dLottable04Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @dLottable04Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  5 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@dLottable05Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @dLottable05Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  6 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable06Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable06Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  7 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable07Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable07Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  8 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable08Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable08Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo =  9 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable09Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable09Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo = 10 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable10Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable10Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo = 11 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable11Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable11Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo = 12 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@cLottable12Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @cLottable12Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo = 13 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@dLottable13Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @dLottable13Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo = 14 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@dLottable14Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @dLottable14Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END ELSE
      IF @nLottableNo = 15 BEGIN IF @cLotAllowBlank ='1' AND ISNULL(@dLottable15Value,'')='' GOTO QUIT ELSE SELECT @nExist = 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLOTVal' AND Code = @dLottable15Value AND StorerKey = @cStorerKey AND Code2 = @nLottableNo END 

      -- Check value exist in code lookup
      IF @nExist = 0
      BEGIN
         SET @nErrNo = 140601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValueNotInList
         GOTO Quit
      END
   END

Quit:

END

GO