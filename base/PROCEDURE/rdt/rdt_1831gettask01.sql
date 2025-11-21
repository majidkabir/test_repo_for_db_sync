SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1831GetTask01                                         */
/* Purpose: Get task                                                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-May-25 1.0  James    WMS5163 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1831GetTask01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @cSKU          NVARCHAR( 20), 
   @cLabelNo      NVARCHAR( 20), 
   @nEXPQty      INT OUTPUT,
   @nPCKQty      INT OUTPUT,
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cLoadKey       NVARCHAR( 10),
           @cNewLoadKey    NVARCHAR( 10),
           @cFacility      NVARCHAR( 5),
           @cUserName      NVARCHAR( 18),
           @cOtherUserName NVARCHAR( 18)    

   SET @nErrNo = 0

   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nStep = 2 -- SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT TOP 1 @cLoadKey = SAP.LoadKey
         FROM rdt.rdtSortAndPackLog SAP WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SAP.LoadKey = LPD.LoadKey
         JOIN dbo.PickDetail PD (NOLOCK) ON LPD.OrderKey = PD.OrderKey
         WHERE SAP.UserName = @cUserName
         AND   SAP.Status < '9'
         AND   PD.SKU = @cSKU
         --AND   PD.Status = '0'
         AND   PD.CaseID = ''
         AND   PD.UOM = '6'
         ORDER BY 1

         SELECT @nEXPQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PickDetail PD (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @cLoadKey
         AND   PD.SKU = @cSKU
         --AND   PD.Status = '0'
         AND   PD.CaseID = ''
         AND   PD.UOM = '6'

         IF @nEXPQty = 0    
         BEGIN    
            SET @nErrNo = 124601    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Task    
            GOTO Quit    
         END 
         ELSE
         BEGIN
            UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
               SKU = @cSKU,
               [Status] = '1'
            WHERE LoadKey = @cLoadKey
            AND   AddWho = @cUserName
            AND   Status = '0'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 124602    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLog Fail    
               GOTO Quit   
            END
         END
      END
   END

   IF @nStep = 3 -- Qty
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cLoadKey = LoadKey
         FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         WHERE UserName = @cUserName
         AND   Status = '1'
         AND   SKU = @cSKU

         -- Look in same load, same sku
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                     WHERE PD.StorerKey = @cStorerKey
                     AND   PD.SKU = @cSKU
                     --AND   PD.Status = '0'
                     AND   PD.CaseID = ''
                     AND   PD.UOM = '6'
                     AND   LPD.LoadKey = @cLoadKey)
         BEGIN
            SELECT @nEXPQty = ISNULL( SUM( Qty), 0)
            FROM dbo.PickDetail PD (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            WHERE LPD.LoadKey = @cLoadKey
            AND   PD.SKU = @cSKU
            --AND   PD.Status = '0'
            AND   PD.CaseID = ''
            AND   PD.UOM = '6'
         END
         ELSE
         BEGIN
            -- Look in different load, same sku
            SELECT TOP 1 @cNewLoadKey = SAP.LoadKey
            FROM rdt.rdtSortAndPackLog SAP WITH (NOLOCK) 
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON SAP.LoadKey = LPD.LoadKey
            JOIN dbo.PickDetail PD (NOLOCK) ON LPD.OrderKey = PD.OrderKey
            WHERE SAP.UserName = @cUserName
            AND   SAP.Status = '0'
            AND   SAP.LoadKey <> @cLoadKey
            AND   PD.SKU = @cSKU
            --AND   PD.Status = '0'
            AND   PD.CaseID = ''
            AND   PD.UOM = '6'
            ORDER BY 1

            IF ISNULL( @cNewLoadKey, '') <> ''
            BEGIN
               UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
                  [Status] = '9'
               WHERE UserName = @cUserName
               AND   Status = '1'
               AND   LoadKey = @cLoadKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 124603    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLog Fail    
                  GOTO Quit   
               END

               UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
                  SKU = @cSKU,
                  [Status] = '1'
               WHERE UserName = @cUserName
               AND   Status = '0'
               AND   LoadKey = @cNewLoadKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 124604    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLog Fail    
                  GOTO Quit   
               END

               SELECT @nEXPQty = ISNULL( SUM( Qty), 0)
               FROM dbo.PickDetail PD (NOLOCK) 
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
               WHERE LPD.LoadKey = @cNewLoadKey
               AND   PD.SKU = @cSKU
               --AND   PD.Status = '0'
               AND   PD.CaseID = ''
               AND   PD.UOM = '6'
            END
            ELSE
            BEGIN
               -- No more task for sku
               SET @nEXPQty = 0
               UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
                  SKU = '',
                  [Status] = '0'
               WHERE UserName = @cUserName
               AND   SKU = @cSKU

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 124605    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLog Fail    
                  GOTO Quit   
               END
               GOTO Quit    
            END
         END
      END
   END
   Quit:


GO