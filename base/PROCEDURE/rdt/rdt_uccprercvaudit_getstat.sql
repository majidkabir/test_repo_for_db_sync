SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCPreRCVAudit_GetStat                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2014-06-13 1.0  Ung        SOS?????? Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCPreRCVAudit_GetStat] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3),
   @cFacility   NVARCHAR( 5), 
   @cStorerKey  NVARCHAR( 15),
   @cOrgUCCNo   NVARCHAR( 20),
   @nCSKU       INT = NULL OUTPUT, 
   @nCQTY       INT = NULL OUTPUT, 
   @nPSKU       INT = NULL OUTPUT, 
   @nPQTY       INT = NULL OUTPUT, 
   @nVariance   INT = NULL OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Get checked SKU
IF @nCSKU IS NOT NULL
   SELECT @nCSKU = COUNT( DISTINCT SKU)
   FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrgUCCNo = @cOrgUCCNo

-- Get checked QTY
IF @nCQTY IS NOT NULL
   SELECT @nCQTY = ISNULL( SUM( QTY), 0)
   FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrgUCCNo = @cOrgUCCNo

-- Get total SKU
IF @nPSKU IS NOT NULL
   SELECT @nPSKU = COUNT( DISTINCT SKU)
   FROM UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cOrgUCCNo
/*
   SELECT @nPSKU = COUNT( DISTINCT SKU)
   FROM
   (
      SELECT SKU
      FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrgUCCNo = @cOrgUCCNo
      UNION
      SELECT SKU
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cOrgUCCNo
   ) A
*/

-- Get total QTY
IF @nPQTY IS NOT NULL
   SELECT @nPQTY = ISNULL( SUM( QTY), 0)
   FROM UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cOrgUCCNo
/*
BEGIN   
   DECLARE @nNotCheckQTY INT
   SELECT @nNotCheckQTY = ISNULL( SUM( QTY), 0)
   FROM UCC WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cOrgUCCNo

   DECLARE @nCheckQTY INT
   SELECT @nCheckQTY = ISNULL( SUM( QTY), 0)
   FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND OrgUCCNo = @cOrgUCCNo
      AND Status = '9' -- Closed

   SET @nPQTY = @nNotCheckQTY + @nCheckQTY
END
*/   

-- Get variance
IF @nVariance IS NOT NULL
BEGIN
   IF EXISTS( SELECT TOP 1 1
      FROM 
      (
         SELECT SKU, ISNULL( SUM( QTY), 0) QTY
         FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND OrgUCCNo = @cOrgUCCNo
         GROUP BY SKU
      ) A FULL OUTER JOIN 
      (
         SELECT SKU, ISNULL( SUM( QTY), 0) QTY
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cOrgUCCNo
         GROUP BY SKU
      ) B ON (A.SKU = B.SKU)
      WHERE A.SKU IS NULL
         OR B.SKU IS NULL
         OR A.QTY <> B.QTY)
      
      SET @nVariance = 1
   ELSE
      SET @nVariance = 0
END

GO