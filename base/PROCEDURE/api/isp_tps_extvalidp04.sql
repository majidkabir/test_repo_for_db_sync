SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: isp_TPS_ExtValidP04                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2024-07-05   1.0  YeeKung  TPS-931 Created                                 */
/******************************************************************************/

CREATE    PROC [API].[isp_TPS_ExtValidP04] (
	@json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1        OUTPUT,
   @n_Err      INT = 0        OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
BEGIN
	DECLARE
		@cStorerKey		NVARCHAR ( 15),
      @cFacility		NVARCHAR ( 5),
      @nFunc			INT,
      @cBarcode		NVARCHAR( 60),
      @cUserName		NVARCHAR( 30),
      @cLangCode		NVARCHAR( 3),
      @cSKU				NVARCHAR( 30),
		@cPickSlipNo	NVARCHAR( 30),
		@nQTY				INT,
		@cOrderKey		NVARCHAR( 20),
		@cLoadkey		NVARCHAR( 20),
		@cZone			NVARCHAR( 20),
		@nPickQTY		INT,
		@nPackQTY		INT

	--Decode Json Format
   SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc = Func, @cBarcode = Barcode, @cUserName = UserName, @cLangCode = LangCode, @cPickSlipNo = PickSlipNo
   FROM OPENJSON(@json)
   WITH (
      StorerKey   NVARCHAR ( 15),
      Facility    NVARCHAR ( 5),
      Func        INT,
      Barcode     NVARCHAR( 60),
		PickSlipNo  NVARCHAR( 20),
      UserName    NVARCHAR( 30),
      LangCode    NVARCHAR( 3)
   )

   SET @b_Success = 1

   IF EXISTS (SELECT 1
              FROM UCC (NOLOCK)
              WHERE UCCNO = @cBarcode
               AND Storerkey = @cStorerKey)
   BEGIN
		SELECT @cSKU = ISNULL(RTRIM(SKU),''), @nQTY = qty 
		FROM UCC WITH (NOLOCK)
		where UCCNO=@cBarcode
		AND storerkey=@cStorerKey


		SELECT @cPickSlipNo = ScanNo 
		FROM API.APPSection(nolock) 
		WHERE UserID = @cUserName

      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo


		IF @cOrderKey <> ''
      BEGIN
			SELECT @nPickQTY = SUM(PD.QTY)
			FROM pickDetail PD WITH (NOLOCK)
			LEFT JOIN orders O WITH (NOLOCK) ON (PD.orderKey = O.OrderKey) --(cc02)
			--LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
			WHERE PD.OrderKey = @cOrderKey
				AND PD.Status <= '5'
				AND PD.SKU = @cSKU
				AND PD.Status NOT IN  ('4')
			GROUP BY PD.SKU,PD.OrderKey--,UCC.UCCNo--,PD.Status (yeekung)
		END
		IF @cLoadKey <> ''
      BEGIN
			SELECT @nPickQTY = SUM(PD.QTY)
			FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            --LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.Status <= '5'
            AND PD.Status NOT IN  ('4')
            AND PD.SKU = @cSKU
	      GROUP BY PD.SKU --(yeekung03)
		END
		ELSE
		BEGIN
			SELECT @nPickQTY = SUM(PD.QTY)
	      FROM dbo.PickDetail PD WITH (NOLOCK)
            --    LEFT JOIN UCC UCC WITH (NOLOCK) ON (PD.SKU=UCC.SKU AND PD.storerkey=UCC.storerkey AND PD.Lot=UCC.lot AND PD.LOC=UCC.LOC)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.Status <= '5'
            AND PD.Status NOT IN  ('4')
				AND PD.SKU = @cSKU
	      GROUP BY PD.SKU,PD.OrderKey--,UCC.UCCNo--,PD.Status
		END

		SELECT @nPackQTY = SUM(QTY)
	   FROM dbo.Packdetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
			AND SKU = @cSKU

		SET @nPackQTY = CASE WHEN ISNULL(@nPackQTY,0 ) = 0 THEN 0 ELSE @nPackQTY END 

		IF @nPickQTY < @nPackQTY + @nQTY
		BEGIN
			SET @n_Err = 1000501      
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')
         SET @jResult = (SELECT '' AS SKU
         FOR JSON PATH,INCLUDE_NULL_VALUES )    
         SET @b_Success = 0
         GOTO QUIT
		END

		SET @jResult = (SELECT ISNULL(RTRIM(SKU),'') AS SKU,qty as qtypacked,@cBarcode AS UCC,'UCC' AS type
         FROM UCC WITH (NOLOCK)
         where UCCno=@cBarcode
         AND storerkey=@cStorerKey
      FOR JSON AUTO, INCLUDE_NULL_VALUES)   



   END
	ELSE
	BEGIN
		SET @jResult = (SELECT @cBarcode AS SKU,'SKU' AS type
      FOR JSON PATH,INCLUDE_NULL_VALUES)  

	END


   SELECT @cStorerKey '@cStorerKey', @cBarcode '@cBarcode', @jResult '@jResult'
QUIT:
END


GO