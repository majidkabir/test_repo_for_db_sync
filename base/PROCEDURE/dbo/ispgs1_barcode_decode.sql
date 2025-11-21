SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispGS1_Barcode_Decode                              */
/* Creation Date: 27-Jan-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Michael Lam                                              */
/*                                                                      */
/* Purpose:  To decode GS1 Barcode                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 27-Jan-2011  MLam      Created                                       */
/* 24-Mar-2011  James     Add qty validation (james01)                  */
/************************************************************************/
CREATE PROC [dbo].[ispGS1_Barcode_Decode] (
	@cGS1_Barcode	NVARCHAR(100), 
	@cGTIN         NVARCHAR(14)    OUTPUT, 
	@dExpDt        DATETIME       OUTPUT, 
	@cBatch        NVARCHAR(20)    OUTPUT, 
	@nQty          INT            OUTPUT 
)
AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @nI      INT
	      , @nSepPos INT
	      , @cData   NVARCHAR(30)
	      , @cAI     NVARCHAR(4)
	      , @nLen    INT

	SET @cGTIN  = ''
	SET @dExpDt = NULL
	SET @cBatch = ''
	SET @nQty   = 0
	SET @nI = 1
	
	WHILE @nI < LEN(@cGS1_Barcode)
	BEGIN
	   SET @nSepPos = 0
	   SET @cData = ''
	   SET @cAI   = SUBSTRING(@cGS1_Barcode,@nI,2)
	   SET @nLen  = CASE @cAI WHEN '02' THEN 14  -- GTIN of Contained Trade Items
	                          WHEN '17' THEN 6   -- Expiration Date yymmdd
	                ELSE 0 END
	   IF ISNULL(@nLen,0) = 0    -- variable data length
	   BEGIN
	      SET @nSepPos = CHARINDEX('|', @cGS1_Barcode, @nI)
	      IF @nSepPos > 0
	         SET @nLen = @nSepPos - @nI - LEN(@cAI)
	      ELSE
	         SET @nLen = LEN(@cGS1_Barcode) + 1 - @nI - LEN(@cAI)
	   END
	   SET @cData = SUBSTRING(@cGS1_Barcode, @nI+LEN(@cAI), @nLen)
	
	   IF @cAI='02'
	      SET @cGTIN  = @cData
	   ELSE IF @cAI='17'
	      SET @dExpDt = CASE WHEN ISDATE(@cData)=1 
	                    THEN CONVERT(DATETIME, @cData, 12) END
	   ELSE IF @cAI='10'
	      SET @cBatch = @cData
	   ELSE IF @cAI='37'
	      SET @nQty   = CASE WHEN ISNUMERIC(@cData)=1 AND LEN(@cData)<=8 -- (james01)
	                    THEN CONVERT(FLOAT, @cData) END

	   SET @nI = @nI + LEN(@cAI) + @nLen + 
	             (CASE WHEN @nSepPos>0 THEN 1 ELSE 0 END)
	END
END

GO