SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855ExtRefNo01                                   */
/* Purpose: For Levis                                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev    Author    Purposes                                 */
/* 2025-01-04 1.0.0  Dennis    FCR-1109 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_855ExtRefNo01] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @cStorer        NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cRefNo         NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cDropID        NVARCHAR( 20), 
   @cLoadKey       NVARCHAR( 10), 
   @cPickSlipNo    NVARCHAR( 10), 
   @cID            NVARCHAR( 18),
   @cTaskDetailKey NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cType          NVARCHAR( 20),
   @nCSKU          INT =0 OUTPUT ,
   @nCQTY          INT =0 OUTPUT ,
   @nPSKU          INT =0 OUTPUT, 
   @nPQTY          INT =0 OUTPUT, 
   @nVariance      INT =0 OUTPUT,
   @nQTY_PPA       INT =0 OUTPUT,
   @nQTY_CHK       INT =0 OUTPUT,
   @nRowRef        INT = 0 OUTPUT,
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
) 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cSQL             NVARCHAR(1000),
      @cSQLParam        NVARCHAR(1000)

   DECLARE
      @nPQTY_Total      INT,
      @nCQTY_Total      INT,
      @cConvertQTYSP       NVARCHAR( 20),
      @cPreCartonization   NVARCHAR( 1)

   DECLARE
      @nP_QTY           INT,
      @nC_QTY           INT,
      @cP_SKU           NVARCHAR( 20),
      @cC_SKU           NVARCHAR( 20)

   SELECT @cLangCode=lang_code,
          @nStep     = step
   FROM RDT.RDTMOBREC (NOLOCK)
   WHERE mobile=@nMobile

   IF @nVariance IS NOT NULL
   BEGIN
      DECLARE @tP TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
      DECLARE @tC TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
   END

   -- Get storer configure
   SET @cPreCartonization = rdt.RDTGetConfig( @nFunc, 'PreCartonization', @cStorer)
   SET @cConvertQTYSP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer)
   IF @cConvertQTYSP = '0'
      SET @cConvertQTYSP = ''
   SET @nPQTY = 0
   SET @nCQTY = 0
   IF @nFunc = 855 -- PPA by labelno
   BEGIN
      --GET PPA DETAILS
      SELECT TOP 1
         @nQTY_PPA = PQTY,
         @nQTY_CHK = CQTY,
         @nRowRef = RowRef
      FROM rdt.rdtPPA WITH (NOLOCK)
      WHERE SKU = @cSKU
         AND StorerKey = @cStorer
         AND DropID = @cDropID
      IF @nRowRef IS NULL
      BEGIN
         SELECT @nQTY_PPA = SUM( CASE WHEN @cPreCartonization = '1' THEN PD.ExpQTY ELSE PD.QTY END)
         FROM dbo.PackHeader PH WITH (NOLOCK)
            INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
         WHERE PD.LabelNo = @cDropID
            AND PH.StorerKey = @cStorer
            AND PD.SKU = @cSKU
      END

      IF @cDropID <> '' AND @cDropID IS NOT NULL            --INC1012120
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.PackDetail PD WITH (NOLOCK)
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
            WHERE PD.StorerKey = @cStorer
               AND PD.LabelNo = @cDropID

         IF @nPQTY IS NOT NULL
         BEGIN
            -- If convert qty sp setup then no need to get the base qty at this point
            IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer) <> ''
               AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
            BEGIN
               SET @nPQTY_Total = 0
               DECLARE @curPQTY_Total CURSOR
               SET @curPQTY_Total = CURSOR FOR
               SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.LabelNo = @cDropID
               GROUP BY PD.SKU
               OPEN @curPQTY_Total
               FETCH NEXT FROM @curPQTY_Total INTO @cP_SKU, @nP_QTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
                  SET @cSQLParam =
                     '@cType   NVARCHAR( 10), ' +
                     '@cStorer NVARCHAR( 15), ' +
                     '@cSKU    NVARCHAR( 20), ' +
                     '@nQTY    INT OUTPUT'
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cP_SKU, @nP_QTY OUTPUT

                  SET @nPQTY_Total = @nPQTY_Total + @nP_QTY
                  FETCH NEXT FROM @curPQTY_Total INTO @cP_SKU, @nP_QTY
               END
               CLOSE @curPQTY_Total
               DEALLOCATE @curPQTY_Total

               SET @nPQTY = @nPQTY_Total
            END
            ELSE
               SELECT @nPQTY = SUM( CASE WHEN @cPreCartonization = '1' THEN PD.ExpQTY ELSE PD.QTY END)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorer
                  AND PD.LabelNo = @cDropID
         END

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PackDetail PD WITH (NOLOCK)
               INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
            WHERE PD.StorerKey = @cStorer
               AND PD.LabelNo = @cDropID
            GROUP BY PD.StorerKey, PD.SKU
      END


      IF @nCSKU IS NOT NULL
         SELECT
            @nCSKU = COUNT( DISTINCT SKU)
         FROM rdt.rdtPPA WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND DropID = @cDropID

      IF @nCQTY IS NOT NULL
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer) <> ''
            AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
         BEGIN
            SET @nCQTY_Total = 0
            DECLARE @curCQTY_Total CURSOR
            SET @curCQTY_Total = CURSOR FOR
            SELECT SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND DropID = @cDropID
            GROUP BY SKU
            OPEN @curCQTY_Total
            FETCH NEXT FROM @curCQTY_Total INTO @cC_SKU, @nC_QTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
               SET @cSQLParam =
                  '@cType   NVARCHAR( 10), ' +
                  '@cStorer NVARCHAR( 15), ' +
                  '@cSKU    NVARCHAR( 20), ' +
                  '@nQTY    INT OUTPUT'
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cC_SKU, @nC_QTY OUTPUT

               SET @nCQTY_Total = @nCQTY_Total + @nC_QTY
               FETCH NEXT FROM @curCQTY_Total INTO @cC_SKU, @nC_QTY
            END
            CLOSE @curCQTY_Total
            DEALLOCATE @curCQTY_Total

            SET @nCQTY = @nCQTY_Total
         END
         ELSE
            SELECT
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND DropID = @cDropID
         

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND DropID = @cDropID
            GROUP BY StorerKey, SKU
      END
      -- SUM() might return NULL when no record
      SET @nCQTY = IsNULL( @nCQTY, 0)
      SET @nPQTY = IsNULL( @nPQTY, 0)

      -- Get variance
      IF @nVariance IS NOT NULL
      BEGIN
         IF EXISTS( SELECT TOP 1 1
            FROM @tP P
               FULL OUTER JOIN @tC C ON (P.SKU = C.SKU)
            WHERE P.SKU IS NULL
               OR C.SKU IS NULL
               OR P.QTY <> C.QTY)
            SET @nVariance = 1
         ELSE
            SET @nVariance = 0
      END
   END

Quit:

END
 

GO