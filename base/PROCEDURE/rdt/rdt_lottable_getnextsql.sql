SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Lottable_GetNextSQL                             */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: format input value                                          */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 21-06-2016  1.0  Ung       SOS372037 Created                         */
/* 05-10-2017  1.1  Ung       WMS-3052 Fix Date is NULL                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Lottable_GetNextSQL]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @nLottableOnPage  INT, 
   @cLottableCode    NVARCHAR( 30), 
   @cTableAlias      NVARCHAR( 20), 
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @cLottable06      NVARCHAR( 30), 
   @cLottable07      NVARCHAR( 30), 
   @cLottable08      NVARCHAR( 30), 
   @cLottable09      NVARCHAR( 30), 
   @cLottable10      NVARCHAR( 30), 
   @cLottable11      NVARCHAR( 30), 
   @cLottable12      NVARCHAR( 30), 
   @dLottable13      DATETIME, 
   @dLottable14      DATETIME, 
   @dLottable15      DATETIME, 
   @cSelect          NVARCHAR( MAX) OUTPUT,
   @cWhere1          NVARCHAR( MAX) OUTPUT,
   @cWhere2          NVARCHAR( MAX) OUTPUT,
   @cGroupBy         NVARCHAR( MAX) OUTPUT,
   @cOrderBy         NVARCHAR( MAX) OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLottableNo  INT
   DECLARE @cLottableNo  NVARCHAR( 2)
   DECLARE @cLottableVar NVARCHAR( 15)
   DECLARE @cLottableCol NVARCHAR( 15)

   -- Temp table for lottable
   DECLARE @tLC TABLE 
   (
      RowRef      INT           IDENTITY( 1,1), 
      LottableNo  INT           NOT NULL, 
      Visible     NVARCHAR(  1) NOT NULL, 
      Editable    NVARCHAR(  1) NOT NULL, 
      Required    NVARCHAR(  1) NOT NULL, 
      Sequence    INT           NOT NULL, 
      Description NVARCHAR( 20) NOT NULL, 
      FormatSP    NVARCHAR( 50) NOT NULL
   )

   SET @cSelect = ''
   SET @cWhere1 = ''
   SET @cWhere2 = ''
   SET @cGroupBy = ''
   SET @cOrderBy = ''

   IF @cLottableCode = ''
      GOTO Quit

   -- If function specific lottablecode not setup, use generic one
   IF @nFunc > 0
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtLottableCode WITH (NOLOCK)
         WHERE LottableCode = @cLottableCode
            AND Function_ID = @nFunc
            AND StorerKey = @cStorerKey)
         SET @nFunc = 0

   INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
   SELECT TOP (@nLottableOnPage)
      LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
   FROM rdt.rdtLottableCode WITH (NOLOCK)
   WHERE LottableCode = @cLottableCode
      AND Function_ID = @nFunc
      AND StorerKey = @cStorerKey
      AND Visible = '1'
   ORDER BY Sequence

   DECLARE @curLC CURSOR
   SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT LottableNo
      FROM @tLC
      ORDER BY Sequence
   OPEN @curLC
   FETCH NEXT FROM @curLC INTO @nLottableNo

   -- Loop lottable display on screen
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get lottable var
      SET @cLottableNo = RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2)
      SET @cLottableCol = @cTableAlias + '.' + 'Lottable' + @cLottableNo
      SET @cLottableVar = CASE WHEN @nLottableNo IN (4, 5, 13, 14, 15) THEN '@d' ELSE '@c' END + 'Lottable' + @cLottableNo
      
      -- Construct SQL clause
      SET @cSelect = @cSelect + ', ' + @cLottableVar + ' = ' + @cLottableCol
      SET @cWhere1 = @cWhere1 + 
         CASE WHEN @nLottableNo IN (1, 2, 3) 
              THEN '+ CAST( ' + @cLottableCol + ' AS NCHAR( 18))' 
              WHEN @nLottableNo IN (4, 5, 13, 14, 15) 
              THEN '+ CONVERT( NCHAR( 10), ISNULL( ' + @cLottableCol + ', 0), 120)'
              ELSE '+ CAST( ' + @cLottableCol + ' AS NCHAR( 30))' 
         END
      SET @cWhere2 = @cWhere2 + 
         CASE WHEN @nLottableNo IN (1, 2, 3) 
              THEN '+ CAST( ' + @cLottableVar + ' AS NCHAR( 18))' 
              WHEN @nLottableNo IN (4, 5, 13, 14, 15) 
              THEN '+ CONVERT( NCHAR( 10), ISNULL( ' + @cLottableVar + ', 0), 120)'
              ELSE '+ CAST( ' + @cLottableVar + ' AS NCHAR( 30))' 
         END
      SET @cGroupBy = @cGroupBy + ', ' + @cLottableCol
      SET @cOrderBy = @cOrderBy + ', ' + @cLottableCol
      
      FETCH NEXT FROM @curLC INTO @nLottableNo
   END
   
   -- Remove leading ", " 
   SET @cSelect = SUBSTRING( @cSelect, 3, LEN( @cSelect))
   SET @cWhere1 = SUBSTRING( @cWhere1, 3, LEN( @cWhere1))
   SET @cWhere2 = SUBSTRING( @cWhere2, 3, LEN( @cWhere2))
   SET @cGroupBy = SUBSTRING( @cGroupBy, 3, LEN( @cGroupBy))
   SET @cOrderBy = SUBSTRING( @cOrderBy, 3, LEN( @cOrderBy))

Quit:

END -- End Procedure


GO