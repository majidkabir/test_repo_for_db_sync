SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry09                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2021-07-01 1.0  Chermaine  WMS-17385 Created                            */
/***************************************************************************/

CREATE PROC [RDT].[rdt_727Inquiry09] (
 	@nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(20),  
   @cParam2      NVARCHAR(20),  
   @cParam3      NVARCHAR(20),  
   @cParam4      NVARCHAR(20),  
   @cParam5      NVARCHAR(20),  
   @c_oFieled01  NVARCHAR(20) OUTPUT,  
   @c_oFieled02  NVARCHAR(20) OUTPUT,  
   @c_oFieled03  NVARCHAR(20) OUTPUT,  
   @c_oFieled04  NVARCHAR(20) OUTPUT,  
   @c_oFieled05  NVARCHAR(20) OUTPUT,  
   @c_oFieled06  NVARCHAR(20) OUTPUT,  
   @c_oFieled07  NVARCHAR(20) OUTPUT,  
   @c_oFieled08  NVARCHAR(20) OUTPUT,  
   @c_oFieled09  NVARCHAR(20) OUTPUT,  
   @c_oFieled10  NVARCHAR(20) OUTPUT,  
   @c_oFieled11  NVARCHAR(20) OUTPUT,  
   @c_oFieled12  NVARCHAR(20) OUTPUT,  
   @nNextPage    INT          OUTPUT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR(20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0

   IF @cOption = '1' 
   BEGIN
      IF @nStep = 2
      BEGIN
      	DECLARE @tCartonInfo TABLE  
         (  
            RowRef      INT,  
            DropID      NVARCHAR(20),
            WaveKey     NVARCHAR(10),  
            Loc         NVARCHAR(10),  
            SKU         NVARCHAR(20),  
            Qty         NVARCHAR(5)
         )  
   
         DECLARE @cDropID     NVARCHAR( 20)
         DECLARE @cSku        NVARCHAR( 20)
         DECLARE @nMaxRow     INT
         DECLARE @nPrevRow    INT
        

         -- Parameter mapping
         SET @cDropID = @cParam1


         -- Check both ID and PSNO blank
         IF @cDropID = '' 
         BEGIN
            SET @nErrNo = 169951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID/PSNO
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- DropID
            GOTO QUIT
         END
         
         IF NOT EXISTS (SELECT 1 FROM pickDetail WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND DropID = @cDropID AND Status < '9')
         BEGIN
         	SET @nErrNo = 169952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID/PSNO
            EXEC rdt.rdtSetFocusField @nMobile, 1  -- DropID
            GOTO QUIT
         END
         
         SELECT @cSku = O_Field08 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile  
                  
         -- Get Info
         INSERT INTO @tCartonInfo (RowRef,DropID,WaveKey,Loc,SKU,Qty)
         SELECT 
            ROW_NUMBER() OVER(PARTITION BY PD.DropID ORDER BY PD.SKU ASC),
            PD.DropID, 
            WD.waveKey, 
            CASE WHEN ISNULL(DP.DeviceID,'') = '' THEN PD.Loc ELSE DP.DeviceID END, 
            PD.SKU, 
            SUM(PD.Qty)
         FROM pickDetail PD WITH (NOLOCK) 
         LEFT JOIN waveDetail WD WITH (NOLOCK) ON (PD.orderKey = WD.OrderKey) 
         LEFT JOIN DeviceProfile DP WITH (NOLOCK) ON (DP.Loc = PD.Loc AND DP.StorerKey = PD.Storerkey)
         WHERE PD.storerKey = @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.STATUS <'9' 
         GROUP BY PD.DropID, WD.waveKey, PD.Loc, DP.DeviceID, PD.SKU
         ORDER BY PD.SKU

         -- Check consignee SKU
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 169953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSKU
            GOTO QUIT
         END
         
         SELECT @nMaxRow = MAX(RowRef) FROM @tCartonInfo
         
         --1st Data
         IF ISNULL(@cSku,'') = ''
         BEGIN
         	SELECT TOP 1
               @c_oFieled02 = DropID, 
               @c_oFieled04 = waveKey, 
               @c_oFieled05 = Loc, 
               @c_oFieled08 = SKU, 
               @c_oFieled09 = QTY
         	FROM @tCartonInfo
         END
         ELSE
         BEGIN
         	SELECT @nPrevRow = rowRef FROM @tCartonInfo WHERE SKU = @cSku
         	
         	SELECT TOP 1
               @c_oFieled02 = DropID, 
               @c_oFieled04 = waveKey, 
               @c_oFieled05 = Loc, 
               @c_oFieled08 = SKU, 
               @c_oFieled09 = QTY
         	FROM @tCartonInfo
         	WHERE RowRef = @nPrevRow + 1
         END
               
         SET @c_oFieled01 = 'Drop ID: ' 
         --SET @c_oFieled02 = ''
         SET @c_oFieled03 = ''--empty row
         SET @c_oFieled04 = 'WaveKey : ' + @c_oFieled04
         SET @c_oFieled05 = 'Loc : ' + @c_oFieled05
         SET @c_oFieled06 = ''--empty row
         SET @c_oFieled07 = 'SKU:' 
         --SET @c_oFieled08 = ''
         SET @c_oFieled09 = 'Qty : ' + @c_oFieled09
         SET @c_oFieled10 = ''
         
         IF @nPrevRow+1 < @nMaxRow
         BEGIN
         	SET @nNextPage = 1  
         END
         ELSE
         BEGIN
         	SET @nNextPage = 0  
         END 
      END
   END

Quit:

END

GO