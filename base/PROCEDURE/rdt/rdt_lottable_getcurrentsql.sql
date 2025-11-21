SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Lottable_GetCurrentSQL                          */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Generate TSQL for current lottables                         */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 30-06-2016  1.0  Ung       SOS372037 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Lottable_GetCurrentSQL]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cLottableCode    NVARCHAR( 30), 
   @nLottableOnPage  INT, 
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
   @cWhere           NVARCHAR( MAX) OUTPUT,
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
   DECLARE @cWhere1     NVARCHAR( MAX)
   DECLARE @cWhere2     NVARCHAR( MAX)

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

   SET @cWhere = ''

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
      -- Get lottable
      SET @cLottableNo = RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2)
      SET @cLottableCol = @cTableAlias + '.' + 'Lottable' + @cLottableNo
      SET @cLottableVar = CASE WHEN @nLottableNo IN (4, 5, 13, 14, 15) THEN '@d' ELSE '@c' END + 'Lottable' + @cLottableNo
      
      -- Construct SQL clause
      SET @cWhere = @cWhere + ' AND ' + @cLottableCol + ' = ' + @cLottableVar
      
      FETCH NEXT FROM @curLC INTO @nLottableNo
   END
   
   -- Construct remain SQL clause
   IF @cWhere <> ''
      SET @cWhere = SUBSTRING( @cWhere, 5, LEN( @cWhere)) -- Remove leading " AND " 

Quit:

END -- End Procedure


GO