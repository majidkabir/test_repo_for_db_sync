SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_641ExtInfo01                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Check validity of tracking id                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-03-12  1.0  James       WMS-12360. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_641ExtInfo01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cParentTrackID NVARCHAR( 20),
   @cChildTrackID  NVARCHAR( 1000),
   @cSKU           NVARCHAR( 10), 
   @nQty           INT,
   @cOption        NVARCHAR( 1), 
   @tExtInfo       VariableTable READONLY, 
   @cExtendedInfo  NVARCHAR( 20) OUTPUT     
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nCaseCnt       INT
   DECLARE @nPallet        INT
   DECLARE @nTrackingIDCnt INT = 0
   
   IF @nStep = 2 -- Child Tracking ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @nCaseCnt = PACK.CaseCnt,
                @nPallet = PACK.Pallet
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.Sku = @cSKU

         SELECT @nTrackingIDCnt = COUNT( DISTINCT TrackingID)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         
         SET @cExtendedInfo = CAST((@nCaseCnt * @nTrackingIDCnt) AS NVARCHAR( 4)) + '/' + CAST( @nPallet AS NVARCHAR( 4))
      END
   END

Quit:
END

GO