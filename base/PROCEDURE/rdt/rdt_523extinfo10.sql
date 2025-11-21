SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtInfo10                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2023-06-23 1.0  yeekung WMS-22805 Created                            */
/************************************************************************/

CREATE   PROC [RDT].[rdt_523ExtInfo10]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nAfterStep      INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cLOC            NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @cExtendedInfo1  NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cExtendedField01  NVARCHAR( 30) = ''

   IF @nFunc = 523 -- Putaway by SKU
   BEGIN
      IF @nAfterStep = 3 
      BEGIN
         DECLARE @cQTYDmg INT

         SELECT @cQTYDmg = sum(CAST (RD.userdefine05 AS INT)) 
         FROM RECEIPTDETAIL RD (NOLOCK)
         JOIN Itrn IT (NOLOCK) 
         ON (RD.receiptkey = SUBSTRING(IT.sourcekey,1,LEN(IT.sourcekey)-5) 
            AND RD.receiptlinenumber = SUBSTRING(IT.sourcekey,LEN(IT.sourcekey)-4,LEN(IT.sourcekey))
            AND IT.trantype ='DP'
            AND RD.SKU = IT.SKU
            AND RD.TOID = IT.TOID
            AND RD.Storerkey = IT.Storerkey)
         WHERE RD.SKU = @cSKU
            AND RD.toid =@cID
            AND RD.Storerkey = @cStorerKey
            AND RD.userdefine05 <> ''
            AND RD.Toloc = CASE WHEN ISNULL(@cLOC,'')='' THEN RD.Toloc ELSE @cLOC END

         SET @cExtendedInfo1 = 'QTYDMG: ' + CAST ( @cQTYDmg AS NVARCHAR(5))
      END

      IF @nAfterStep = 4  -- Suggest LOC, final LOC
      BEGIN
         SELECT @cExtendedField01 = ExtendedField01
         FROM dbo.SkuInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         SET @cExtendedInfo1 = @cExtendedField01
      END
   END
END

GO