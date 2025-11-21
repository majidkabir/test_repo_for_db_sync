SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: rdt_LottableFormat_Decode                            */
/* Copyright      : LF Logistics                                         */
/*                                                                       */
/* Date        Rev  Author      Purposes                                 */
/* 07-05-2018  1.0  Ung         WMS-4668 Created                         */
/*************************************************************************/
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_Decode]  
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
  
   DECLARE @nDecodeErrNo INT

   DECLARE @cLottable01   NVARCHAR( 18)
   DECLARE @cLottable02   NVARCHAR( 18)
   DECLARE @cLottable03   NVARCHAR( 18)
   DECLARE @dLottable04   DATETIME     
   DECLARE @dLottable05   DATETIME     
   DECLARE @cLottable06   NVARCHAR( 30)
   DECLARE @cLottable07   NVARCHAR( 30)
   DECLARE @cLottable08   NVARCHAR( 30)
   DECLARE @cLottable09   NVARCHAR( 30)
   DECLARE @cLottable10   NVARCHAR( 30)
   DECLARE @cLottable11   NVARCHAR( 30)
   DECLARE @cLottable12   NVARCHAR( 30)
   DECLARE @dLottable13   DATETIME     
   DECLARE @dLottable14   DATETIME     
   DECLARE @dLottable15   DATETIME     

   -- Date cannot be decode
   IF @nLottableNo IN (4, 5, 13, 14, 15)
      GOTO Quit

   -- Set default as not mapped (for rdt_Decode)
   SET @dLottable04 = -1
   SET @dLottable05 = -1
   SET @dLottable13 = -1
   SET @dLottable14 = -1
   SET @dLottable15 = -1

   -- Get lottable
   IF @nLottableNo =  1 SET @cLottable01 = @cLottableValue ELSE 
   IF @nLottableNo =  2 SET @cLottable02 = @cLottableValue ELSE 
   IF @nLottableNo =  3 SET @cLottable03 = @cLottableValue ELSE 
   IF @nLottableNo =  4 SET @dLottable04 = @cLottableValue ELSE 
   IF @nLottableNo =  5 SET @dLottable05 = @cLottableValue ELSE 
   IF @nLottableNo =  6 SET @cLottable06 = @cLottableValue ELSE 
   IF @nLottableNo =  7 SET @cLottable07 = @cLottableValue ELSE 
   IF @nLottableNo =  8 SET @cLottable08 = @cLottableValue ELSE 
   IF @nLottableNo =  9 SET @cLottable09 = @cLottableValue ELSE 
   IF @nLottableNo = 10 SET @cLottable10 = @cLottableValue ELSE 
   IF @nLottableNo = 11 SET @cLottable11 = @cLottableValue ELSE 
   IF @nLottableNo = 12 SET @cLottable12 = @cLottableValue ELSE 
   IF @nLottableNo = 13 SET @dLottable13 = @cLottableValue ELSE 
   IF @nLottableNo = 14 SET @dLottable14 = @cLottableValue ELSE 
   IF @nLottableNo = 15 SET @dLottable15 = @cLottableValue

   -- Get session info
   DECLARE @nStep INT
   DECLARE @cFacility NVARCHAR(5)
   SELECT 
      @nStep = Step, 
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Decode
   EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cLottableValue, 
      @cLottable01 = @cLottable01  OUTPUT, 
      @cLottable02 = @cLottable02  OUTPUT, 
      @cLottable03 = @cLottable03  OUTPUT, 
      @dLottable04 = @dLottable04  OUTPUT, 
      @dLottable05 = @dLottable05  OUTPUT,
      @cLottable06 = @cLottable06  OUTPUT, 
      @cLottable07 = @cLottable07  OUTPUT, 
      @cLottable08 = @cLottable08  OUTPUT, 
      @cLottable09 = @cLottable09  OUTPUT, 
      @cLottable10 = @cLottable10  OUTPUT,
      @cLottable11 = @cLottable11  OUTPUT, 
      @cLottable12 = @cLottable12  OUTPUT, 
      @dLottable13 = @dLottable13  OUTPUT, 
      @dLottable14 = @dLottable14  OUTPUT, 
      @dLottable15 = @dLottable15  OUTPUT, 
      @nErrNo      = @nDecodeErrNo OUTPUT

--insert into a (field, value) values ('@nLottableNo', cast( @nLottableNo as nvarchar(10)))

   IF @nDecodeErrNo = 0
   BEGIN
      IF @nLottableNo =  1 SET @cLottable = @cLottable01 ELSE 
      IF @nLottableNo =  2 SET @cLottable = @cLottable02 ELSE 
      IF @nLottableNo =  3 SET @cLottable = @cLottable03 ELSE 
      IF @nLottableNo =  4 SET @cLottable = @dLottable04 ELSE 
      IF @nLottableNo =  5 SET @cLottable = @dLottable05 ELSE 
      IF @nLottableNo =  6 SET @cLottable = @cLottable06 ELSE 
      IF @nLottableNo =  7 SET @cLottable = @cLottable07 ELSE 
      IF @nLottableNo =  8 SET @cLottable = @cLottable08 ELSE 
      IF @nLottableNo =  9 SET @cLottable = @cLottable09 ELSE 
      IF @nLottableNo = 10 SET @cLottable = @cLottable10 ELSE 
      IF @nLottableNo = 11 SET @cLottable = @cLottable11 ELSE 
      IF @nLottableNo = 12 SET @cLottable = @cLottable12 ELSE 
      IF @nLottableNo = 13 SET @cLottable = @dLottable13 ELSE 
      IF @nLottableNo = 14 SET @cLottable = @dLottable14 ELSE 
      IF @nLottableNo = 15 SET @cLottable = @dLottable15
   END
-- insert into a (field, value) values ('@cLottable', @cLottable)

Quit:  
  
END -- End Procedure  

GO