SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1831ExtValid01                                        */
/* Purpose: Validate Loadkey scanned in                                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-May-25 1.0  James    WMS5163 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1831ExtValid01] (
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
   @nQty          INT, 
   @cLabelNo      NVARCHAR( 20), 
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cLoadKey       NVARCHAR( 10),
           @cFacility      NVARCHAR( 5),
           @cUserName      NVARCHAR( 18),
           @cOtherUserName NVARCHAR( 18)    

   SET @nErrNo = 0

   SET @cLoadKey = @cParam1

   SELECT @cFacility = Facility,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF ISNULL( @cParam1, '') = '' 
         BEGIN
            SET @nErrNo = 124451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadKey Needed
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- LoadKey
            GOTO Quit
         END 
         ELSE
         BEGIN
            -- Check valid    
            IF NOT EXISTS( SELECT 1 
                  FROM dbo.LoadPlan WITH (NOLOCK) 
                  WHERE LoadKey = @cLoadKey)    
            BEGIN    
               SET @nErrNo = 124452    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidLoadKey    
               GOTO Quit    
            END    

            IF NOT EXISTS ( SELECT 1 
               FROM dbo.LoadPlan WITH (NOLOCK) 
               WHERE LoadKey = @cLoadKey 
               AND   Facility = @cFacility ) 
            BEGIN
               SET @nErrNo = 124453    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffFacility    
               GOTO Quit  
            END
      
            IF NOT EXISTS ( SELECT 1 
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = LPD.OrderKey)
               WHERE LPD.LoadKey = @cLoadKey
               AND   O.StorerKey = @cStorerKey) 
            BEGIN
               SET @nErrNo = 124454    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DiffStorer    
               GOTO Quit  
            END

            -- Check load plan status    
            IF EXISTS( SELECT 1 
               FROM dbo.LoadPlan WITH (NOLOCK) 
               WHERE LoadKey = @cLoadKey 
               AND   Status = '9') -- 9=Closed    
            BEGIN    
               SET @nErrNo = 124455    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LoadKey Closed    
               GOTO Quit    
            END 

             IF EXISTS ( SELECT 1 FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
                        WHERE LoadKey = @cLoadKey
                        AND   AddWho = @cUserName
                        AND   Status < '9')    
            BEGIN
               SET @nErrNo = 124456    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Load Scanned    
               GOTO Quit   
            END
         END
      END
   END

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                         JOIN rdt.rdtSortAndPackLog SAP WITH (NOLOCK) ON ( O.LoadKey = SAP.LoadKey)
                         WHERE PD.StorerKey = @cStorerKey
                         AND   PD.SKU = @cSKU
                         --AND   O.LoadKey = @cLoadKey
                         AND   ISNULL(OD.UserDefine04, '') <> 'M' 
                         AND   SAP.UserName = @cUserName
                         AND SAP.Status = '0')
         BEGIN    
            SET @nErrNo = 124457    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotIn Load    
            GOTO Quit    
         END    
       
         -- Check if same SKU more then 1 user handle    
         SET @cOtherUserName = ''    
         SELECT TOP 1 @cOtherUserName = UserName  
         FROM rdt.rdtMobRec Mob WITH (NOLOCK)    
         WHERE Func = @nFunc    
            AND StorerKey = @cStorerKey    
            AND V_SKU = @cSKU    
            AND UserName <> @cUserName    
            AND Step > 2    
            AND EXISTS ( SELECT 1 FROM rdt.rdtSortAndPackLog SAP WITH (NOLOCK) 
                         WHERE Mob.V_LoadKey = SAP.LoadKey 
                         AND   SAP.UserName = @cUserName
                         AND   Status < '9')
         ORDER BY EditDate DESC             
         
         IF @cOtherUserName <> ''    
         BEGIN    
            SET @nErrNo = 124458    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKULockByUser    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, @cOtherUserName    
            GOTO Quit    
         END   
      END 
   END

   Quit:


GO