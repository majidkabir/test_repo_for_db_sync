SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   PROCEDURE [RDT].[rdtConvertToDate_NICK] (
   @cDate DATETIME,
   @cOutputDate DATETIME OUTPUT,
   @cID NVARCHAR(10) = '' OUTPUT
) 
AS
BEGIN
	print '1'
	SET @cOutputDate = DATEADD( DD, 2, @cDate)
	SET @cID = 'AAA'
	DECLARE @nMobile INT = 164

	--DECLARE @tReturnData TABLE
	--(
	--	Variable	NVARCHAR(30),
	--	Value		NVARCHAR(100)
	--)

	DECLARE @tReturnData SPReturnDataTable

	--INSERT INTO @tReturnData (Mobile, Variable, Value)
	--VALUES(@nMobile, '@cSKU', 'NNFG007'),
	--(@nMobile, '@cID', @cID)

	INSERT INTO @tReturnData
	EXEC [RDT].[rdtConvertToDate_NICK0] @cDate, @cOutputDate

	SELECT * FROM @tReturnData
END

GO