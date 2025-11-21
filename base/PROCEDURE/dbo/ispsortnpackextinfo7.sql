SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackExtInfo7                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Display qty in load level                                   */  
/*                                                                      */
/* Called from: rdtfnc_SortAndPack                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2018-Mar-27 1.0  James    WMS4203. Created                           */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo7]  
   @cLoadKey         NVARCHAR(10),  
   @cOrderKey        NVARCHAR(10),  
   @cConsigneeKey    NVARCHAR(15),  
   @cLabelNo         NVARCHAR(20) OUTPUT,  
   @cStorerKey       NVARCHAR(15),  
   @cSKU             NVARCHAR(20),  
   @nQTY             INT,   
   @cExtendedInfo    NVARCHAR(20) OUTPUT,  
   @cExtendedInfo2   NVARCHAR(20) OUTPUT,
   @cLangCode        NVARCHAR(3),           
   @bSuccess         INT          OUTPUT,   
   @nErrNo           INT          OUTPUT,   
   @cErrMsg          NVARCHAR(20) OUTPUT,   
   @nMobile          INT                    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nInputKey      INT,
           @nStep          INT,
           @nTtl_PickQty   INT,
           @nTTL_PickedQty INT,
           @nCount         INT,
           @nOrderQTY_Bal  INT,
           @nOrderQTY_Total   INT

   DECLARE @cDisplay_LoadKey     NVARCHAR( 10),
           @cText2Display        NVARCHAR( 20),
           @cUserName            NVARCHAR( 18),
           @cErrMsg1             NVARCHAR( 20),
           @cErrMsg2             NVARCHAR( 20),
           @cErrMsg3             NVARCHAR( 20),
           @cErrMsg4             NVARCHAR( 20),
           @cErrMsg5             NVARCHAR( 20),
           @cErrMsg6             NVARCHAR( 20),
           @cErrMsg7             NVARCHAR( 20),
           @cErrMsg8             NVARCHAR( 20)

   SELECT @nInputKey = InputKey, 
          @nStep = Step,
          @cUserName = UserName,
          @cLoadKey = V_CaseID
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         SELECT TOP 1 @cLoadKey = SAP.LoadKey 
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
         JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( LPD.LoadKey = SAP.LoadKey)
         WHERE PD.Status = '0'
         AND   PD.UOM = '6'
         AND   PD.CaseID = ''
         AND   PD.Sku = @cSKU
         AND   SAP.Username = @cUserName
         AND   SAP.Status = '0'
         ORDER BY 1

         SET @cExtendedInfo = ''
         SET @cExtendedInfo2 = 'LOADKEY: ' + @cLoadKey
      END

      IF @nStep = 3
      BEGIN
         SELECT @cLoadKey = I_Field06 FROM rdt.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

         SET @cExtendedInfo = ''
         SET @cExtendedInfo2 = 'LOADKEY: ' + @cLoadKey
      END

      IF @nStep = 4
      BEGIN
         SELECT TOP 1 @cLoadKey = SAP.LoadKey 
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
         JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( LPD.LoadKey = SAP.LoadKey)
         WHERE PD.Status = '0'
         AND   PD.UOM = '6'
         AND   PD.CaseID = ''
         AND   PD.Sku = @cSKU
         AND   SAP.Username = @cUserName
         AND   SAP.Status = '0'
         ORDER BY 1

         SET @cExtendedInfo = ''
         SET @cExtendedInfo2 = 'LOADKEY: ' + @cLoadKey
      END

      IF @nStep = 7
      BEGIN
         SELECT @nTtl_PickQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         AND   PD.StorerKey = @cStorerKey
         AND   PD.UOM = '6'

         SELECT @nTTL_PickedQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         AND   PD.StorerKey = @cStorerKey
         AND   PD.Status = '5'
         AND   PD.UOM = '6'

         SET @cExtendedInfo = 'SKU QTY: ' + CAST( @nTTL_PickedQty AS NVARCHAR( 4)) + '/' + CAST( @nTTL_PickQty AS NVARCHAR( 4))
         SET @cExtendedInfo2 = ''
      END
   END

   IF @nInputKey = 0
   BEGIN
      IF @nStep = 3
      BEGIN
         --IF @nQTY <> 0
         --BEGIN
            SET @nCount = 1
            DECLARE CUR_DISPLAY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT LPD.LoadKey
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
            JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( LPD.LoadKey = SAP.LoadKey)
            WHERE SAP.UserName = @cUserName
            AND   SAP.Status = '0'
            AND   PD.UOM = '6'
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
               AND   PD.Status = '5'
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

            SET @cExtendedInfo = ''
            SET @cExtendedInfo2 = ''
         --END
      END

      IF @nStep = 4
      BEGIN
         SET @cExtendedInfo = ''
         SET @cExtendedInfo2 = 'LOADKEY: ' + @cLoadKey
      END
   END
QUIT:  
END -- End Procedure  

GO