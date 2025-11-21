SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_610DecodeSP02                                         */
/* Copyright: MAERSK                                                          */
/*                                                                            */
/* Purpose: Nike decode QR barcode return UCC no                              */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-09-05  James     1.0   WMS-23451 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_610DecodeSP02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cCCRefNo       NVARCHAR( 10),
   @cCCSheetNo     NVARCHAR( 10),
   @cBarcode       NVARCHAR( MAX),
   @cLOC           NVARCHAR( 10)  OUTPUT,
   @cID            NVARCHAR( 18)  OUTPUT,
   @cUCC           NVARCHAR( 20)  OUTPUT,
   @cUPC           NVARCHAR( 20)  OUTPUT,
   @nQTY           INT            OUTPUT,
   @cLottable01    NVARCHAR( 18)  OUTPUT,
   @cLottable02    NVARCHAR( 18)  OUTPUT,
   @cLottable03    NVARCHAR( 18)  OUTPUT,
   @dLottable04    DATETIME       OUTPUT,
   @dLottable05    DATETIME       OUTPUT,
   @cLottable06    NVARCHAR( 30)  OUTPUT,
   @cLottable07    NVARCHAR( 30)  OUTPUT,
   @cLottable08    NVARCHAR( 30)  OUTPUT,
   @cLottable09    NVARCHAR( 30)  OUTPUT,
   @cLottable10    NVARCHAR( 30)  OUTPUT,
   @cLottable11    NVARCHAR( 30)  OUTPUT,
   @cLottable12    NVARCHAR( 30)  OUTPUT,
   @dLottable13    DATETIME       OUTPUT,
   @dLottable14    DATETIME       OUTPUT,
   @dLottable15    DATETIME       OUTPUT,
   @cUserDefine01  NVARCHAR( 60)  OUTPUT,
   @cUserDefine02  NVARCHAR( 60)  OUTPUT,
   @cUserDefine03  NVARCHAR( 60)  OUTPUT,
   @cUserDefine04  NVARCHAR( 60)  OUTPUT,
   @cUserDefine05  NVARCHAR( 60)  OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT

   DECLARE @cActUCCNo      NVARCHAR( 20)

   DECLARE @cBatchNo       NVARCHAR( 18)
   DECLARE @nBatchNoStart  INT
   DECLARE @nBatchNoEnd    INT

   DECLARE @cBoxNo         NVARCHAR( 10)
   DECLARE @nBoxNoStart    INT
   DECLARE @nBoxNoEnd      INT

   SET @nErrNo = 0
   SET @cErrMsg = 0

   /*
      2D barcode:
         ,950-8700-30:1000193193.04/06/2023;BVTN>D1^GKF001%10109975<596*HTUQU1,350

      After formatted:
      ,950-8700-30
      :1000193193      -- 2nd param, Batch no
      .04/06/2023
      ;BVTN
      >D1
      ^GKF001
      %10109975
      <596             -- 8th param, Box no
      *HTUQU1
      ,350
   */
   
   IF @nFunc = 610 -- Cycle Count
   BEGIN
      IF @nStep = 9 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SET @nBatchNoStart = CHARINDEX( ':', @cBarcode)
               SET @nBatchNoEnd = CHARINDEX( '.', @cBarcode)
               SET @nBoxNoStart = CHARINDEX( '<', @cBarcode)
               SET @nBoxNoEnd = CHARINDEX( '*', @cBarcode)

               IF @nBatchNoStart > 0 AND @nBatchNoEnd > 0 
                  SET @cBatchNo = SUBSTRING( @cBarcode, @nBatchNoStart+1, @nBatchNoEnd-@nBatchNoStart-1)
      
               IF @nBoxNoStart > 0 AND @nBoxNoEnd > 0 
                  SET @cBoxNo = SUBSTRING( @cBarcode, @nBoxNoStart+1, @nBoxNoEnd-@nBoxNoStart-1)
      
               IF @cBatchNo <> '' AND @cBoxNo <> ''
                  SET @cActUCCNo = @cBatchNo + '-' + @cBoxNo

               SET @cUCC = @cActUCCNo
            END
         END   -- ENTER
      END   -- @nStep = 9
   END

Quit:

END

GO