SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: ispPieceRcvExtInfo10                                   */
/* Copyright      : LFLogistics                                            */
/*                                                                         */
/* Purpose: Display Count                                                  */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-01-05 1.0  yeekung    WMS-18685 Created                            */
/***************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo10] (
  @cReceiptKey   NVARCHAR( 10), 
  @cPOKey        NVARCHAR( 10), 
  @cLOC          NVARCHAR( 10), 
  @cToID         NVARCHAR( 18), 
  @cLottable01   NVARCHAR( 18), 
  @cLottable02   NVARCHAR( 18), 
  @cLottable03   NVARCHAR( 18), 
  @dLottable04   DATETIME,  
  @cStorer       NVARCHAR( 15), 
  @cSKU          NVARCHAR( 20), 
  @cExtendedInfo NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nStep                  INT
          ,@BUSR10  NVARCHAR(20)
          ,@cErrMsg1 NVARCHAR(20)
          ,@cErrMsg2 NVARCHAR(20)
          ,@nMobile INT
          ,@nErrno INT
          ,@cErrMsg NVARCHAR(MAX)
   
   SELECT TOP 1 @nStep = Step ,
               @nMobile=Mobile
   FROM rdt.RDTMobrec WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
   AND Func = 1580 
   AND V_ReceiptKey = @cReceiptKey
   AND V_Loc = @cLoc
   AND V_ID  = @cToID

          
   IF @nStep = 5
   BEGIN
      SET @cErrMsg1='notice'

      SELECT
         @cErrMsg2=busr10
      FROM sku (NOLOCK) 
      WHERE sku=@cSKU
      AND storerkey=@cstorer

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2

      SET @nErrNo=0

   END

END

GO