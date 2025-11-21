SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832Decode01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-07-15  1.0  Ung         WMS-13699 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_832Decode01] (
	@nMobile        INT,           
	@nFunc          INT,           
	@cLangCode      NVARCHAR( 3),  
	@nStep          INT,           
	@nInputKey      INT,           
	@cStorerKey     NVARCHAR( 15), 
	@cFacility      NVARCHAR( 5),  
	@cBarcode       NVARCHAR( 60), 
	@cCartonID      NVARCHAR( 20)  OUTPUT,
	@cCartonSKU     NVARCHAR( 20)  OUTPUT,
	@nCartonQTY     INT            OUTPUT,
	@nErrNo         INT            OUTPUT,
	@cErrMsg        NVARCHAR( 20)  OUTPUT 
)
AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	IF LEN( @cBarcode) = 31 -- SKU
	BEGIN
	   /*
	      E.g.:
	      93300012249    4057828337241015
	      
	      Len:
	      11 = PO
	      4  = blank
	      13 = UPC
	      3  = Pack
	   */
		SET @cCartonID = SUBSTRING( @cBarcode, 16, 13)
	END

Quit:

END

GO