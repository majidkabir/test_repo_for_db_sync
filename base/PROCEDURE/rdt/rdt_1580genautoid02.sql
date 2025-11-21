SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580GenAutoID02                                 */
/* Copyright: IDS                                                       */
/* Purpose: Generate lottable01 as ID                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2023-09-22   yeekung   1.0   WMS-23598 TOID = loc                    */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580GenAutoID02]
   @nMobile     INT,
   @nFunc       INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @cReceiptKey NVARCHAR( 10),
   @cPOKey      NVARCHAR( 10),
   @cLOC        NVARCHAR( 10),
   @cID         NVARCHAR( 18),
   @cOption     NVARCHAR( 1),
   @cAutoID     NVARCHAR( 18) OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @cAutoID = @cLOC
END

GO