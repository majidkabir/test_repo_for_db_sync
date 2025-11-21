SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenLottable04_01                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 21-11-2015   ChewKP    1.0   WMS-3175 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenLottable04_01]
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nShelfLife  INT
   DECLARE @dMfgDate    DATETIME
          ,@dExpiryDate DATETIME
          ,@dComputeDate DATETIME
          ,@cLottableLabel02 NVARCHAR(20)
          ,@cLottableLabel04 NVARCHAR(20) 
          ,@cExecStatements  NVARCHAR(4000) 
          ,@cComputeStatement NVARCHAR(4000)
          

   -- Check empty
   IF NOT (@cLottable02Value IS NULL)
   BEGIN
        
        
         
      SELECT     @cLottableLabel02 = Lottable02Label
               , @cLottableLabel04 = Lottable04Label
               , @nShelfLife       = ShelfLife
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU
      
     

      SELECT @cComputeStatement = Long
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE ListName = 'LOT04RULE'
      AND StorerKey = @cStorerKey
      AND Description = RTRIM(ISNULL(@cLottableLabel02,'') ) 
      AND Short = RTRIM(ISNULL(@cLottableLabel04,'') ) 

      --PRINT @cLottableLabel02 + ' ' + @cLottableLabel04 + ' ' + @cStorerKey
      --PRINT @cComputeStatement
      
      --Sample Statement
      --SET @cComputeStatement = 'SELECT @dComputeDate = DATEADD( day,' +  CAST(@nShelfLife AS NVARCHAR(5)) + '  * -1, ''' + @cLottable02Value + ''') '
      SELECT @cExecStatements = @cComputeStatement 
                                        
      EXEC sp_executesql @cExecStatements, N' @dComputeDate DATETIME OUTPUT , @nShelfLife INT , @cLottable02Value NVARCHAR(18) '  
                                                 , @dComputeDate OUTPUT ,@nShelfLife , @cLottable02Value
      
      SET @dLottable04 = CONVERT( NVARCHAR(8), @dComputeDate, 112)
      
      
      
--      
--      IF ISNULL(@dLottable04Value,'')  = '' 
--      BEGIN
--         IF @cLottableLabel02 = 'BATCHNO' AND @cLottableLabel04 = 'PRODN_DATE'
--         BEGIN
--            SET @dComputeDate = DATEADD( day, @nShelfLife * -1, @cLottable02Value)
--            SET @dLottable04 = CONVERT( NVARCHAR(8), @dComputeDate, 112)
--         END
--         ELSE IF @cLottableLabel02 = 'EXP_Date' AND @cLottableLabel04 = 'EXP_Date'
--         BEGIN
--            SET @dLottable04 = CONVERT( NVARCHAR(8), @cLottable02Value, 112)
--         END
--         ELSE IF @cLottableLabel02 = 'PRODN_DATE' AND @cLottableLabel04 = 'EXP_Date'
--         BEGIN
--            SET @dComputeDate = DATEADD( day, @nShelfLife, @cLottable02Value)
--            SET @dLottable04 = CONVERT( NVARCHAR(8), @dComputeDate, 112)
--         END
--         ELSE IF @cLottableLabel02 = 'PRODN_DATE' AND @cLottableLabel04 = 'PRODN_DATE'
--         BEGIN
--            SET @dLottable04 = CONVERT( NVARCHAR(8), @cLottable02Value, 112)
--         END
--         
--         SET @nErrNo = -1
--      END
      
      -- Calc L03 if blank
--      IF @cLottable03Value = ''
--      BEGIN
--         -- Get Shelf life info
--         SELECT @nShelfLife = ShelfLife
--         FROM SKU WITH (NOLOCK) 
--         WHERE StorerKey = @cStorerKey 
--            AND SKU = @cSKU
--
--         SET @dMfgDate = DATEADD( day, @nShelfLife * -1, @dLottable04Value)
--         SET @cLottable03 = CONVERT( NVARCHAR(8), @dMfgDate, 112)
--         
--         SET @nErrNo = -1
--      END
   END

Fail:

END

GO