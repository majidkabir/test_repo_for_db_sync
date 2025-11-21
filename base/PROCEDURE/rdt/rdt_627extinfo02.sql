SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: rdt_627ExtInfo02                                    */
/* Purpose: Add Display Lottable02 For Hisense                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author       Ver.   Purposes                            */
/* 2024-10-09   Wang ShaoAn  1.0    FCR-821 Created                     */
/************************************************************************/

CREATE    PROC [RDT].[rdt_627ExtInfo02]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cStorerkey      NVARCHAR( 15)
   ,@cSKU            NVARCHAR( 20)
   ,@cID             NVARCHAR( 20)
   ,@cSerialNo       NVARCHAR( 20)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@cExtendedInfo2  NVARCHAR( 20) OUTPUT
   ,@cExtendedInfo3  NVARCHAR( 20) OUTPUT
   ,@cExtendedInfo4  NVARCHAR( 20) OUTPUT
   ,@cExtendedInfo5  NVARCHAR( 20) OUTPUT
   ,@cExtendedInfo6  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT

AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable02    NVARCHAR(20),
           @cLot           NVARCHAR(10)

   IF @nFunc = 627 AND @nStep = 1
   BEGIN

       -- Get Lot 
      SELECT TOP 1 @cLot = Lot
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE Serialno = @cSerialNo
      AND   SKU = @cSKU
      ORDER BY SerialNoKey DESC
      
      -- Get Lottable02
      SELECT @cLottable02 = Lottable02
      FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
      WHERE Lot = @cLot

      IF @cLottable02 IS NULL OR @cLottable02 = ''
      BEGIN
         SET @cExtendedInfo1='Lottable02:  ';
      END
      ELSE 
      BEGIN
         SET @cExtendedInfo1='Lottable02: '
         SET @cExtendedInfo2=CAST(@cLottable02 AS NVARCHAR(20))
      END
   END

GO