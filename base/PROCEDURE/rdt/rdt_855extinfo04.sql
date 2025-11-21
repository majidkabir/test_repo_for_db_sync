SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt.rdt_855ExtInfo04                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2017-07-05 1.0  Ung        WMS-2331 Created                                */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_855ExtInfo04]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY, 
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 855 -- PPA (DropID). Note: 1 DropID 1 SKU
   BEGIN
      IF @nAfterStep = 2 -- Statistic screen
      BEGIN
         DECLARE @cDropID  NVARCHAR(20)
         DECLARE @nCQTY    INT
         DECLARE @nPQTY    INT
         DECLARE @nCQTY_CS INT
         DECLARE @nPQTY_CS INT
         DECLARE @nCQTY_EA INT
         DECLARE @nPQTY_EA INT
         
         -- Variable mapping
         SELECT @cDropID = Value FROM @tExtInfo WHERE Variable = '@cDropID'
         SELECT @nCQTY = Value FROM @tExtInfo WHERE Variable = '@nCQTY'
         SELECT @nPQTY = Value FROM @tExtInfo WHERE Variable = '@nPQTY'

         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey) = '1'
         BEGIN
            SELECT 
               @nPQTY_CS = SUM( A.CS), 
               @nPQTY_EA = SUM( A.EA)
            FROM 
            (
               SELECT 
                  ISNULL( SUM( PD.QTY), 0) / CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END CS, 
                  ISNULL( SUM( PD.QTY), 0) % CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END EA
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
               GROUP BY SKU.StorerKey, SKU.SKU, Pack.CaseCnt
            ) A
         END
         
         ELSE IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey) = '1'
         BEGIN
            SELECT 
               @nPQTY_CS = SUM( A.CS), 
               @nPQTY_EA = SUM( A.EA)
            FROM 
            (
               SELECT 
                  ISNULL( SUM( PD.QTY), 0) / CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END CS, 
                  ISNULL( SUM( PD.QTY), 0) % CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END EA
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cDropID
               GROUP BY SKU.StorerKey, SKU.SKU, Pack.CaseCnt
            ) A
         END

         ELSE IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey) = '1'
         BEGIN
            SELECT 
               @nPQTY_CS = SUM( A.CS), 
               @nPQTY_EA = SUM( A.EA)
            FROM 
            (
               SELECT 
                  ISNULL( SUM( PD.QTY), 0) / CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END CS, 
                  ISNULL( SUM( PD.QTY), 0) % CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END EA
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'
               GROUP BY SKU.StorerKey, SKU.SKU, Pack.CaseCnt
            ) A
         END
         
         ELSE
         BEGIN
            SELECT 
               @nPQTY_CS = SUM( A.CS), 
               @nPQTY_EA = SUM( A.EA)
            FROM 
            (
               SELECT 
                  ISNULL( SUM( PD.QTY), 0) / CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END CS, 
                  ISNULL( SUM( PD.QTY), 0) % CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END EA
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'
               GROUP BY SKU.StorerKey, SKU.SKU, Pack.CaseCnt
            ) A
         END
         
         SELECT 
            @nCQTY_CS = SUM( A.CS), 
            @nCQTY_EA = SUM( A.EA)
         FROM 
         (
            SELECT 
               ISNULL( SUM( CQTY), 0) / CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END CS, 
               ISNULL( SUM( CQTY), 0) % CASE WHEN Pack.CaseCnt > 0 THEN CAST( Pack.CaseCnt AS INT) ELSE 1 END EA
            FROM rdt.rdtPPA PPA WITH (NOLOCK) 
               JOIN dbo.SKU WITH (NOLOCK) ON (PPA.StorerKey = SKU.StorerKey AND PPA.SKU = SKU.SKU)
               JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE PPA.StorerKey = @cStorerKey
               AND PPA.DropID = @cDropID
            GROUP BY SKU.StorerKey, SKU.SKU, Pack.CaseCnt
         ) A
         
         SET @cExtendedInfo = 
            CAST( @nCQTY_CS AS NVARCHAR( 3)) + 'C' + '-' + 
            CAST( @nCQTY_EA AS NVARCHAR( 3)) + 'P' + '/' + 
            CAST( @nPQTY_CS AS NVARCHAR( 3)) + 'C' + '-' + 
            CAST( @nPQTY_EA AS NVARCHAR( 3)) + 'P' 
      END
   END
   
QUIT:

END

GO