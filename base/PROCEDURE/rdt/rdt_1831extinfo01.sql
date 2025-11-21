SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1831ExtInfo01                                         */
/* Purpose: Display total scanned loadkey on the screen                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-May-25 1.0  James    WMS5163 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1831ExtInfo01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),  
   @nQty             INT,            
   @cLabelNo         NVARCHAR( 20),  
   @cExtendedInfo1   NVARCHAR( 20) OUTPUT,  
   @cExtendedInfo2   NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nCount         INT,
           @nQty2Pick      INT,
           @nQtyPicked     INT,
           @nTtl_PickQty   INT,
           @nTtl_PickedQty INT,
           @cUserName      NVARCHAR( 18),
           @cLoadKey       NVARCHAR( 10),
           @cDisplay_LoadKey  NVARCHAR( 10),
           @cText2Display     NVARCHAR( 20),
           @cErrMsg1          NVARCHAR( 20),
           @cErrMsg2          NVARCHAR( 20),
           @cErrMsg3          NVARCHAR( 20),
           @cErrMsg4          NVARCHAR( 20),
           @cErrMsg5          NVARCHAR( 20),
           @cErrMsg6          NVARCHAR( 20),
           @cErrMsg7          NVARCHAR( 20),
           @cErrMsg8          NVARCHAR( 20),
           @nErrNo            INT,
           @cErrMsg           NVARCHAR( 20)

  
   SELECT @cUserName = UserName 
   FROM RDT.RDTMobRec WITH (NOLOCK) 
   WHERE MOBILE = @nMobile

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @cLoadKey = ''
         SELECT TOP 1 @cLoadKey = LoadKey
         FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         WHERE UserName = @cUserName
         AND   Status < '9'
         ORDER BY AddDate DESC

         SET @nCount = 0
         SELECT @nCount = COUNT( DISTINCT LoadKey) 
         FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         WHERE UserName = @cUserName
         AND   Status < '9'

         SET @cExtendedInfo1 = 'LAST: ' + @cLoadKey
         SET @cExtendedInfo2 = 'SCANNED: ' + CAST( @nCount AS NVARCHAR( 5))
      END   -- ENTER
   END   

   IF @nStep IN (2, 3)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cLoadKey = LoadKey
         FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         WHERE UserName = @cUserName
         AND   Status = '1'
         AND   SKU = @cSKU

         SELECT @nQty2Pick = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         AND   PD.UOM = '6'

         SELECT @nQtyPicked = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         --AND   PD.Status = '5'
         AND   PD.CaseID = 'SORTED'
         AND   PD.UOM = '6'

         SET @cExtendedInfo1 = 'LoadKey: ' + @cLoadKey
         SET @cExtendedInfo2 = 'Load Qty: ' + CAST( @nQtyPicked AS NVARCHAR( 4)) + '/' + CAST( @nQty2Pick AS NVARCHAR( 4))
      END
   END

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 0
      BEGIN
         SET @nCount = 1
         DECLARE CUR_DISPLAY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT LoadKey
         FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         WHERE UserName = @cUserName
         ORDER BY 1
         OPEN CUR_DISPLAY
         FETCH NEXT FROM CUR_DISPLAY INTO @cDisplay_LoadKey 
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @nTtl_PickQty = ISNULL( SUM( Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE LPD.LoadKey = @cDisplay_LoadKey
            AND   PD.StorerKey = @cStorerKey
            AND   PD.UOM = '6'

            SELECT @nTTL_PickedQty = ISNULL( SUM( Qty), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE LPD.LoadKey = @cDisplay_LoadKey
            AND   PD.StorerKey = @cStorerKey
            --AND   PD.Status = '5'
            AND   PD.CaseID = 'SORTED'
            AND   PD.UOM = '6'

            SET @cText2Display = ''
            SET @cText2Display = '-' + @cDisplay_LoadKey + '=' + CAST( @nTTL_PickedQty AS NVARCHAR( 4)) + '/' + CAST( @nTTL_PickQty AS NVARCHAR( 4))

            IF @nCount = 1 SET @cErrMsg1 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 2 SET @cErrMsg2 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 3 SET @cErrMsg3 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 4 SET @cErrMsg4 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 5 SET @cErrMsg5 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 6 SET @cErrMsg6 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 7 SET @cErrMsg7 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            IF @nCount = 8 SET @cErrMsg8 = CAST( @nCount AS NVARCHAR( 1)) + @cText2Display

            SET @nCount = @nCount + 1

            IF @nCount = 9
               BREAK

            FETCH NEXT FROM CUR_DISPLAY INTO @cDisplay_LoadKey    
         END
         CLOSE CUR_DISPLAY
         DEALLOCATE CUR_DISPLAY

         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, 
         @cErrMsg5, @cErrMsg6, @cErrMsg7, @cErrMsg8

         IF @nErrNo = 1
         BEGIN
            SELECT @cErrMsg1 = '', @cErrMsg2 = '', @cErrMsg3 = '', @cErrMsg4 = ''
            SELECT @cErrMsg5 = '', @cErrMsg6 = '', @cErrMsg7 = '', @cErrMsg8 = ''
         END   
         SET @nErrNo = 0
      END
   END
Quit:



GO